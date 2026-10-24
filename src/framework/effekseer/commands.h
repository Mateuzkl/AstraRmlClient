#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

namespace AstraParticles {
inline constexpr size_t MaxInstances = 128, MaxCommands = 512, MaxAssets = 4;
inline constexpr int ParticleBudget = 2048;
inline constexpr size_t MaxFileBytes = 8 * 1024 * 1024;
inline bool validPath(const std::string& path) {
    if (!path.starts_with("/effekseer/") || path.size() > 240 || path.back() == '/') return false;
    if (path.find_first_of("\\:") != std::string::npos ||
        std::any_of(path.begin(),path.end(),[](unsigned char c) { return c<32 || c==127; })) return false;
    size_t offset = 1;
    while (offset < path.size()) {
        const auto end = path.find('/', offset);
        const auto part = path.substr(offset, end == std::string::npos ? end : end-offset);
        if (part.empty() || part == "." || part == "..") return false;
        offset = end == std::string::npos ? path.size() : end+1;
    }
    return true;
}
struct Projected { uint32_t id; float x, y, scale; float tilt=0.f; };
struct Command {
    enum Type { Spawn, Stop, Clear } type = Clear;
    uint64_t epoch = 0;
    uint32_t id = 0;
    std::string path;
};
// Producers and the GL owner exchange values, never map/widget/entity pointers.
class CommandQueue {
public:
    bool push(Command command) {
        std::scoped_lock lock(mutex);
        if (commands.size() >= MaxCommands) return false;
        commands.push_back(std::move(command)); return true;
    }
    void clear() { std::scoped_lock lock(mutex); commands.clear(); }
    std::deque<Command> take() {
        std::scoped_lock lock(mutex); std::deque<Command> result; result.swap(commands); return result;
    }
private:
    std::mutex mutex;
    std::deque<Command> commands;
};
inline float frameStep(double seconds) {
    return std::isfinite(seconds) ? float(std::clamp(seconds, 0.0, 0.05) * 60.0) : 0.f;
}
}
