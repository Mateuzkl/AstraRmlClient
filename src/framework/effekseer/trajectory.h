#pragma once
#include <algorithm>
#include <cmath>

namespace AstraParticles {
struct FlightPoint { float x,y; };
inline FlightPoint trajectory(FlightPoint from,FlightPoint to,float progress) {
    const float t=std::isfinite(progress)?std::clamp(progress,0.f,1.f):0.f;
    // A small screen-space arc; endpoints remain exact. Values are world tiles.
    return {from.x+(to.x-from.x)*t,from.y+(to.y-from.y)*t-0.35f*std::sin(t*3.14159265f)};
}
}
