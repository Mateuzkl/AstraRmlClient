#include "effekseersystem.h"
#include "mapview.h"
#include "map.h"
#include "creature.h"
#include "spritemanager.h"
#include <framework/core/eventdispatcher.h>
#include <framework/core/resourcemanager.h>
#include <framework/core/logger.h>
#include <framework/graphics/graphics.h>
#include <framework/graphics/drawqueue.h>
#include <framework/effekseer/glstate.h>
#include <framework/effekseer/backend.h>
#include <framework/effekseer/trajectory.h>
#include <Effekseer.h>
#include <Effekseer.Modules.h>
#include <EffekseerRendererGL.h>
#include <chrono>
#include <filesystem>
#include <unordered_map>

static_assert(Effekseer::TextureSlotMax <= 16, "Update the GL binding guard for this Effekseer version");

using namespace AstraParticles;
namespace {
using ParticleClock = std::chrono::steady_clock;
double elapsed(ParticleClock::time_point start) { return std::chrono::duration<double,std::milli>(ParticleClock::now()-start).count(); }
std::string utf8(const char16_t* text) {
    if (!text) return {};
    const auto s=std::filesystem::path(std::u16string(text)).generic_u8string();
    return std::string(reinterpret_cast<const char*>(s.data()),s.size());
}
class MemoryReader final : public Effekseer::FileReader {
    std::string data; size_t offset=0;
public:
    explicit MemoryReader(std::string value):data(std::move(value)) {}
    size_t Read(void* out,size_t count) override {
        count=std::min(count,data.size()-offset); std::memcpy(out,data.data()+offset,count);offset+=count;return count;
    }
    void Seek(int position) override { offset=static_cast<size_t>(std::clamp(position,0,int(data.size()))); }
    int GetPosition() const override { return int(offset); }
    size_t GetLength() const override { return data.size(); }
};
class Vfs final : public Effekseer::FileInterface {
    size_t readBytes=0,decodedBytes=0,files=0;
public:
    void beginAsset() { readBytes=decodedBytes=files=0; }
    Effekseer::FileReaderRef OpenRead(const char16_t* name) override {
        try {
            const auto path=utf8(name);
            if (!validPath(path) || ++files>32) return nullptr;
            // Only PNG texture decoding is admitted; no DDS/JPEG allocation bypass.
            if(!path.ends_with(".efkefc") && !path.ends_with(".png") &&
               !path.ends_with(".efkmodel") && !path.ends_with(".efkcurve")) return nullptr;
            auto data=g_resources.readFileContentsBounded(path,MaxFileBytes);
            readBytes+=data.size();
            if (readBytes>16*MaxFileBytes) return nullptr;
            if (path.ends_with(".png")) {
                if(data.size()<33 || data.compare(0,8,"\x89PNG\r\n\x1a\n",8)!=0 || data.substr(12,4)!="IHDR") return nullptr;
                auto integer=[&](size_t i) { uint32_t n=0;for(size_t k=0;k<4;++k)n=(n<<8)|uint8_t(data[i+k]);return n; };
                const auto w=integer(16),h=integer(20);
                if(!w || !h || w>2048 || h>2048) return nullptr;
                decodedBytes+=size_t(w)*h*4;
                if(decodedBytes>32*1024*1024) return nullptr;
            }
            return Effekseer::MakeRefPtr<MemoryReader>(std::move(data));
        } catch (...) { return nullptr; }
    }
    Effekseer::FileWriterRef OpenWrite(const char16_t*) override { return nullptr; }
};
struct Runtime {
    EffekseerRendererGL::RendererRef renderer;
    Effekseer::ManagerRef manager;
    Effekseer::RefPtr<Vfs> files;
    std::unordered_map<std::string,Effekseer::EffectRef> assets;
    std::unordered_map<uint32_t,Effekseer::Handle> handles;
    std::unordered_map<uint32_t,std::string> handleAssets;
    std::unordered_map<std::string,uint64_t> assetAge;
    uint64_t clock=0;
    Runtime() {
#ifdef OPENGL_ES
        constexpr auto device=EffekseerRendererGL::OpenGLDeviceType::OpenGLES3;
#else
        constexpr auto device=EffekseerRendererGL::OpenGLDeviceType::OpenGL3;
#endif
        renderer=EffekseerRendererGL::Renderer::Create(ParticleBudget,device);
        if(!renderer) throw std::runtime_error("Effekseer GL/ANGLE renderer creation failed");
        manager=Effekseer::Manager::Create(ParticleBudget);
        if(!manager) throw std::runtime_error("Effekseer manager creation failed");
        renderer->SetRestorationOfStatesFlag(true);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER,0);
        glPixelStorei(GL_UNPACK_ALIGNMENT,1);glPixelStorei(GL_UNPACK_ROW_LENGTH,0);
        glPixelStorei(GL_UNPACK_SKIP_PIXELS,0);glPixelStorei(GL_UNPACK_SKIP_ROWS,0);
        renderer->SetDistortingCallback(nullptr); renderer->SetBackground(0);
        manager->SetSpriteRenderer(renderer->CreateSpriteRenderer());
        manager->SetRibbonRenderer(renderer->CreateRibbonRenderer());
        manager->SetRingRenderer(renderer->CreateRingRenderer());
        manager->SetTrackRenderer(renderer->CreateTrackRenderer());
        manager->SetModelRenderer(renderer->CreateModelRenderer());
        files=Effekseer::MakeRefPtr<Vfs>();
        manager->SetEffectLoader(Effekseer::Effect::CreateEffectLoader(files));
        manager->SetTextureLoader(renderer->CreateTextureLoader(files));
        manager->SetModelLoader(renderer->CreateModelLoader(files));
        manager->SetCurveLoader(Effekseer::MakeRefPtr<Effekseer::CurveLoader>(files));
        // No sound, custom materials, distortion background, networking or GPU particles.
    }
    ~Runtime() {
        if(manager) manager->StopAllEffects();
        handles.clear();handleAssets.clear();assetAge.clear();assets.clear();manager.Reset();renderer.Reset();files.Reset();
    }
    bool spawn(uint32_t id,const std::string& path) {
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER,0);
        glPixelStorei(GL_UNPACK_ALIGNMENT,1);glPixelStorei(GL_UNPACK_ROW_LENGTH,0);
        glPixelStorei(GL_UNPACK_SKIP_PIXELS,0);glPixelStorei(GL_UNPACK_SKIP_ROWS,0);
        auto found=assets.find(path);
        if(found==assets.end()) {
            if(assets.size()>=MaxAssets) {
                auto candidate=assets.end();
                for(auto it=assets.begin();it!=assets.end();++it) {
                    const bool inUse=std::any_of(handleAssets.begin(),handleAssets.end(),[&](const auto& pair) { return pair.second==it->first; });
                    if(!inUse && (candidate==assets.end() || assetAge.at(it->first)<assetAge.at(candidate->first))) candidate=it;
                }
                if(candidate==assets.end()) return false;
                assetAge.erase(candidate->first);assets.erase(candidate);
            }
            files->beginAsset();
            const auto encoded=std::filesystem::u8path(path).u16string();
            auto effect=Effekseer::Effect::Create(manager,encoded.c_str());
            if(!effect) return false;
            found=assets.emplace(path,std::move(effect)).first;
        }
        assetAge[path]=++clock;
        auto handle=manager->Play(found->second,0,0,0);
        if(handle<0) return false;
        manager->SetAutoDrawing(handle,false);handles.emplace(id,handle);handleAssets.emplace(id,path);return true;
    }
    void stop(uint32_t id) {
        if(auto found=handles.find(id);found!=handles.end()) { manager->StopEffect(found->second);handles.erase(found);handleAssets.erase(id); }
    }
    void clear() { manager->StopAllEffects();handles.clear();handleAssets.clear();assetAge.clear();assets.clear(); }
    void draw(const std::vector<Projected>& entries) {
        const auto painterProjection=g_painter->getProjectionMatrix();
        const auto* p=painterProjection.data();
        Effekseer::Matrix44 projection;projection.Indentity();
        projection.Values[0][0]=p[0];projection.Values[1][1]=-p[4];
        projection.Values[2][2]=1.f/2000.f;projection.Values[3][0]=p[6];projection.Values[3][1]=p[7];
        renderer->SetProjectionMatrix(projection);
        for(const auto& entry:entries) {
            auto found=handles.find(entry.id);
            if(found==handles.end() || !manager->Exists(found->second)) continue;
            Effekseer::Matrix44 camera;camera.Indentity();
            camera.Values[0][0]=camera.Values[1][1]=camera.Values[2][2]=entry.scale;
            const float radians=entry.tilt*3.14159265f/180.f;
            camera.Values[1][1]=camera.Values[2][2]=entry.scale*std::cos(radians);
            camera.Values[1][2]=entry.scale*std::sin(radians);
            camera.Values[2][1]=-entry.scale*std::sin(radians);
            camera.Values[3][0]=entry.x;camera.Values[3][1]=-entry.y;
            renderer->SetCameraMatrix(camera);
            Effekseer::Manager::DrawParameter parameter;
            Effekseer::Matrix44::Mul(parameter.ViewProjectionMatrix,camera,projection);
            if(renderer->BeginRendering()) { manager->DrawHandle(found->second,parameter);renderer->EndRendering(); }
        }
    }
};
struct ParticleDrawItem final : DrawQueueItem {
    uint64_t epoch;std::vector<Projected> entries;
    ParticleDrawItem(uint64_t generation,std::vector<Projected> values):DrawQueueItem(nullptr),epoch(generation),entries(std::move(values)) {}
    void draw() override { g_effekseer.render(epoch,entries); }
};
bool mapPosition(const Position& p) { return p.x<65535 && p.y<65535 && p.z<=15; }
}

struct EffekseerSystem::Impl {
    struct Flight {
        std::weak_ptr<Creature> target;
        FlightPoint from;
        std::string impact;
        uint32_t duration;
        float impactScale;
        ParticleClock::time_point start{};
        bool started=false;
    };
    struct Anchor {
        uint32_t id;Position position;std::weak_ptr<Creature> creature;bool follow=false,preview=false;float scale=8.f;
        float tilt=0.f,offsetX=0.f,offsetY=0.f;
        bool ready=false,impact=false;
        std::optional<Flight> flight;
    };
    mutable std::mutex mutex;
    CommandQueue commands;
    std::unordered_map<uint32_t,Anchor> anchors;
    std::atomic_bool enabled=false;
    std::atomic<uint64_t> epoch=1,selectedView=0;
    uint32_t next=0; uint64_t resources=0,graphicsEpoch=0;
    std::unique_ptr<Runtime> runtime; // graphics thread only
    ParticleClock::time_point last=ParticleClock::now();double time=0;
    ParticleClock::time_point lastLogic{};
    std::atomic_int active=0,particles=0,cached=0,dropped=0;
    std::atomic<double> updateMs=0,renderMs=0;
    std::string status="Effekseer experimental is disabled";
    void message(std::string value) { std::scoped_lock lock(mutex);status=std::move(value); }
};
EffekseerSystem g_effekseer;
EffekseerSystem::EffekseerSystem():m(std::make_unique<Impl>()) {}
EffekseerSystem::~EffekseerSystem()=default;
bool EffekseerSystem::isAvailable() const { return true; }
bool EffekseerSystem::isEnabled() const { return m->enabled.load(); }
void EffekseerSystem::pollResources() {
    const auto generation=g_resources.getGeneration();
    if(m->resources!=generation) { m->resources=generation;clearAll(); }
    if(!isEnabled()) return;
    const auto now=ParticleClock::now();
    if(now-m->lastLogic<std::chrono::milliseconds(8)) return;
    m->lastLogic=now;
    std::scoped_lock lock(m->mutex);
    bool overflow=false;
    for(auto it=m->anchors.begin();it!=m->anchors.end();) {
        auto& anchor=it->second;
        if(!anchor.flight || !anchor.ready) { ++it;continue; }
        auto& flight=*anchor.flight;
        auto target=flight.target.lock();
        if(!target || target->isRemoved() || target->getPosition().z!=anchor.position.z) {
            overflow|=!m->commands.push({Command::Stop,m->epoch.load(),anchor.id,{}});
            it=m->anchors.erase(it);continue;
        }
        if(!flight.started) { flight.start=now;flight.started=true; }
        const float t=float(std::chrono::duration<double,std::milli>(now-flight.start).count()/flight.duration);
        const auto destination=target->getPrewalkingPosition();
        const auto walking=target->getWalkOffset();
        const float sprite=float(g_sprites.spriteSize());
        const auto point=trajectory(flight.from,{float(destination.x)+walking.x/sprite,float(destination.y)+walking.y/sprite},t);
        anchor.offsetX=point.x-anchor.position.x;anchor.offsetY=point.y-anchor.position.y;
        if(t>=1.f) {
            overflow|=!m->commands.push({Command::Stop,m->epoch.load(),anchor.id,{}});
            if(flight.impact.empty()) { it=m->anchors.erase(it);continue; }
            overflow|=!m->commands.push({Command::Spawn,m->epoch.load(),anchor.id,flight.impact});
            anchor.scale=flight.impactScale;anchor.tilt=40.f;
            anchor.impact=true;
            anchor.creature=target;anchor.follow=true;anchor.position=destination;
            anchor.offsetX=anchor.offsetY=0;anchor.ready=false;anchor.flight.reset();
        }
        ++it;
    }
    if(overflow) { ++m->dropped;++m->epoch;m->anchors.clear();m->commands.clear(); }
}
void EffekseerSystem::setEnabled(bool value) {
    if(m->enabled.exchange(value)==value) return;
    clearAll();m->message(value?"Effekseer experimental: waiting for OpenGL renderer":"Effekseer experimental is disabled");
}
void EffekseerSystem::clearAll() {
    std::scoped_lock lock(m->mutex);
    ++m->epoch;m->anchors.clear();m->commands.clear();
}
uint32_t EffekseerSystem::create(const std::string& path,const Position& position,const CreaturePtr& creature,bool preview) {
    if(!isEnabled() || !validPath(path) || !path.ends_with(".efkefc") || (!preview && !mapPosition(position))) return 0;
    if(creature && creature->isRemoved()) return 0;
    std::scoped_lock lock(m->mutex);
    if(m->anchors.size()>=MaxInstances || m->next==UINT32_MAX) { ++m->dropped;return 0; }
    const auto id=++m->next;
    if(!m->commands.push({Command::Spawn,m->epoch.load(),id,path})) { ++m->dropped;return 0; }
    m->anchors.emplace(id,Impl::Anchor{id,position,creature,creature!=nullptr,preview});return id;
}
uint32_t EffekseerSystem::play(const std::string& path,const Position& position) { return create(path,position,nullptr,false); }
uint32_t EffekseerSystem::follow(const std::string& path,uint32_t creatureId) {
    return followCreature(path,g_map.getCreatureById(creatureId));
}
uint32_t EffekseerSystem::followCreature(const std::string& path,const CreaturePtr& creature) {
    return creature?create(path,creature->getPosition(),creature,false):0;
}
uint32_t EffekseerSystem::playPreview(const std::string& path) { return create(path,Position(0,0,7),nullptr,true); }
uint32_t EffekseerSystem::shoot(const std::string& path,const CreaturePtr& source,const CreaturePtr& target,
                              const std::string& impact,uint32_t milliseconds,float flightScale,float impactScale) {
    if(!source || !target || source->isRemoved() || target->isRemoved() || milliseconds<100 || milliseconds>3000 ||
       !std::isfinite(flightScale) || flightScale<0.1f || flightScale>64.f ||
       !std::isfinite(impactScale) || impactScale<0.1f || impactScale>64.f ||
       (!impact.empty() && (!validPath(impact) || !impact.ends_with(".efkefc")))) return 0;
    const auto from=source->getPrewalkingPosition(),to=target->getPrewalkingPosition();
    if(!mapPosition(from) || !mapPosition(to) || from.z!=to.z || std::abs(int(from.x)-to.x)>20 || std::abs(int(from.y)-to.y)>20) return 0;
    const auto id=create(path,from,nullptr,false);
    if(!id) return 0;
    const auto walking=source->getWalkOffset();const float sprite=float(g_sprites.spriteSize());
    std::scoped_lock lock(m->mutex);auto found=m->anchors.find(id);
    if(found==m->anchors.end()) return 0;
    auto& anchor=found->second;anchor.scale=flightScale;
    anchor.flight=Impl::Flight{target,{float(from.x)+walking.x/sprite,float(from.y)+walking.y/sprite},impact,milliseconds,impactScale};
    return id;
}
bool EffekseerSystem::move(uint32_t handle,const Position& position) {
    if(!mapPosition(position)) return false;
    std::scoped_lock lock(m->mutex);auto found=m->anchors.find(handle);
    if(found==m->anchors.end() || found->second.preview) return false;
    found->second.position=position;found->second.follow=false;found->second.creature.reset();
    found->second.flight.reset();found->second.offsetX=found->second.offsetY=0;return true;
}
bool EffekseerSystem::setScale(uint32_t handle,float scale) {
    if(!std::isfinite(scale) || scale<0.1f || scale>64.f) return false;
    std::scoped_lock lock(m->mutex);auto found=m->anchors.find(handle);
    if(found==m->anchors.end()) return false;found->second.scale=scale;return true;
}
bool EffekseerSystem::setTilt(uint32_t handle,float degrees) {
    if(!std::isfinite(degrees) || degrees<0.f || degrees>75.f) return false;
    std::scoped_lock lock(m->mutex);auto found=m->anchors.find(handle);
    if(found==m->anchors.end()) return false;found->second.tilt=degrees;return true;
}
std::string EffekseerSystem::getPhase(uint32_t handle) const {
    std::scoped_lock lock(m->mutex);auto found=m->anchors.find(handle);
    if(found==m->anchors.end()) return "stopped";
    const auto& anchor=found->second;
    if(!anchor.ready || (anchor.flight && !anchor.flight->started)) return "loading";
    return anchor.flight?"flight":anchor.impact?"impact":anchor.preview?"preview":"stationary";
}
void EffekseerSystem::stop(uint32_t handle) {
    std::scoped_lock lock(m->mutex);
    if(!m->anchors.erase(handle)) return;
    if(!m->commands.push({Command::Stop,m->epoch.load(),handle,{}})) {
        // Backpressure cannot leave an untracked live instance: invalidate the batch.
        ++m->dropped;++m->epoch;m->anchors.clear();m->commands.clear();
    }
}
void EffekseerSystem::selectMapView(uint64_t view) { m->selectedView=view; }
void EffekseerSystem::releaseMapView(uint64_t view) { uint64_t expected=view;m->selectedView.compare_exchange_strong(expected,0); }
void EffekseerSystem::submitMap(const MapView& view,uint64_t id) {
    if(!isEnabled() || m->selectedView!=id) return;
    const auto camera=const_cast<MapView&>(view).getCameraPosition();
    // MapView owns its exact virtual center; project through its existing method.
    std::vector<Projected> entries;std::vector<uint32_t> expired;
    const int sprite=g_sprites.spriteSize();
    {
        std::scoped_lock lock(m->mutex);
        for(const auto& [key,anchor]:m->anchors) {
            if(anchor.preview) continue;
            auto position=anchor.position;Point walk;
            if(anchor.follow) {
                auto owner=anchor.creature.lock();
                if(!owner || owner->isRemoved()) { expired.push_back(key);continue; }
                position=owner->getPrewalkingPosition();walk=owner->getWalkOffset();
            }
            if(position.z!=camera.z || std::abs(int(position.x)-camera.x)>32 || std::abs(int(position.y)-camera.y)>32) continue;
            const auto point=const_cast<MapView&>(view).projectEffekseer(position,camera)+walk+Point(sprite/2,sprite/2);
            entries.push_back({key,float(point.x)+anchor.offsetX*sprite,float(point.y)+anchor.offsetY*sprite,
                               anchor.scale*float(sprite)/32.f,anchor.tilt});
        }
    }
    for(auto key:expired) stop(key);
    if(!entries.empty()) g_drawQueue->add(std::make_unique<ParticleDrawItem>(m->epoch.load(),std::move(entries)));
}
void EffekseerSystem::submitPreview(uint32_t handle,const Rect& rect) {
    if(!isEnabled() || !rect.isValid()) return;
    std::vector<Projected> entries;
    {
        std::scoped_lock lock(m->mutex);auto found=m->anchors.find(handle);
        if(found==m->anchors.end() || !found->second.preview) return;
        entries.push_back({handle,float(rect.center().x),float(rect.center().y),found->second.scale,found->second.tilt});
    }
    const auto start=g_drawQueue->size();
    g_drawQueue->add(std::make_unique<ParticleDrawItem>(m->epoch.load(),std::move(entries)));
    g_drawQueue->setClip(start,rect);
}
void EffekseerSystem::beginFrame() {
    VALIDATE_GRAPHICS_THREAD();
    const auto started=ParticleClock::now();
    const auto step=frameStep(std::chrono::duration<double>(started-m->last).count());m->last=started;
    if(!isEnabled()) {
        if(m->runtime) { EffekseerGlState guard;m->runtime.reset(); }
        m->active=0;m->particles=0;m->cached=0;m->updateMs=0;m->renderMs=0;return;
    }
    // Do not construct a GL3 state guard on an older context: its entry points
    // (VAOs/samplers/read FBO) may be null even though vanilla GL can still run.
#ifdef OPENGL_ES
    const bool supported=supportsGles3(g_graphics.getVersion());
#else
    const bool supported=GLEW_VERSION_3_3;
#endif
    if(!m->runtime && (!g_graphics.ok() || !supported)) {
        m->enabled=false;clearAll();
        m->message("Effekseer requires OpenGL 3.3 or ANGLE ES3; vanilla rendering retained");
        g_logger.warning("[Effekseer] "+getStatus());return;
    }
    try {
        EffekseerGlState guard;
        if(!m->runtime) {
            m->runtime=std::make_unique<Runtime>();m->graphicsEpoch=m->epoch;m->time=0;
#ifdef OPENGL_ES
            m->message("Effekseer 1.80.7 / ANGLE ES3 (DirectX) / experimental");
#else
            m->message("Effekseer 1.80.7 / desktop OpenGL3 / experimental");
#endif
        }
        if(m->graphicsEpoch!=m->epoch) { m->runtime->clear();m->graphicsEpoch=m->epoch; }
        auto commands=m->commands.take();
        for(const auto& command:commands) {
            if(command.epoch!=m->graphicsEpoch) continue;
            if(command.type==Command::Spawn && !m->runtime->spawn(command.id,command.path)) {
                { std::scoped_lock lock(m->mutex);m->anchors.erase(command.id); }
                ++m->dropped;m->message("Effect unavailable or asset budget exceeded: "+command.path);
            } else if(command.type==Command::Stop) m->runtime->stop(command.id);
            else if(command.type==Command::Spawn) {
                std::scoped_lock lock(m->mutex);auto found=m->anchors.find(command.id);
                if(found!=m->anchors.end()) found->second.ready=true;
            }
        }
        m->time+=step/60.f;m->runtime->renderer->SetTime(float(m->time));m->runtime->manager->Update(step);
        std::vector<std::pair<uint32_t,std::string>> restartFlights;
        for(auto it=m->runtime->handles.begin();it!=m->runtime->handles.end();) {
            if(!m->runtime->manager->Exists(it->second)) {
                std::scoped_lock lock(m->mutex);
                auto anchor=m->anchors.find(it->first);
                // A finite asset can end before the requested flight duration.
                // Reuse its cached effect, never let a live shot become invisible
                // for the remainder of its flight or keep an expired entity alive.
                if(anchor!=m->anchors.end()) {
                    if(anchor->second.flight)
                        restartFlights.emplace_back(it->first,m->runtime->handleAssets.at(it->first));
                    else m->anchors.erase(anchor);
                }
                m->runtime->handleAssets.erase(it->first);it=m->runtime->handles.erase(it);
            } else ++it;
        }
        for(const auto& [id,path]:restartFlights) {
            if(!m->runtime->spawn(id,path)) {
                std::scoped_lock lock(m->mutex);m->anchors.erase(id);++m->dropped;
            }
        }
        m->active=int(m->runtime->handles.size());m->particles=m->runtime->manager->GetTotalInstanceCount();
        m->cached=int(m->runtime->assets.size());m->updateMs=elapsed(started);m->renderMs=0;
    } catch(const std::exception& error) {
        { EffekseerGlState guard;m->runtime.reset(); }
        m->enabled=false;clearAll();m->message(error.what());g_logger.warning(std::string("[Effekseer] ")+error.what());
    }
}
void EffekseerSystem::render(uint64_t epoch,const std::vector<Projected>& entries) {
    VALIDATE_GRAPHICS_THREAD();
    if(!isEnabled() || epoch!=m->epoch || !m->runtime) return;
    const auto started=ParticleClock::now();
    { EffekseerGlState guard;m->runtime->draw(entries); }
    m->renderMs=m->renderMs.load()+elapsed(started);
}
void EffekseerSystem::shutdown() {
    VALIDATE_GRAPHICS_THREAD();
    m->enabled=false;clearAll();
    if(m->runtime) { EffekseerGlState guard;m->runtime.reset(); }
    m->active=0;m->particles=0;m->cached=0;
}
std::string EffekseerSystem::getStatus() const { std::scoped_lock lock(m->mutex);return m->status; }
int EffekseerSystem::getActiveCount() const { return m->active; }
int EffekseerSystem::getParticleCount() const { return m->particles; }
int EffekseerSystem::getCachedAssetCount() const { return m->cached; }
int EffekseerSystem::getDroppedCount() const { return m->dropped; }
double EffekseerSystem::getUpdateMilliseconds() const { return m->updateMs; }
double EffekseerSystem::getRenderMilliseconds() const { return m->renderMs; }
UIEffekseerPreview::~UIEffekseerPreview() { if(m_handle) g_effekseer.stop(m_handle); }
void UIEffekseerPreview::setEffectHandle(uint32_t handle) { if(m_handle!=handle && m_handle) g_effekseer.stop(m_handle);m_handle=handle; }
void UIEffekseerPreview::drawSelf(Fw::DrawPane pane) {
    UIWidget::drawSelf(pane);
    if(pane==Fw::ForegroundPane && m_handle) g_effekseer.submitPreview(m_handle,getPaddingRect());
}
