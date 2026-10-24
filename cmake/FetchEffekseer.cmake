include(FetchContent)
set(ASTRA_EFFEKSEER_BACKEND "OpenGL" CACHE STRING "Effekseer backend: OpenGL or ANGLE")
set(ASTRA_EFFEKSEER_ANGLE_INCLUDE_DIR "" CACHE PATH "ANGLE GLES/EGL headers")
set_property(CACHE ASTRA_EFFEKSEER_BACKEND PROPERTY STRINGS OpenGL ANGLE)
if(NOT ASTRA_EFFEKSEER_BACKEND MATCHES "^(OpenGL|ANGLE)$")
    message(FATAL_ERROR "Unknown Effekseer backend: ${ASTRA_EFFEKSEER_BACKEND}")
endif()
include(${CMAKE_CURRENT_LIST_DIR}/EffekseerAngle.cmake)
function(astra_fetch_effekseer)
    set(BUILD_SHARED_LIBS OFF)
    foreach(flag BUILD_VIEWER BUILD_EDITOR BUILD_TEST BUILD_EXAMPLES BUILD_TOOLS
                 BUILD_UNITYPLUGIN BUILD_DX9 BUILD_DX11 BUILD_DX12 BUILD_METAL
                 BUILD_VULKAN BUILD_WEBGPU USE_OPENAL USE_XAUDIO2 USE_DSOUND USE_OSM
                 NETWORK_ENABLED USE_LIBPNG_LOADER BUILD_WITH_EASY_PROFILER)
        set(${flag} OFF)
    endforeach()
    set(BUILD_GL ON)
    set(USE_OPENGL3 ON)
    set(USE_OPENGLES2 OFF)
    set(USE_OPENGLES3 OFF)
    set(USE_MSVC_RUNTIME_LIBRARY_DLL OFF)
    set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
    FetchContent_Declare(effekseer
        GIT_REPOSITORY https://github.com/effekseer/Effekseer.git
        GIT_TAG b87d1a2e3ff3731ba25cad34f8d8abeae382b21f
        GIT_SUBMODULES "") # 1.80.7 / 1807, runtime + common + desktop GL only
    FetchContent_MakeAvailable(effekseer)
    if(ASTRA_EFFEKSEER_BACKEND STREQUAL "ANGLE")
        astra_effekseer_angle("${effekseer_SOURCE_DIR}" "${effekseer_BINARY_DIR}")
        set(ASTRA_EFFEKSEER_GL_INSTALL_SOURCE "${ASTRA_EFFEKSEER_GL_INSTALL_SOURCE}" PARENT_SCOPE)
    endif()
endfunction()
astra_fetch_effekseer()
