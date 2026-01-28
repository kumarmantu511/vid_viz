# VidViz Engine CMake - Android JNI Entry Point
# Ana native kodları include eder

cmake_minimum_required(VERSION 3.18)
project(vidviz_engine_android LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Native source dizini
set(NATIVE_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../native")

# Core sources
set(CORE_SOURCES
    ${NATIVE_SRC_DIR}/core/engine.cpp
    ${NATIVE_SRC_DIR}/core/timeline/timeline.cpp
    ${NATIVE_SRC_DIR}/core/parser/job_parser.cpp
    ${NATIVE_SRC_DIR}/core/effects/shader_manager.cpp
    ${NATIVE_SRC_DIR}/common/log.cpp
    ${NATIVE_SRC_DIR}/common/minijson.cpp
)

# Android platform sources
set(ANDROID_SOURCES
    ${NATIVE_SRC_DIR}/platform/android/android_bridge.cpp
    ${NATIVE_SRC_DIR}/platform/android/vulkan_renderer.cpp
    ${NATIVE_SRC_DIR}/platform/android/mediacodec_encoder.cpp
    ${NATIVE_SRC_DIR}/platform/android/mediacodec_utils.cpp
    ${NATIVE_SRC_DIR}/platform/android/mediacodec_remuxer.cpp
    ${NATIVE_SRC_DIR}/platform/android/renderer/gles/shader_source_utils.cpp
    ${NATIVE_SRC_DIR}/platform/android/renderer/gles/text_rasterizer.cpp
    ${NATIVE_SRC_DIR}/platform/android/renderer/gles/overlay_renderer.cpp
    ${NATIVE_SRC_DIR}/platform/android/renderer/gles/visualizer_renderer.cpp
    ${NATIVE_SRC_DIR}/platform/android/gles_surface_renderer.cpp
    ${NATIVE_SRC_DIR}/platform/android/ndk_video_decoder.cpp
    ${NATIVE_SRC_DIR}/platform/android/gl_quad_renderer.cpp
    ${NATIVE_SRC_DIR}/platform/android/ndk_video_decoder_gpu.cpp
    ${NATIVE_SRC_DIR}/platform/android/gl_external_oes_renderer.cpp
    ${NATIVE_SRC_DIR}/platform/android/gl_framebuffer.cpp
)

# Create shared library
add_library(vidviz_engine SHARED
    ${CORE_SOURCES}
    ${ANDROID_SOURCES}
)

# Include directories
target_include_directories(vidviz_engine PRIVATE
    ${NATIVE_SRC_DIR}
    ${NATIVE_SRC_DIR}/core
    ${NATIVE_SRC_DIR}/common
    ${NATIVE_SRC_DIR}/platform
)

# Android libraries
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

# Compile definitions
target_compile_definitions(vidviz_engine PRIVATE
    VIDVIZ_BUILDING_LIBRARY=1
)

# Compiler flags
target_compile_options(vidviz_engine PRIVATE
    -Wall
    -Wextra
    -fvisibility=hidden
)
# ==========================================
# 16 KB Page Size Alignment Fix (Android 15+)
# ==========================================
target_link_options(vidviz_engine PRIVATE
    "-Wl,-z,max-page-size=16384"
)
