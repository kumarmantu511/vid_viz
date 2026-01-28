#pragma once

#include "platform/ios/text/text_params.h"

namespace vidviz {
namespace ios {
namespace text {

TextAnimTransform computeTextAnimTransform(
    const ParsedTextParams& p,
    float timeSec,
    float texW,
    float texH
);

void applyTextDecorAnimQuantized(
    ParsedTextParams& p,
    float timeSec
);

float computeTextBiasXPx(const ParsedTextParams& p);

} // namespace text
} // namespace ios
} // namespace vidviz
