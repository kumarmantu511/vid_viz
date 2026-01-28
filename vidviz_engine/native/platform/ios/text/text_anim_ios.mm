#import "platform/ios/text/text_anim_ios.h"

#include <algorithm>
#include <cmath>
#include <cctype>

namespace vidviz {
namespace ios {
namespace text {

static int quantizeStep(float v01, int steps) {
    if (!std::isfinite(v01)) v01 = 0.0f;
    if (v01 < 0.0f) v01 = 0.0f;
    if (v01 > 1.0f) v01 = 1.0f;
    if (steps < 1) steps = 1;
    const float s = std::round(v01 * static_cast<float>(steps));
    int i = static_cast<int>(s);
    if (i < 0) i = 0;
    if (i > steps) i = steps;
    return i;
}

static float clampFinite(float v, float lo, float hi, float fallback) {
    if (!std::isfinite(v)) return fallback;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static float fract01(float x) {
    if (!std::isfinite(x)) return 0.0f;
    const float f = std::fmod(std::max(0.0f, x), 1.0f);
    return (f < 0.0f) ? 0.0f : f;
}

void applyTextDecorAnimQuantized(ParsedTextParams& p, float timeSec) {
    float spd = p.animSpeed;
    if (!std::isfinite(spd)) spd = 1.0f;
    if (spd < 0.2f) spd = 0.2f;
    if (spd > 2.0f) spd = 2.0f;

    if (p.animType == "glow_pulse") {
        float r = p.glowRadius;
        if (!std::isfinite(r)) r = 0.0f;
        if (r < 0.0f) r = 0.0f;
        const float s01 = 0.5f * (1.0f + std::sin(timeSec * spd));
        const int step = quantizeStep(s01, 30);
        const float sq01 = static_cast<float>(step) / 30.0f;
        float rr = r * (0.5f + sq01);
        rr = clampFinite(rr, 0.0f, 40.0f, 0.0f);
        p.glowRadius = rr;
    } else if (p.animType == "outline_pulse") {
        float bw = p.borderW;
        if (!std::isfinite(bw)) bw = 0.0f;
        if (bw < 0.0f) bw = 0.0f;
        const float s01 = 0.5f * (1.0f + std::sin(timeSec * spd));
        const int step = quantizeStep(s01, 30);
        const float sq01 = static_cast<float>(step) / 30.0f;
        float bbw = bw * (0.5f + sq01);
        bbw = clampFinite(bbw, 0.0f, 20.0f, 0.0f);
        p.borderW = bbw;
    } else if (p.animType == "shadow_swing") {
        float A = p.animAmplitude;
        if (!std::isfinite(A)) A = 1.0f;
        if (A < 1.0f) A = 1.0f;
        if (A > 500.0f) A = 500.0f;

        const float kTwoPi = 6.283185307f;
        float ang = timeSec * spd;
        if (!std::isfinite(ang)) ang = 0.0f;
        ang = std::fmod(std::max(0.0f, ang), kTwoPi);
        const float phase01 = ang / kTwoPi;
        const int step = quantizeStep(phase01, 60);
        const float angQ = (static_cast<float>(step) / 60.0f) * kTwoPi;

        float sx = A * std::sin(angQ);
        float sy = A * std::cos(angQ);
        if (!std::isfinite(sx)) sx = 0.0f;
        if (!std::isfinite(sy)) sy = 0.0f;
        p.shadowX = sx;
        p.shadowY = sy;
    }
}

TextAnimTransform computeTextAnimTransform(
    const ParsedTextParams& p,
    float timeSec,
    float texW,
    float texH
) {
    (void)texW;
    (void)texH;

    TextAnimTransform t;
    const std::string& a = p.animType;

    const float kPi = 3.1415926535f;

    const float spd = clampFinite(p.animSpeed, 0.2f, 2.0f, 1.0f);
    const float amp = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
    const float ph = std::isfinite(p.animPhase) ? p.animPhase : 0.0f;

    if (a == "bounce") {
        t.dyPx += std::sin(timeSec * spd) * amp;
    } else if (a == "jitter") {
        t.dxPx += std::sin(timeSec * spd + ph) * amp * 0.5f;
        t.dyPx += std::cos(timeSec * (spd * 1.3f) + ph * 1.7f) * amp * 0.5f;
    }

    if (a == "marquee") {
        const float w = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        const float x = fract01(timeSec * spd) * w;
        t.dxPx += -x;
    } else if (a == "pulse") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        float k = 1.0f + 0.05f * aPx * std::sin(timeSec * spd + ph);
        k = clampFinite(k, 0.1f, 5.0f, 1.0f);
        t.scaleX *= k;
        t.scaleY *= k;
    } else if (a == "slide_lr") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dxPx += fract01(timeSec * spd) * aPx;
    } else if (a == "slide_rl") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dxPx += -fract01(timeSec * spd) * aPx;
    } else if (a == "shake_h") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dxPx += std::sin(timeSec * spd * 6.0f) * aPx * 0.5f;
    } else if (a == "shake_v") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dyPx += std::sin(timeSec * spd * 6.0f) * aPx * 0.5f;
    } else if (a == "rotate") {
        const float aDeg = clampFinite(p.animAmplitude, 0.0f, 720.0f, 0.0f);
        t.rotationDeg += aDeg * std::sin(timeSec * spd);
    } else if (a == "zoom_in") {
        const float p01 = fract01(timeSec * spd);
        const float k = 0.7f + 0.3f * p01;
        t.scaleX *= k;
        t.scaleY *= k;
    } else if (a == "slide_up") {
        float aPx = p.animAmplitude;
        if (!std::isfinite(aPx)) aPx = 40.0f;
        aPx = clampFinite(aPx, 0.0f, 500.0f, 40.0f);
        const float p01 = fract01(timeSec * spd);
        t.dyPx += (1.0f - p01) * aPx;
    } else if (a == "flip_x") {
        const float kx = std::cos(timeSec * spd * kPi);
        const float mag = clampFinite(std::fabs(kx), 0.1f, 1.0f, 1.0f);
        t.scaleX *= mag * ((kx >= 0.0f) ? 1.0f : -1.0f);
    } else if (a == "flip_y") {
        const float ky = std::cos(timeSec * spd * kPi);
        const float mag = clampFinite(std::fabs(ky), 0.1f, 1.0f, 1.0f);
        t.scaleY *= mag * ((ky >= 0.0f) ? 1.0f : -1.0f);
    } else if (a == "pop_in") {
        const float p01 = fract01(timeSec * spd);
        const float eased = 1.0f - std::pow(1.0f - p01, 3.0f);
        const float k = 0.6f + 0.4f * eased;
        t.scaleX *= k;
        t.scaleY *= k;
    } else if (a == "rubber_band") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 100.0f, 0.0f);
        const float f = clampFinite((aPx / 40.0f), 0.0f, 0.4f, 0.0f);
        const float s = std::sin(timeSec * spd * 4.0f + ph);
        float kx = 1.0f + f * s;
        float ky = 1.0f - f * s;
        kx = clampFinite(kx, -5.0f, 5.0f, 1.0f);
        ky = clampFinite(ky, -5.0f, 5.0f, 1.0f);
        t.scaleX *= kx;
        t.scaleY *= ky;
    }

    return t;
}

float computeTextBiasXPx(const ParsedTextParams& p) {
    const bool hasExplicitPadPx = (p.padPx >= 0.0f && std::isfinite(p.padPx));
    if (!hasExplicitPadPx) return 0.0f;

    std::string fontLower;
    fontLower.reserve(p.font.size());
    for (const char c : p.font) {
        fontLower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
    }

    const bool isPacifico = (fontLower.find("pacifico") != std::string::npos);
    const bool isItalic = (fontLower.find("italic") != std::string::npos);
    const bool isSourceSans = (fontLower.find("sourcesans") != std::string::npos);
    const int titleLen = static_cast<int>(p.title.size());

    float bias = 0.0f;
    if (isPacifico) {
        bias -= 4.0f;
    }
    if (isItalic && isSourceSans) {
        bias += 5.0f;
    } else if (titleLen >= 6) {
        bias += 4.0f;
    }
    return bias;
}

} // namespace text
} // namespace ios
} // namespace vidviz
