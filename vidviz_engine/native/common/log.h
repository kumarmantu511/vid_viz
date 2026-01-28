/**
 * VidViz Engine - Logging
 * 
 * Platform bağımsız loglama.
 */

#pragma once

#include <string>

namespace vidviz {

enum class LogLevel {
    Verbose = 0,
    Debug = 1,
    Info = 2,
    Warning = 3,
    Error = 4,
};

/// Initialize logging (platform specific implementation)
void LogInit();

/// Log message
void Log(LogLevel level, const char* tag, const char* format, ...);

// Convenience macros
#define VIDVIZ_TAG "VidVizEngine"

#define LOGV(fmt, ...) vidviz::Log(vidviz::LogLevel::Verbose, VIDVIZ_TAG, fmt, ##__VA_ARGS__)
#define LOGD(fmt, ...) vidviz::Log(vidviz::LogLevel::Debug, VIDVIZ_TAG, fmt, ##__VA_ARGS__)
#define LOGI(fmt, ...) vidviz::Log(vidviz::LogLevel::Info, VIDVIZ_TAG, fmt, ##__VA_ARGS__)
#define LOGW(fmt, ...) vidviz::Log(vidviz::LogLevel::Warning, VIDVIZ_TAG, fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) vidviz::Log(vidviz::LogLevel::Error, VIDVIZ_TAG, fmt, ##__VA_ARGS__)

} // namespace vidviz
