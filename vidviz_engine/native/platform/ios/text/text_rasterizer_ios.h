#pragma once

#include <cstdint>
#include <vector>

#include "platform/ios/text/text_params.h"

namespace vidviz {
namespace ios {
namespace text {

bool rasterizeTextBitmap(
    const ParsedTextParams& p,
    float fontPx,
    float timeSec,
    bool maskOnly,
    bool decorOnly,
    std::vector<uint8_t>& outBgra,
    int32_t& outW,
    int32_t& outH
);

} // namespace text
} // namespace ios
} // namespace vidviz
