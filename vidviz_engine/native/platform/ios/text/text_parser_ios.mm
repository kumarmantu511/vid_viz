#import "platform/ios/text/text_parser_ios.h"

#include "common/minijson.h"

#include <cmath>

namespace vidviz {
namespace ios {
namespace text {

static inline float vvClamp(float v, float lo, float hi) {
    if (!std::isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline float vvClamp01(float v) {
    return vvClamp(v, 0.0f, 1.0f);
}

bool parseTextParams(const std::string& dataJson, ParsedTextParams& out) {
    out = ParsedTextParams{};
    if (dataJson.empty()) return false;

    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;

    const auto* root = parsed.value.asObject();
    if (!root) return false;

    const minijson::Value* textV = minijson::get(*root, "text");
    const auto* textO = textV ? textV->asObject() : nullptr;
    if (!textO) return false;

    minijson::getString(*textO, "title", &out.title);
    minijson::getString(*textO, "font", &out.font);
    minijson::getString(*textO, "effectType", &out.effectType);
    minijson::getString(*textO, "animType", &out.animType);

    double d = 0.0;
    if (minijson::getDouble(*textO, "fontSize", &d)) out.fontSizeN = static_cast<float>(d);
    if (minijson::getDouble(*textO, "alpha", &d)) out.alpha = static_cast<float>(d);
    if (minijson::getDouble(*textO, "x", &d)) out.x = static_cast<float>(d);
    if (minijson::getDouble(*textO, "y", &d)) out.y = static_cast<float>(d);

    if (minijson::getDouble(*textO, "borderw", &d)) out.borderW = static_cast<float>(d);
    if (minijson::getDouble(*textO, "shadowx", &d)) out.shadowX = static_cast<float>(d);
    if (minijson::getDouble(*textO, "shadowy", &d)) out.shadowY = static_cast<float>(d);
    if (minijson::getDouble(*textO, "shadowBlur", &d)) out.shadowBlur = static_cast<float>(d);
    if (minijson::getDouble(*textO, "padPx", &d)) out.padPx = static_cast<float>(d);
    if (minijson::getDouble(*textO, "boxborderw", &d)) out.boxBorderW = static_cast<float>(d);
    if (minijson::getDouble(*textO, "boxPad", &d)) out.boxPad = static_cast<float>(d);
    if (minijson::getDouble(*textO, "boxRadius", &d)) out.boxRadius = static_cast<float>(d);
    if (minijson::getDouble(*textO, "glowRadius", &d)) out.glowRadius = static_cast<float>(d);

    bool bDecor = false;
    if (minijson::getBool(*textO, "decorAlreadyScaled", &bDecor)) out.decorAlreadyScaled = bDecor;

    if (minijson::getDouble(*textO, "effectIntensity", &d)) out.effectIntensity = static_cast<float>(d);
    if (minijson::getDouble(*textO, "effectSpeed", &d)) out.effectSpeed = static_cast<float>(d);
    if (minijson::getDouble(*textO, "effectThickness", &d)) out.effectThickness = static_cast<float>(d);
    if (minijson::getDouble(*textO, "effectAngle", &d)) out.effectAngle = static_cast<float>(d);

    if (minijson::getDouble(*textO, "animSpeed", &d)) out.animSpeed = static_cast<float>(d);
    if (minijson::getDouble(*textO, "animAmplitude", &d)) out.animAmplitude = static_cast<float>(d);
    if (minijson::getDouble(*textO, "animPhase", &d)) out.animPhase = static_cast<float>(d);

    bool bb = false;
    if (minijson::getBool(*textO, "box", &bb)) out.box = bb;

    // Optional (present in struct, may or may not be emitted by UI)
    bool fb = false;
    if (minijson::getBool(*textO, "fakeBold", &fb)) out.fakeBold = fb;

    int64_t i64 = 0;
    if (minijson::getInt64(*textO, "fontColor", &i64)) out.fontColor = i64;
    if (minijson::getInt64(*textO, "bordercolor", &i64)) out.borderColor = i64;
    if (minijson::getInt64(*textO, "shadowcolor", &i64)) out.shadowColor = i64;
    if (minijson::getInt64(*textO, "boxcolor", &i64)) out.boxColor = i64;
    if (minijson::getInt64(*textO, "glowColor", &i64)) out.glowColor = i64;
    if (minijson::getInt64(*textO, "effectColorA", &i64)) out.effectColorA = i64;
    if (minijson::getInt64(*textO, "effectColorB", &i64)) out.effectColorB = i64;

    // Defensive clamps (avoid NaN/Inf drift)
    out.alpha = vvClamp01(out.alpha);
    out.x = vvClamp(out.x, -10000.0f, 10000.0f);
    out.y = vvClamp(out.y, -10000.0f, 10000.0f);

    out.fontSizeN = vvClamp(out.fontSizeN, 0.001f, 10.0f);

    out.borderW = vvClamp(out.borderW, 0.0f, 2000.0f);
    out.shadowX = vvClamp(out.shadowX, -2000.0f, 2000.0f);
    out.shadowY = vvClamp(out.shadowY, -2000.0f, 2000.0f);
    out.shadowBlur = vvClamp(out.shadowBlur, 0.0f, 2000.0f);
    out.boxBorderW = vvClamp(out.boxBorderW, 0.0f, 2000.0f);
    out.boxPad = vvClamp(out.boxPad, 0.0f, 2000.0f);
    out.boxRadius = vvClamp(out.boxRadius, 0.0f, 2000.0f);
    out.glowRadius = vvClamp(out.glowRadius, 0.0f, 2000.0f);

    out.effectIntensity = vvClamp01(out.effectIntensity);
    out.effectSpeed = vvClamp(out.effectSpeed, 0.0f, 100.0f);
    out.effectThickness = vvClamp(out.effectThickness, 0.0f, 10.0f);
    out.effectAngle = vvClamp(out.effectAngle, -36000.0f, 36000.0f);

    out.animSpeed = vvClamp(out.animSpeed, 0.0f, 10.0f);
    out.animAmplitude = vvClamp(out.animAmplitude, 0.0f, 10.0f);
    out.animPhase = vvClamp(out.animPhase, -1000.0f, 1000.0f);

    return !out.title.empty();
}

} // namespace text
} // namespace ios
} // namespace vidviz
