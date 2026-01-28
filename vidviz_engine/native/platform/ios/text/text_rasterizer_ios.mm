#import "platform/ios/text/text_rasterizer_ios.h"

#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

#include <algorithm>
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

static inline void vvArgbToRgba01(int64_t argb, CGFloat& r, CGFloat& g, CGFloat& b, CGFloat& a) {
    const uint32_t c = static_cast<uint32_t>(argb);
    a = static_cast<CGFloat>(((c >> 24) & 0xFFu)) / 255.0;
    r = static_cast<CGFloat>(((c >> 16) & 0xFFu)) / 255.0;
    g = static_cast<CGFloat>(((c >> 8) & 0xFFu)) / 255.0;
    b = static_cast<CGFloat>((c & 0xFFu)) / 255.0;
}

static CTFontRef vvCreateCtFont(const std::string& font, float fontPx) {
    const float sz = std::max(1.0f, fontPx);
    if (font.empty()) {
        return CTFontCreateWithName(CFSTR("Helvetica"), sz, nullptr);
    }

    std::string name = font;
    const size_t slash = name.find_last_of("/");
    if (slash != std::string::npos) name = name.substr(slash + 1);
    const size_t dot = name.find_last_of(".");
    if (dot != std::string::npos) name = name.substr(0, dot);

    CTFontRef ct = nullptr;
    if (!name.empty()) {
        NSString* nss = [NSString stringWithUTF8String:name.c_str()];
        if (nss && nss.length > 0) {
            ct = CTFontCreateWithName((__bridge CFStringRef)nss, sz, nullptr);
        }
    }

    if (!ct) {
        ct = CTFontCreateWithName(CFSTR("Helvetica"), sz, nullptr);
    }
    return ct;
}

static CGMutablePathRef vvCreateGlyphPath(CTLineRef line, CTFontRef font, CGPoint origin) {
    if (!line || !font) return nullptr;
    CGMutablePathRef path = CGPathCreateMutable();
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    if (!runs) return path;

    const CFIndex runCount = CFArrayGetCount(runs);
    for (CFIndex i = 0; i < runCount; i++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, i);
        if (!run) continue;
        const CFIndex glyphCount = CTRunGetGlyphCount(run);
        if (glyphCount <= 0) continue;

        std::vector<CGGlyph> glyphs(static_cast<size_t>(glyphCount));
        std::vector<CGPoint> positions(static_cast<size_t>(glyphCount));
        CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs.data());
        CTRunGetPositions(run, CFRangeMake(0, 0), positions.data());

        for (CFIndex g = 0; g < glyphCount; g++) {
            CGPathRef gpath = CTFontCreatePathForGlyph(font, glyphs[static_cast<size_t>(g)], nullptr);
            if (!gpath) continue;
            CGAffineTransform tr = CGAffineTransformMakeTranslation(origin.x + positions[static_cast<size_t>(g)].x, origin.y + positions[static_cast<size_t>(g)].y);
            CGPathAddPath(path, &tr, gpath);
            CGPathRelease(gpath);
        }
    }
    return path;
}

static inline int vvRoundInt(float v) {
    if (!std::isfinite(v)) return 0;
    return static_cast<int>(std::lround(v));
}

bool rasterizeTextBitmap(
    const ParsedTextParams& p,
    float fontPx,
    float timeSec,
    bool maskOnly,
    bool decorOnly,
    std::vector<uint8_t>& outBgra,
    int32_t& outW,
    int32_t& outH
) {
    (void)timeSec;
    outBgra.clear();
    outW = 0;
    outH = 0;

    if (p.title.empty()) return false;

    CTFontRef ctFont = vvCreateCtFont(p.font, fontPx);
    if (!ctFont) return false;

    CGFloat fr = 1.0, fg = 1.0, fb = 1.0, fa = 1.0;
    vvArgbToRgba01(maskOnly ? 0xFFFFFFFFu : p.fontColor, fr, fg, fb, fa);

    CGColorRef fillColor = [UIColor colorWithRed:fr green:fg blue:fb alpha:fa].CGColor;
    NSDictionary* attrs = @{
        (__bridge id)kCTFontAttributeName: (__bridge id)ctFont,
        (__bridge id)kCTForegroundColorAttributeName: (__bridge id)fillColor,
    };

    NSString* nsText = [NSString stringWithUTF8String:p.title.c_str()];
    if (!nsText) {
        CFRelease(ctFont);
        return false;
    }

    CFAttributedStringRef astr = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)nsText, (__bridge CFDictionaryRef)attrs);
    if (!astr) {
        CFRelease(ctFont);
        return false;
    }

    CTLineRef line = CTLineCreateWithAttributedString(astr);
    CFRelease(astr);
    if (!line) {
        CFRelease(ctFont);
        return false;
    }

    const CGRect bounds = CTLineGetBoundsWithOptions(line, kCTLineBoundsUseOpticalBounds);
    const float bw = std::max(1.0f, static_cast<float>(std::ceil(bounds.size.width)));
    const float bh = std::max(1.0f, static_cast<float>(std::ceil(bounds.size.height)));

    float bleed = 0.0f;
    bleed = std::max(bleed, std::max(0.0f, p.glowRadius) * 2.0f);
    bleed = std::max(bleed, std::max(0.0f, p.shadowBlur) * 2.0f + (std::fabs(p.shadowX) + std::fabs(p.shadowY)));
    bleed = std::max(bleed, std::max(0.0f, p.borderW));
    if (p.box) {
        bleed = std::max(bleed, std::max(0.0f, p.boxBorderW) * 0.5f);
    }
    bleed = vvClamp(bleed, 0.0f, 80.0f);

    int pad = 0;
    if (p.padPx >= 0.0f && std::isfinite(p.padPx)) {
        const float pp = vvClamp(p.padPx, 0.0f, 200.0f);
        pad = vvRoundInt(pp);
    } else {
        pad = static_cast<int>(std::ceil(bleed)) + 6;
    }

    int boxPad = 0;
    if (p.box) {
        boxPad = static_cast<int>(std::ceil(vvClamp(p.boxPad, 0.0f, 1024.0f)));
    }

    const int w = std::min(4096, static_cast<int>(std::ceil(bw)) + pad * 2 + boxPad * 2);
    const int h = std::min(4096, static_cast<int>(std::ceil(bh)) + pad * 2 + boxPad * 2);
    if (w <= 0 || h <= 0) {
        CFRelease(line);
        CFRelease(ctFont);
        return false;
    }

    outW = w;
    outH = h;
    outBgra.assign(static_cast<size_t>(w) * static_cast<size_t>(h) * 4u, 0);

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(outBgra.data(), w, h, 8, w * 4, cs, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(cs);
    if (!ctx) {
        outBgra.clear();
        outW = 0;
        outH = 0;
        CFRelease(line);
        CFRelease(ctFont);
        return false;
    }

    CGContextClearRect(ctx, CGRectMake(0, 0, w, h));
    CGContextSetAllowsAntialiasing(ctx, true);
    CGContextSetShouldAntialias(ctx, true);

    CGContextTranslateCTM(ctx, 0, h);
    CGContextScaleCTM(ctx, 1.0, -1.0);

    const CGPoint pos = CGPointMake(static_cast<CGFloat>(pad + boxPad) - bounds.origin.x, static_cast<CGFloat>(pad + boxPad) - bounds.origin.y);

    auto setFillFromArgb = [&](int64_t argb) {
        CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
        vvArgbToRgba01(argb, r, g, b, a);
        CGContextSetRGBFillColor(ctx, r, g, b, a);
    };

    auto setStrokeFromArgb = [&](int64_t argb) {
        CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
        vvArgbToRgba01(argb, r, g, b, a);
        CGContextSetRGBStrokeColor(ctx, r, g, b, a);
    };

    auto drawLineAt = [&](CGPoint p0) {
        CGContextSetTextPosition(ctx, p0.x, p0.y);
        CTLineDraw(line, ctx);
    };

    if (!maskOnly && p.box) {
        const CGFloat leftX = static_cast<CGFloat>(pad);
        const CGFloat topY = static_cast<CGFloat>(pad);
        const CGFloat rightX = static_cast<CGFloat>(pad + boxPad * 2) + static_cast<CGFloat>(bw);
        const CGFloat bottomY = static_cast<CGFloat>(pad + boxPad * 2) + static_cast<CGFloat>(bh);
        const CGFloat rectW = std::max<CGFloat>(0.0, rightX - leftX);
        const CGFloat rectH = std::max<CGFloat>(0.0, bottomY - topY);
        const CGFloat maxRad = 0.5 * std::min(rectW, rectH);
        const CGFloat rad = std::max<CGFloat>(0.0, std::min(maxRad, static_cast<CGFloat>(std::max(0.0f, p.boxRadius))));

        setFillFromArgb(p.boxColor);
        UIBezierPath* bp = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX, topY, rectW, rectH) cornerRadius:rad];
        CGContextAddPath(ctx, bp.CGPath);
        CGContextFillPath(ctx);

        if (p.boxBorderW > 0.0f) {
            setStrokeFromArgb(p.borderColor);
            CGContextSetLineWidth(ctx, static_cast<CGFloat>(std::max(0.0f, p.boxBorderW)));
            CGContextAddPath(ctx, bp.CGPath);
            CGContextStrokePath(ctx);
        }
    }

    const bool isInnerGlow = (!maskOnly) && (p.effectType == "inner_glow");
    const bool isInnerShadow = (!maskOnly) && (p.effectType == "inner_shadow");
    const bool useInner = isInnerGlow || isInnerShadow;

    CGMutablePathRef glyphPath = nullptr;
    if ((!maskOnly && p.borderW > 0.0f) || useInner) {
        glyphPath = vvCreateGlyphPath(line, ctFont, pos);
    }

    auto drawOuterGlow = [&]() {
        if (maskOnly) return;
        if (p.glowRadius <= 0.0f) return;
        CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
        vvArgbToRgba01(p.glowColor, r, g, b, a);
        const CGFloat rad = static_cast<CGFloat>(std::max(0.0f, p.glowRadius));
        CGColorRef col = [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor;
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0.0, 0.0), rad, col);
        CGContextSetRGBFillColor(ctx, r, g, b, a);
        drawLineAt(pos);
        CGContextRestoreGState(ctx);
    };

    auto drawShadow = [&]() {
        if (maskOnly) return;
        if (p.shadowBlur <= 0.0f && p.shadowX == 0.0f && p.shadowY == 0.0f) return;
        CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
        vvArgbToRgba01(p.shadowColor, r, g, b, a);
        const CGFloat blur = static_cast<CGFloat>(std::max(0.0f, p.shadowBlur));
        const CGFloat offX = static_cast<CGFloat>(p.shadowX);
        const CGFloat offY = static_cast<CGFloat>(-p.shadowY);
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, r, g, b, a);
        if (blur > 0.0f) {
            CGColorRef col = [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor;
            CGContextSetShadowWithColor(ctx, CGSizeMake(offX, offY), blur, col);
            drawLineAt(pos);
        } else {
            drawLineAt(CGPointMake(pos.x + offX, pos.y + offY));
        }
        CGContextRestoreGState(ctx);
    };

    auto drawOutline = [&]() {
        if (maskOnly) return;
        if (!glyphPath) return;
        if (p.borderW <= 0.0f) return;
        CGContextSaveGState(ctx);
        setStrokeFromArgb(p.borderColor);
        CGContextSetLineWidth(ctx, static_cast<CGFloat>(std::max(0.0f, p.borderW)));
        CGContextAddPath(ctx, glyphPath);
        CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
    };

    auto drawFillOnly = [&]() {
        if (decorOnly) return;
        CGContextSaveGState(ctx);
        setFillFromArgb(maskOnly ? 0xFFFFFFFFu : p.fontColor);
        drawLineAt(pos);
        CGContextRestoreGState(ctx);
    };

    if (p.animType == "blur_in" && !maskOnly && !decorOnly) {
        float spd = p.animSpeed;
        if (!std::isfinite(spd)) spd = 1.0f;
        if (spd < 0.2f) spd = 0.2f;
        if (spd > 2.0f) spd = 2.0f;
        float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
        prog = vvClamp01(prog);
        const int step = static_cast<int>(std::lround(prog * 30.0f));
        const float q = static_cast<float>(std::max(0, std::min(30, step))) / 30.0f;
        float blurR = (1.0f - q) * 12.0f;
        blurR = vvClamp(blurR, 0.0f, 32.0f);

        CGFloat r = fr, g = fg, b = fb, a = fa;
        CGContextSaveGState(ctx);
        CGColorRef col = [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor;
        CGContextSetShadowWithColor(ctx, CGSizeMake(0.0, 0.0), static_cast<CGFloat>(blurR), col);
        CGContextSetRGBFillColor(ctx, r, g, b, a);
        drawLineAt(pos);
        CGContextRestoreGState(ctx);
    }

    if (useInner && glyphPath) {
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, glyphPath);
        CGContextClip(ctx);
        if (isInnerGlow) {
            CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
            vvArgbToRgba01(p.glowColor, r, g, b, a);
            const CGFloat rad = static_cast<CGFloat>(std::max(0.0f, p.glowRadius));
            CGColorRef col = [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor;
            CGContextSetShadowWithColor(ctx, CGSizeMake(0.0, 0.0), rad, col);
            CGContextSetRGBFillColor(ctx, r, g, b, a);
            CGContextAddPath(ctx, glyphPath);
            CGContextFillPath(ctx);
        } else {
            CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
            vvArgbToRgba01(p.shadowColor, r, g, b, a);
            const CGFloat blur = static_cast<CGFloat>(std::max(0.0f, p.shadowBlur));
            const CGFloat offX = static_cast<CGFloat>(p.shadowX);
            const CGFloat offY = static_cast<CGFloat>(-p.shadowY);
            CGColorRef col = [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor;
            CGContextSetShadowWithColor(ctx, CGSizeMake(offX, offY), blur, col);
            CGContextSetRGBFillColor(ctx, r, g, b, a);
            CGContextAddPath(ctx, glyphPath);
            CGContextFillPath(ctx);
        }
        CGContextRestoreGState(ctx);
    } else {
        drawOuterGlow();
        drawShadow();
        drawOutline();
        drawFillOnly();
    }

    if (glyphPath) {
        CGPathRelease(glyphPath);
        glyphPath = nullptr;
    }

    CGContextRelease(ctx);
    CFRelease(line);
    CFRelease(ctFont);
    return true;
}

} // namespace text
} // namespace ios
} // namespace vidviz
