#pragma once

#include <string>
#include <cstdint>

namespace vidviz {
namespace android {

namespace utils {

std::string toLowerAscii(std::string s);
bool endsWithMp4(const std::string& path);
int32_t clampI32(int64_t v, int32_t lo, int32_t hi);
int32_t computeBitrate(int32_t width, int32_t height, int32_t fps, int32_t quality, const std::string& mime);

} // namespace utils

} // namespace android
} // namespace vidviz
