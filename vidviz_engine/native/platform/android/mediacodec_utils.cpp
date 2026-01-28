#include "mediacodec_utils.h"

#include <algorithm>
#include <cctype>

namespace vidviz {
namespace android {
namespace utils {

std::string toLowerAscii(std::string s) {
    for (char& c : s) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    return s;
}

bool endsWithMp4(const std::string& path) {
    const std::string p = toLowerAscii(path);
    if (p.size() < 4) return false;
    return p.rfind(".mp4") == (p.size() - 4);
}

int32_t clampI32(int64_t v, int32_t lo, int32_t hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return static_cast<int32_t>(v);
}

int32_t computeBitrate(int32_t width, int32_t height, int32_t fps, int32_t quality, const std::string& mime) {
    // bitrate = bpp * fps * width * height
    // H.264: medium quality at 1080p30 ~ 10Mbps => bpp ~ 0.16
    // HEVC: can be lower for same perceived quality.
    float bpp = 0.16f;
    switch (quality) {
        case 0: bpp = 0.11f; break;
        case 1: bpp = 0.16f; break;
        case 2: bpp = 0.22f; break;
        default: bpp = 0.16f; break;
    }

    const std::string m = toLowerAscii(mime);
    if (m.find("hevc") != std::string::npos || m.find("h265") != std::string::npos) {
        bpp *= 0.70f;
    }

    const int64_t w = std::max<int32_t>(16, width);
    const int64_t h = std::max<int32_t>(16, height);
    const int64_t f = std::max<int32_t>(1, fps);

    const double br = static_cast<double>(w) * static_cast<double>(h) * static_cast<double>(f) * static_cast<double>(bpp);

    const bool isUhd = (w * h) >= 8'000'000;
    const bool isHighFps = f >= 50;

    int32_t maxBr = 60'000'000;
    if (isUhd && isHighFps) {
        const std::string m = toLowerAscii(mime);
        if (m.find("hevc") != std::string::npos || m.find("h265") != std::string::npos) {
            maxBr = 30'000'000;
        } else {
            maxBr = 40'000'000;
        }
    }

    return clampI32(static_cast<int64_t>(br), 1'000'000, maxBr);
}

} // namespace utils
} // namespace android
} // namespace vidviz
