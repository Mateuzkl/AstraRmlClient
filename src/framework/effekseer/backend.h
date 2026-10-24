#pragma once
#include <charconv>
#include <string_view>

namespace AstraParticles {
inline bool supportsGles3(std::string_view version) noexcept {
    constexpr std::string_view prefix="OpenGL ES ";
    if(!version.starts_with(prefix)) return false;
    version.remove_prefix(prefix.size());
    int major=0,minor=0;
    const auto* end=version.data()+version.size();
    const auto first=std::from_chars(version.data(),end,major);
    if(first.ec!=std::errc{} || first.ptr==end || *first.ptr!='.') return false;
    const auto second=std::from_chars(first.ptr+1,end,minor);
    return second.ec==std::errc{} && major>=3 && minor>=0;
}
}
