cmake_minimum_required(VERSION 3.24)
project(AstraEffekseerDependency LANGUAGES C CXX)
set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)
include(../FetchEffekseer.cmake)
FetchContent_GetProperties(effekseer)
install(DIRECTORY "${effekseer_SOURCE_DIR}/Dev/Cpp/Effekseer/Effekseer"
    "${effekseer_SOURCE_DIR}/Dev/Cpp/EffekseerRendererCommon/EffekseerRendererCommon"
    DESTINATION include FILES_MATCHING PATTERN "*.h" PATTERN "*.inl")
if(NOT ASTRA_EFFEKSEER_GL_INSTALL_SOURCE)
    set(ASTRA_EFFEKSEER_GL_INSTALL_SOURCE "${effekseer_SOURCE_DIR}/Dev/Cpp/EffekseerRendererGL")
endif()
install(FILES "${ASTRA_EFFEKSEER_GL_INSTALL_SOURCE}/EffekseerRendererGL.h" DESTINATION include)
install(DIRECTORY "${ASTRA_EFFEKSEER_GL_INSTALL_SOURCE}/EffekseerRendererGL"
    DESTINATION include FILES_MATCHING PATTERN "*.h")
