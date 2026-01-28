cmake_minimum_required(VERSION 3.18)
project(vidviz_engine VERSION 0.0.1 LANGUAGES C CXX)

# C++17 required
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# =============================================================================
# Platform Detection
# =============================================================================

if(ANDROID)
    message(STATUS "Building for Android")
    set(VIDVIZ_PLATFORM_ANDROID ON)
    set(VIDVIZ_PLATFORM_IOS OFF)
elseif(IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(STATUS "Building for iOS")
    set(VIDVIZ_PLATFORM_ANDROID OFF)
    set(VIDVIZ_PLATFORM_IOS ON)
else()
    message(FATAL_ERROR "Unsupported platform")
endif()

# =============================================================================
# Source Files
# =============================================================================

# Core (Platform Independent - %90 code here)
set(CORE_SOURCES
    core/engine.cpp
    core/engine.h
    core/timeline/timeline.cpp
    core/timeline/timeline.h
    core/parser/job_parser.cpp
    core/parser/job_parser.h
    core/effects/shader_manager.cpp
    core/effects/shader_manager.h
    core/effects/effect.h
)

# Common utilities
set(COMMON_SOURCES
    common/types.h
    common/log.h
    common/log.cpp
    common/minijson.h
    common/minijson.cpp
    common/render_math.h
    common/media_overlay.h
)

# Platform abstraction layer
set(PLATFORM_INTERFACE
    platform/renderer_interface.h
    platform/encoder_interface.h
)

# =============================================================================
# Android Platform Sources
# =============================================================================

if(VIDVIZ_PLATFORM_ANDROID)
    set(PLATFORM_SOURCES
        platform/android/android_bridge.cpp
        platform/android/vulkan_renderer.cpp
        platform/android/vulkan_renderer.h
        platform/android/mediacodec_encoder.cpp
        platform/android/mediacodec_encoder.h
        platform/android/mediacodec_utils.cpp
        platform/android/mediacodec_utils.h
        platform/android/mediacodec_remuxer.cpp
        platform/android/mediacodec_remuxer.h
        platform/android/renderer/gles/shader_source_utils.cpp
        platform/android/renderer/gles/shader_source_utils.h
        platform/android/renderer/gles/text_rasterizer.cpp
        platform/android/renderer/gles/text_rasterizer.h
        platform/android/renderer/gles/overlay_renderer.cpp
        platform/android/renderer/gles/overlay_renderer.h
        platform/android/renderer/gles/visualizer_renderer.cpp
        platform/android/renderer/gles/visualizer_renderer.h
        platform/android/gles_surface_renderer.cpp
        platform/android/gles_surface_renderer.h
        platform/android/ndk_video_decoder.cpp
        platform/android/ndk_video_decoder.h
        platform/android/gl_quad_renderer.cpp
        platform/android/gl_quad_renderer.h
        platform/android/ndk_video_decoder_gpu.cpp
        platform/android/ndk_video_decoder_gpu.h
        platform/android/gl_external_oes_renderer.cpp
        platform/android/gl_external_oes_renderer.h
    )
endif()

# =============================================================================
# iOS Platform Sources (compiled via Xcode, not CMake)
# =============================================================================

if(VIDVIZ_PLATFORM_IOS)
    # iOS uses Xcode for building, CMake is informational only
    set(PLATFORM_SOURCES
        platform/ios/ios_bridge.mm
        platform/ios/metal_renderer.mm
        platform/ios/metal_renderer.h
        platform/ios/avfoundation_encoder.mm
        platform/ios/avfoundation_encoder.h
    )
endif()

# =============================================================================
# Library Target
# =============================================================================

add_library(vidviz_engine SHARED
    ${CORE_SOURCES}
    ${COMMON_SOURCES}
    ${PLATFORM_INTERFACE}
    ${PLATFORM_SOURCES}
)

# Include directories
target_include_directories(vidviz_engine PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/common
    ${CMAKE_CURRENT_SOURCE_DIR}/platform
)

# =============================================================================
# Android Specific Configuration
# =============================================================================

if(VIDVIZ_PLATFORM_ANDROID)
    # Find required Android libraries
    find_library(log-lib log)
    find_library(android-lib android)
    find_library(vulkan-lib vulkan)
    find_library(mediandk-lib mediandk)
    find_library(egl-lib EGL)
    find_library(glesv2-lib GLESv2)
    find_library(jnigraphics-lib jnigraphics)
    
    target_link_libraries(vidviz_engine
        ${log-lib}
        ${android-lib}
        ${vulkan-lib}
        ${mediandk-lib}
        ${egl-lib}
        ${glesv2-lib}
        ${jnigraphics-lib}
    )
    
    # Vulkan validation layers (debug only)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        target_compile_definitions(vidviz_engine PRIVATE VIDVIZ_VULKAN_VALIDATION=1)
    endif()
endif()

# =============================================================================
# Compile Definitions
# =============================================================================

target_compile_definitions(vidviz_engine PRIVATE
    VIDVIZ_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
    VIDVIZ_VERSION_MINOR=${PROJECT_VERSION_MINOR}
    VIDVIZ_VERSION_PATCH=${PROJECT_VERSION_PATCH}
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_definitions(vidviz_engine PRIVATE VIDVIZ_DEBUG=1)
endif()

# =============================================================================
# Compiler Flags
# =============================================================================

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(vidviz_engine PRIVATE
        -Wall
        -Wextra
        -Werror=return-type
        -fvisibility=hidden
    )
    
    # Optimization flags for release
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        target_compile_options(vidviz_engine PRIVATE
            -O3
            -ffast-math
            -DNDEBUG
        )
    endif()
endif()

# =============================================================================
# Export symbols for FFI
# =============================================================================

# All public FFI functions are marked with VIDVIZ_API macro
target_compile_definitions(vidviz_engine PRIVATE
    VIDVIZ_BUILDING_LIBRARY=1
)
