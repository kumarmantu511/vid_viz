#import "platform/ios/text/text_renderer_ios.h"
#import "platform/ios/text/text_renderer_ios_internal.h"

namespace vidviz {
namespace ios {
namespace text {

namespace {
static std::unordered_map<MetalRenderer*, TextRendererIOSImpl*>& vvImplMap() {
    static std::unordered_map<MetalRenderer*, TextRendererIOSImpl*> s;
    return s;
}
} // namespace

static TextRendererIOSImpl* vvGetImpl(MetalRenderer* owner) {
    auto& s = vvImplMap();
    auto it = s.find(owner);
    if (it != s.end()) return it->second;
    auto* p = new TextRendererIOSImpl(owner);
    s[owner] = p;
    return p;
}

static void vvFreeImpl(MetalRenderer* owner) {
    auto& s = vvImplMap();
    auto it = s.find(owner);
    if (it != s.end()) {
        delete it->second;
        s.erase(it);
    }
}

TextRendererIOS::TextRendererIOS(MetalRenderer* owner)
    : m_owner(owner) {}

TextRendererIOS::~TextRendererIOS() {
    cleanup();
}

void TextRendererIOS::cleanup() {
    if (!m_owner) return;
    TextRendererIOSImpl* impl = vvGetImpl(m_owner);
    if (impl) impl->cleanup();
    vvFreeImpl(m_owner);
    m_owner = nullptr;
}

static inline bool vvHasShaderEffect(const ParsedTextParams& p) {
    return !p.effectType.empty() &&
        p.effectType != "none" &&
        p.effectType != "inner_glow" &&
        p.effectType != "inner_shadow";
}

void TextRendererIOS::render(const Asset& asset, TimeMs localTime) {
    if (!m_owner) return;
    if (!m_owner->m_renderEncoder) return;
    if (m_owner->m_width <= 0 || m_owner->m_height <= 0) return;

    TextRendererIOSImpl* impl = vvGetImpl(m_owner);
    if (!impl) return;

    ParsedTextParams p;
    if (!parseTextParams(asset.dataJson, p)) return;
    if (p.title.empty()) return;

    p.alpha = vvTextClamp01(p.alpha);
    const float timeSec = static_cast<float>(localTime) / 1000.0f;

    float gAlpha = p.alpha;
    if (p.animType == "fade_in") {
        const float spd = vvTextClamp(p.animSpeed, 0.2f, 2.0f);
        const float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
        gAlpha = gAlpha * prog;
    } else if (p.animType == "blink") {
        const float spd = vvTextClamp(p.animSpeed, 0.2f, 2.0f);
        const float ph = std::isfinite(p.animPhase) ? p.animPhase : 0.0f;
        const float f = 0.5f + 0.5f * std::sin(timeSec * spd * 6.0f + ph);
        gAlpha = gAlpha * f;
    }
    gAlpha = vvTextClamp01(gAlpha);

    const TextAnimTransform xform = computeTextAnimTransform(p, timeSec, 0.0f, 0.0f);

    ParsedTextParams cacheP = p;
    applyTextDecorAnimQuantized(cacheP, timeSec);

    auto computeTextPadPx = [&](const ParsedTextParams& q) -> float {
        if (q.padPx >= 0.0f && std::isfinite(q.padPx)) {
            float pad = q.padPx;
            if (pad < 0.0f) pad = 0.0f;
            if (pad > 200.0f) pad = 200.0f;
            return pad;
        }
        float bleed = 0.0f;
        bleed = std::max(bleed, std::max(0.0f, q.glowRadius) * 2.0f);
        bleed = std::max(bleed, std::max(0.0f, q.shadowBlur) * 2.0f + (std::fabs(q.shadowX) + std::fabs(q.shadowY)));
        bleed = std::max(bleed, std::max(0.0f, q.borderW));
        if (q.box) {
            bleed = std::max(bleed, std::max(0.0f, q.boxBorderW) * 0.5f);
        }
        if (!std::isfinite(bleed)) bleed = 0.0f;
        if (bleed < 0.0f) bleed = 0.0f;
        if (bleed > 80.0f) bleed = 80.0f;
        return std::ceil(bleed) + 6.0f;
    };

    float padAfterScalePx = computeTextPadPx(cacheP);

    bool hasUiMetrics = false;
    float sxUi = 0.0f;
    float syUi = 0.0f;
    float uiDpr = 0.0f;
    {
        const float uiW = (m_owner->m_uiPlayerWidth > 0.0f) ? m_owner->m_uiPlayerWidth : 0.0f;
        const float uiH = (m_owner->m_uiPlayerHeight > 0.0f) ? m_owner->m_uiPlayerHeight : 0.0f;
        if (uiW > 0.0f && uiH > 0.0f) {
            hasUiMetrics = true;
            sxUi = static_cast<float>(m_owner->m_width) / uiW;
            syUi = static_cast<float>(m_owner->m_height) / uiH;
            uiDpr = (m_owner->m_uiDevicePixelRatio > 0.0f) ? m_owner->m_uiDevicePixelRatio : 0.0f;

            const float s = 0.5f * (sxUi + syUi);
            const float sStroke = std::max(sxUi, syUi);
            auto scaleDecor = [&](ParsedTextParams& q) {
                q.borderW *= s;
                q.glowRadius *= s;
                q.shadowBlur *= s;
                q.boxBorderW *= sStroke;
                q.boxPad *= s;
                q.boxRadius *= s;
                q.shadowX *= sxUi;
                q.shadowY *= syUi;
            };

            if (!p.decorAlreadyScaled) {
                scaleDecor(cacheP);
                padAfterScalePx = computeTextPadPx(cacheP);
            } else if (cacheP.animType == "shadow_swing") {
                cacheP.shadowX *= sxUi;
                cacheP.shadowY *= syUi;
            }
        }
    }

    int blurInStep = -1;
    if (p.animType == "blur_in") {
        const float spd = vvTextClamp(p.animSpeed, 0.2f, 2.0f);
        const float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
        blurInStep = static_cast<int>(std::round(prog * 30.0f));
        if (blurInStep < 0) blurInStep = 0;
        if (blurInStep > 30) blurInStep = 30;
    }

    float clipU = 1.0f;
    if (p.animType == "typing" || p.animType == "type_delete") {
        const float spd = vvTextClamp(p.animSpeed, 0.2f, 2.0f);
        const float t = timeSec * spd;
        float prog = 0.0f;
        if (p.animType == "typing") {
            prog = std::fmod(std::max(0.0f, t), 1.0f);
        } else {
            const float x = std::fmod(std::max(0.0f, t), 2.0f);
            prog = (x < 1.0f) ? x : (2.0f - x);
        }
        clipU = vvTextClamp01(prog);
    }

    const bool hasShaderEffect = vvHasShaderEffect(p);
    const bool bakeDecorOnly = hasShaderEffect;

    float fontPx = p.fontSizeN * static_cast<float>(m_owner->m_width);
    if (!std::isfinite(fontPx) || fontPx < 1.0f) fontPx = 16.0f;
    if (fontPx > 2048.0f) fontPx = 2048.0f;

    std::string key;
    key.reserve(asset.id.size() + p.title.size() + p.font.size() + 256);
    key += asset.id;
    key += "|";
    key += std::to_string(m_owner->m_width);
    key += "x";
    key += std::to_string(m_owner->m_height);
    key += "|";
    key += p.title;
    key += "|";
    key += p.font;
    key += "|";
    key += std::to_string(static_cast<int>(fontPx));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.fontColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.borderW * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.borderColor));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.shadowColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowX * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowY * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowBlur * 1000.0f));
    key += "|";
    key += (p.box ? "1" : "0");
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxBorderW * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.boxColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxPad * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxRadius * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.glowRadius * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.glowColor));
    key += "|";
    key += p.effectType;
    key += "|";
    key += std::to_string(static_cast<int>(p.effectIntensity * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.effectColorA));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.effectColorB));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectSpeed * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectThickness * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectAngle * 1000.0f));
    key += "|";
    key += p.animType;
    key += "|";
    key += std::to_string(static_cast<int>(p.animSpeed * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.animAmplitude * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.animPhase * 1000.0f));
    key += "|";
    key += (bakeDecorOnly ? "decorOnly" : "full");
    key += "|textAlignV2";

    if (!hasShaderEffect && blurInStep >= 0) {
        key += "|blurIn=";
        key += std::to_string(blurInStep);
    }

    auto getOrCreate = [&](std::unordered_map<std::string, VVTextTexInfo>& map, const std::string& k, bool maskOnly, bool decorOnly) -> VVTextTexInfo* {
        auto it = map.find(k);
        if (it != map.end() && it->second.tex) return &it->second;

        ParsedTextParams rp = cacheP;
        rp.alpha = 1.0f;

        std::vector<uint8_t> bgra;
        int32_t tw = 0;
        int32_t th = 0;
        if (!rasterizeTextBitmap(rp, fontPx, timeSec, maskOnly, decorOnly, bgra, tw, th)) {
            return nullptr;
        }

        id<MTLTexture> tex = impl->makeTextureBgra(bgra, tw, th);
        if (!tex) return nullptr;

        VVTextTexInfo ti;
        ti.tex = (__bridge_retained void*)tex;
        ti.w = tw;
        ti.h = th;
        map[k] = ti;
        return &map[k];
    };

    if (!impl->ensureQuadPipeline()) return;

    float xPx = p.x * static_cast<float>(m_owner->m_width) + xform.dxPx;
    float yPx = p.y * static_cast<float>(m_owner->m_height) + xform.dyPx;

    const bool hasExplicitPadPx = (p.padPx >= 0.0f && std::isfinite(p.padPx));
    if (hasExplicitPadPx) {
        xPx -= padAfterScalePx * xform.scaleX;
        yPx -= padAfterScalePx * xform.scaleY;
    }
    xPx += computeTextBiasXPx(p);

    auto snapPos = [&](float& xx, float& yy, float qw, float qh) {
        if (std::fabs(xform.rotationDeg) < 0.0001f) {
            const float tlx = xx + 0.5f * qw * (1.0f - xform.scaleX);
            const float tly = yy + 0.5f * qh * (1.0f - xform.scaleY);
            if (hasUiMetrics && uiDpr > 0.5f && sxUi > 0.0f && syUi > 0.0f) {
                const float tlxUi = tlx / sxUi;
                const float tlyUi = tly / syUi;
                const float tlxUiPhys = tlxUi * uiDpr;
                const float tlyUiPhys = tlyUi * uiDpr;
                const float stlxUiPhys = std::round(tlxUiPhys);
                const float stlyUiPhys = std::round(tlyUiPhys);
                const float stlx = (stlxUiPhys / uiDpr) * sxUi;
                const float stly = (stlyUiPhys / uiDpr) * syUi;
                xx = stlx - 0.5f * qw * (1.0f - xform.scaleX);
                yy = stly - 0.5f * qh * (1.0f - xform.scaleY);
            } else if (!hasUiMetrics) {
                const float stlx = std::round(tlx);
                const float stly = std::round(tly);
                xx = stlx - 0.5f * qw * (1.0f - xform.scaleX);
                yy = stly - 0.5f * qh * (1.0f - xform.scaleY);
            }
        }
    };

    if (!hasShaderEffect) {
        VVTextTexInfo* t = getOrCreate(impl->baked, key, false, false);
        if (!t || !t->tex || t->w <= 0 || t->h <= 0) return;

        float quadW = static_cast<float>(t->w);
        float uMax = 1.0f;
        if (clipU < 0.9999f) {
            uMax = clipU;
            quadW = std::max(1.0f, quadW * uMax);
        }

        snapPos(xPx, yPx, quadW, static_cast<float>(t->h));
        impl->drawTexturedQuad(impl->quadPipeline, (__bridge id<MTLTexture>)t->tex, nil, xPx, yPx, quadW, (float)t->h, xform.rotationDeg, xform.scaleX, xform.scaleY, gAlpha, uMax);
        return;
    }

    VVTextTexInfo* decor = getOrCreate(impl->baked, key, false, true);
    if (decor && decor->tex && decor->w > 0 && decor->h > 0) {
        float quadW = static_cast<float>(decor->w);
        float uMax = 1.0f;
        if (clipU < 0.9999f) {
            uMax = clipU;
            quadW = std::max(1.0f, quadW * uMax);
        }
        float dx = xPx;
        float dy = yPx;
        snapPos(dx, dy, quadW, static_cast<float>(decor->h));
        impl->drawTexturedQuad(impl->quadPipeline, (__bridge id<MTLTexture>)decor->tex, nil, dx, dy, quadW, (float)decor->h, xform.rotationDeg, xform.scaleX, xform.scaleY, gAlpha, uMax);
    }

    std::string maskKey = key;
    maskKey += "|mask";
    if (blurInStep >= 0) {
        maskKey += "|blurIn=";
        maskKey += std::to_string(blurInStep);
    }

    VVTextTexInfo* mask = getOrCreate(impl->masks, maskKey, true, false);
    if (!mask || !mask->tex || mask->w <= 0 || mask->h <= 0) return;

    impl->renderToEffectRT(
        p.effectType,
        mask->w,
        mask->h,
        timeSec,
        p.effectIntensity,
        p.effectSpeed,
        p.effectAngle,
        p.effectThickness,
        p.effectColorA,
        p.effectColorB
    );

    impl->restoreSceneEncoderWithLoad();
    if (!impl->ensureMaskCompositePipeline()) return;

    float quadW = static_cast<float>(mask->w);
    float uMax = 1.0f;
    if (clipU < 0.9999f) {
        uMax = clipU;
        quadW = std::max(1.0f, quadW * uMax);
    }

    float mx = xPx;
    float my = yPx;
    snapPos(mx, my, quadW, static_cast<float>(mask->h));

    impl->drawTexturedQuad(
        impl->maskCompositePipeline,
        (__bridge id<MTLTexture>)impl->effectRT.tex,
        (__bridge id<MTLTexture>)mask->tex,
        mx,
        my,
        quadW,
        (float)mask->h,
        xform.rotationDeg,
        xform.scaleX,
        xform.scaleY,
        gAlpha,
        uMax
    );
}

} // namespace text
} // namespace ios
} // namespace vidviz
