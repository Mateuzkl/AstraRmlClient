#pragma once
#include <framework/global.h>
#include <framework/ui/uiwidget.h>
#include <framework/effekseer/commands.h>
#include "position.h"
#include "declarations.h"
#include <memory>

class MapView;
class EffekseerSystem {
public:
    EffekseerSystem();
    ~EffekseerSystem();
    bool isAvailable() const;
    void setEnabled(bool value);
    bool isEnabled() const;
    uint32_t play(const std::string& path,const Position& position);
    uint32_t follow(const std::string& path,uint32_t creatureId);
    uint32_t followCreature(const std::string& path,const CreaturePtr& creature);
    uint32_t playPreview(const std::string& path);
    uint32_t shoot(const std::string& path,const CreaturePtr& source,const CreaturePtr& target,
                   const std::string& impact,uint32_t milliseconds,float flightScale,float impactScale);
    bool move(uint32_t handle,const Position& position);
    bool setScale(uint32_t handle,float scale);
    bool setTilt(uint32_t handle,float degrees);
    std::string getPhase(uint32_t handle) const;
    void stop(uint32_t handle);
    void clearAll();
    std::string getStatus() const;
    int getActiveCount() const;
    int getParticleCount() const;
    int getCachedAssetCount() const;
    int getDroppedCount() const;
    double getUpdateMilliseconds() const;
    double getRenderMilliseconds() const;
    void selectMapView(uint64_t view);
    void releaseMapView(uint64_t view);
    void submitMap(const MapView& view,uint64_t id);
    void submitPreview(uint32_t handle,const Rect& rect);
    void pollResources(); // Logic thread; resource generation is not an atomic GL input.
    // Only the GL owner calls these; draws contain immutable values, not entities.
    void beginFrame();
    void shutdown();
    void render(uint64_t epoch,const std::vector<AstraParticles::Projected>& entries);
private:
    uint32_t create(const std::string& path,const Position& position,const CreaturePtr& creature,bool preview);
    struct Impl; std::unique_ptr<Impl> m;
};
extern EffekseerSystem g_effekseer;

class UIEffekseerPreview : public UIWidget {
public:
    ~UIEffekseerPreview() override;
    void setEffectHandle(uint32_t handle);
    void drawSelf(Fw::DrawPane pane) override;
private:
    uint32_t m_handle=0;
};
