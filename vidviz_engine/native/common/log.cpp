/**
 * VidViz Engine - Logging Implementation
 */

#include "log.h"
#include <cstdarg>
#include <cstdio>
#include <cstring>

#if defined(__ANDROID__)
#include <android/log.h>
#endif

#if defined(__APPLE__)
#include <os/log.h>
#endif

namespace vidviz {

void LogInit() {
    // Platform specific init if needed
}

void Log(LogLevel level, const char* tag, const char* format, ...) {
    char buffer[2048];
    
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

#if defined(__ANDROID__)
    android_LogPriority priority;
    switch (level) {
        case LogLevel::Verbose: priority = ANDROID_LOG_VERBOSE; break;
        case LogLevel::Debug:   priority = ANDROID_LOG_DEBUG; break;
        case LogLevel::Info:    priority = ANDROID_LOG_INFO; break;
        case LogLevel::Warning: priority = ANDROID_LOG_WARN; break;
        case LogLevel::Error:   priority = ANDROID_LOG_ERROR; break;
        default:                priority = ANDROID_LOG_INFO; break;
    }
    __android_log_print(priority, tag, "%s", buffer);
#elif defined(__APPLE__)
    const char* levelStr;
    switch (level) {
        case LogLevel::Verbose: levelStr = "V"; break;
        case LogLevel::Debug:   levelStr = "D"; break;
        case LogLevel::Info:    levelStr = "I"; break;
        case LogLevel::Warning: levelStr = "W"; break;
        case LogLevel::Error:   levelStr = "E"; break;
        default:                levelStr = "I"; break;
    }
    static os_log_t s_log = nullptr;
    if (s_log == nullptr) {
        s_log = os_log_create("com.vidviz.engine", "native");
    }

    os_log_type_t type = OS_LOG_TYPE_DEFAULT;
    switch (level) {
        case LogLevel::Verbose:
        case LogLevel::Debug:
            type = OS_LOG_TYPE_DEBUG;
            break;
        case LogLevel::Info:
            type = OS_LOG_TYPE_INFO;
            break;
        case LogLevel::Warning:
            type = OS_LOG_TYPE_ERROR;
            break;
        case LogLevel::Error:
            type = OS_LOG_TYPE_FAULT;
            break;
        default:
            type = OS_LOG_TYPE_DEFAULT;
            break;
    }
    os_log_with_type(s_log, type, "[%{public}s/%{public}s] %{public}s", levelStr, tag ? tag : "", buffer);
    fprintf(stderr, "[%s/%s] %s\n", levelStr, tag ? tag : "", buffer);
    fflush(stderr);
#else
    const char* levelStr;
    switch (level) {
        case LogLevel::Verbose: levelStr = "V"; break;
        case LogLevel::Debug:   levelStr = "D"; break;
        case LogLevel::Info:    levelStr = "I"; break;
        case LogLevel::Warning: levelStr = "W"; break;
        case LogLevel::Error:   levelStr = "E"; break;
        default:                levelStr = "I"; break;
    }
    printf("[%s/%s] %s\n", levelStr, tag, buffer);
#endif
}

} // namespace vidviz
