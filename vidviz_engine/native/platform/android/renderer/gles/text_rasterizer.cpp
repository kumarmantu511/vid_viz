#include "platform/android/renderer/gles/text_rasterizer.h"

#include "common/log.h"

#include <android/bitmap.h>
#include <jni.h>

#include <algorithm>
#include <cctype>
#include <cmath>
 #include <cstring>

namespace vidviz {
namespace android {

extern JavaVM* g_vidvizJvm;
JavaVM* getJavaVmFallback();

namespace gles {

namespace {

static jobject g_assetManager = nullptr;

static jobject getFlutterAssetManager(JNIEnv* env) {
    if (g_assetManager) return g_assetManager;

    jclass atCls = env->FindClass("android/app/ActivityThread");
    if (!atCls) return nullptr;
    jmethodID curApp = env->GetStaticMethodID(atCls, "currentApplication", "()Landroid/app/Application;");
    if (!curApp) {
        env->DeleteLocalRef(atCls);
        return nullptr;
    }
    jobject app = env->CallStaticObjectMethod(atCls, curApp);
    env->DeleteLocalRef(atCls);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
    if (!app) return nullptr;

    jclass appCls = env->GetObjectClass(app);
    if (!appCls) {
        env->DeleteLocalRef(app);
        return nullptr;
    }
    jmethodID getAssets = env->GetMethodID(appCls, "getAssets", "()Landroid/content/res/AssetManager;");
    if (!getAssets) {
        env->DeleteLocalRef(appCls);
        env->DeleteLocalRef(app);
        return nullptr;
    }
    jobject am = env->CallObjectMethod(app, getAssets);
    env->DeleteLocalRef(appCls);
    env->DeleteLocalRef(app);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
    if (!am) return nullptr;

    g_assetManager = env->NewGlobalRef(am);
    env->DeleteLocalRef(am);
    return g_assetManager;
}

} // namespace

bool rasterizeTextBitmap(
    const ParsedTextParams& p,
    float fontPx,
    float timeSec,
    bool maskOnly,
    bool decorOnly,
    std::vector<uint8_t>& outRgba,
    int32_t& outW,
    int32_t& outH,
    float* outInkCenterDxPx,
    float* outInkCenterDyPx
) {
    (void)timeSec;
    static int s_textParityCount = 0;
    outRgba.clear();
    outW = 0;
    outH = 0;
    if (outInkCenterDxPx) *outInkCenterDxPx = 0.0f;
    if (outInkCenterDyPx) *outInkCenterDyPx = 0.0f;
    if (p.title.empty()) return false;
    if (!g_vidvizJvm) {
        g_vidvizJvm = getJavaVmFallback();
    }
    if (!g_vidvizJvm) return false;

    JNIEnv* env = nullptr;
    bool didAttach = false;
    const jint envRes = g_vidvizJvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (envRes == JNI_EDETACHED) {
        if (g_vidvizJvm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
            return false;
        }
        didAttach = true;
    } else if (envRes != JNI_OK) {
        return false;
    }

    if (env->PushLocalFrame(512) != 0) {
        if (didAttach) {
            g_vidvizJvm->DetachCurrentThread();
        }
        return false;
    }

    bool ok = false;
    do {
        jclass paintCls = env->FindClass("android/graphics/Paint");
        jclass textPaintCls = env->FindClass("android/text/TextPaint");
        jclass rectCls = env->FindClass("android/graphics/Rect");
        jclass rectFCls = env->FindClass("android/graphics/RectF");
        jclass canvasCls = env->FindClass("android/graphics/Canvas");
        jclass bitmapCls = env->FindClass("android/graphics/Bitmap");
        jclass bitmapCfgCls = env->FindClass("android/graphics/Bitmap$Config");
        jclass typefaceCls = env->FindClass("android/graphics/Typeface");
        jclass styleCls = env->FindClass("android/graphics/Paint$Style");
        jclass pathCls = env->FindClass("android/graphics/Path");
        if (!paintCls || !textPaintCls || !rectCls || !rectFCls || !canvasCls || !bitmapCls || !bitmapCfgCls || !typefaceCls || !styleCls) break;
        jclass porterDuffXferCls = env->FindClass("android/graphics/PorterDuffXfermode");
        jclass porterDuffCls = env->FindClass("android/graphics/PorterDuff");
        jclass porterDuffModeCls = env->FindClass("android/graphics/PorterDuff$Mode");
        jclass blurMaskFilterCls = env->FindClass("android/graphics/BlurMaskFilter");
        jclass blurStyleCls = env->FindClass("android/graphics/BlurMaskFilter$Blur");

        jmethodID paintCtor = env->GetMethodID(textPaintCls, "<init>", "()V");
        jmethodID rectFCtor = env->GetMethodID(rectFCls, "<init>", "(FFFF)V");
        if (!paintCtor) break;
        jobject paint = env->NewObject(textPaintCls, paintCtor);
        if (!paint) break;

        jmethodID setAntiAlias = env->GetMethodID(paintCls, "setAntiAlias", "(Z)V");
        jmethodID setSubpixel = env->GetMethodID(paintCls, "setSubpixelText", "(Z)V");
        jmethodID setFakeBoldText = env->GetMethodID(paintCls, "setFakeBoldText", "(Z)V");
        jmethodID setTextSize = env->GetMethodID(paintCls, "setTextSize", "(F)V");
        jmethodID setColor = env->GetMethodID(paintCls, "setColor", "(I)V");
        jmethodID setStyle = env->GetMethodID(paintCls, "setStyle", "(Landroid/graphics/Paint$Style;)V");
        jmethodID setStrokeWidth = env->GetMethodID(paintCls, "setStrokeWidth", "(F)V");
        jmethodID setShadowLayer = env->GetMethodID(paintCls, "setShadowLayer", "(FFFI)V");
        jmethodID clearShadowLayer = env->GetMethodID(paintCls, "clearShadowLayer", "()V");
        jmethodID setMaskFilter = env->GetMethodID(paintCls, "setMaskFilter", "(Landroid/graphics/MaskFilter;)Landroid/graphics/MaskFilter;");
        jmethodID setXfermode = env->GetMethodID(paintCls, "setXfermode", "(Landroid/graphics/Xfermode;)Landroid/graphics/Xfermode;");
        jmethodID measureText = env->GetMethodID(paintCls, "measureText", "(Ljava/lang/String;)F");
        jmethodID getTextBounds = env->GetMethodID(paintCls, "getTextBounds", "(Ljava/lang/String;IILandroid/graphics/Rect;)V");
        jmethodID getFontMetrics = env->GetMethodID(paintCls, "getFontMetrics", "()Landroid/graphics/Paint$FontMetrics;");
        jmethodID setTypeface = env->GetMethodID(paintCls, "setTypeface", "(Landroid/graphics/Typeface;)Landroid/graphics/Typeface;");
        if (!setAntiAlias || !setSubpixel || !setTextSize || !setColor || !setStyle || !setStrokeWidth || !setShadowLayer || !measureText || !getFontMetrics) break;

        env->CallVoidMethod(paint, setAntiAlias, JNI_TRUE);
        env->CallVoidMethod(paint, setSubpixel, JNI_TRUE);
        if (setFakeBoldText) {
            env->CallVoidMethod(paint, setFakeBoldText, p.fakeBold ? JNI_TRUE : JNI_FALSE);
        }
        if (!std::isfinite(fontPx) || fontPx < 1.0f) fontPx = 16.0f;
        env->CallVoidMethod(paint, setTextSize, fontPx);

        jobject assetManager = getFlutterAssetManager(env);
        if (assetManager && setTypeface && !p.font.empty()) {
            jmethodID createFromAsset = env->GetStaticMethodID(
                typefaceCls,
                "createFromAsset",
                "(Landroid/content/res/AssetManager;Ljava/lang/String;)Landroid/graphics/Typeface;"
            );
            if (createFromAsset) {
                const std::string fullPath = std::string("flutter_assets/fonts/") + p.font;
                jstring jpath = env->NewStringUTF(fullPath.c_str());
                jobject tf = env->CallStaticObjectMethod(typefaceCls, createFromAsset, assetManager, jpath);
                env->DeleteLocalRef(jpath);
                if (env->ExceptionCheck()) {
                    env->ExceptionClear();
                }
                if (tf) {
                    env->CallObjectMethod(paint, setTypeface, tf);
                    env->DeleteLocalRef(tf);
                }
            }
        }

        jstring jtext = env->NewStringUTF(p.title.c_str());
        if (!jtext) break;

        float boundsLf = NAN;
        float boundsRf = NAN;
        bool hasBoundsF = false;
        if (pathCls && rectFCls && rectFCtor) {
            jmethodID pathCtor = env->GetMethodID(pathCls, "<init>", "()V");
            jmethodID getTextPathM = env->GetMethodID(paintCls, "getTextPath", "(Ljava/lang/String;IIFFLandroid/graphics/Path;)V");
            jmethodID computeBoundsM = env->GetMethodID(pathCls, "computeBounds", "(Landroid/graphics/RectF;Z)V");
            jfieldID leftF = env->GetFieldID(rectFCls, "left", "F");
            jfieldID topF = env->GetFieldID(rectFCls, "top", "F");
            jfieldID rightF = env->GetFieldID(rectFCls, "right", "F");
            jfieldID botF = env->GetFieldID(rectFCls, "bottom", "F");
            if (pathCtor && getTextPathM && computeBoundsM && leftF && topF && rightF && botF) {
                jobject path = env->NewObject(pathCls, pathCtor);
                if (path) {
                    const jint end = static_cast<jint>(p.title.size());
                    env->CallVoidMethod(paint, getTextPathM, jtext, 0, end, 0.0f, 0.0f, path);
                    if (env->ExceptionCheck()) {
                        env->ExceptionClear();
                    } else {
                        jobject rf = env->NewObject(rectFCls, rectFCtor, 0.0f, 0.0f, 0.0f, 0.0f);
                        if (rf) {
                            env->CallVoidMethod(path, computeBoundsM, rf, JNI_TRUE);
                            if (env->ExceptionCheck()) {
                                env->ExceptionClear();
                            } else {
                                const float l = env->GetFloatField(rf, leftF);
                                const float t = env->GetFloatField(rf, topF);
                                const float r = env->GetFloatField(rf, rightF);
                                const float b = env->GetFloatField(rf, botF);
                                if (std::isfinite(l) && std::isfinite(r) && std::isfinite(t) && std::isfinite(b) && r > l && b > t) {
                                    boundsLf = l;
                                    boundsRf = r;
                                    hasBoundsF = true;
                                }
                            }
                            env->DeleteLocalRef(rf);
                        }
                    }
                    env->DeleteLocalRef(path);
                }
            }
        }

        float textWf = env->CallFloatMethod(paint, measureText, jtext);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            env->DeleteLocalRef(jtext);
            break;
        }

        if (!std::isfinite(textWf)) textWf = 1.0f;
        if (textWf < 1.0f) textWf = 1.0f;

        float contentWf = textWf;
        if (hasBoundsF && std::isfinite(boundsLf) && std::isfinite(boundsRf)) {
            const float inkW = boundsRf - boundsLf;
            if (std::isfinite(inkW) && inkW > 1.0f) {
                contentWf = std::max(contentWf, inkW);
            }
        }
        if (!std::isfinite(contentWf) || contentWf < 1.0f) contentWf = 1.0f;

        int textW = static_cast<int>(std::ceil(contentWf));
        if (textW < 1) textW = 1;

        jobject fm = env->CallObjectMethod(paint, getFontMetrics);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            env->DeleteLocalRef(jtext);
            break;
        }
        if (!fm) {
            env->DeleteLocalRef(jtext);
            break;
        }
        jclass fmCls = env->GetObjectClass(fm);
        if (!fmCls) {
            env->DeleteLocalRef(fm);
            env->DeleteLocalRef(jtext);
            break;
        }
        jfieldID ascentF = env->GetFieldID(fmCls, "ascent", "F");
        jfieldID descentF = env->GetFieldID(fmCls, "descent", "F");
        jfieldID topF = env->GetFieldID(fmCls, "top", "F");
        jfieldID bottomF = env->GetFieldID(fmCls, "bottom", "F");
        if (!ascentF || !descentF) {
            env->DeleteLocalRef(fmCls);
            env->DeleteLocalRef(fm);
            env->DeleteLocalRef(jtext);
            break;
        }
        const float ascent = env->GetFloatField(fm, ascentF);
        const float descent = env->GetFloatField(fm, descentF);
        float top = (topF) ? env->GetFloatField(fm, topF) : ascent;
        float bottom = (bottomF) ? env->GetFloatField(fm, bottomF) : descent;
        env->DeleteLocalRef(fmCls);
        env->DeleteLocalRef(fm);

        float topMost = std::min(top, ascent);
        float bottomMost = std::max(bottom, descent);
        if (!std::isfinite(topMost)) topMost = std::isfinite(top) ? top : ascent;
        if (!std::isfinite(bottomMost)) bottomMost = std::isfinite(bottom) ? bottom : descent;

        int32_t boundsL = 0;
        int32_t boundsT = 0;
        int32_t boundsR = 0;
        int32_t boundsB = 0;
        bool hasBounds = false;
        if (rectCls && getTextBounds) {
            jmethodID rectCtor = env->GetMethodID(rectCls, "<init>", "()V");
            if (rectCtor) {
                jobject bounds = env->NewObject(rectCls, rectCtor);
                if (bounds) {
                    const jint end = static_cast<jint>(p.title.size());
                    env->CallVoidMethod(paint, getTextBounds, jtext, 0, end, bounds);
                    if (env->ExceptionCheck()) {
                        env->ExceptionClear();
                    } else {
                        jfieldID leftF = env->GetFieldID(rectCls, "left", "I");
                        jfieldID topbF = env->GetFieldID(rectCls, "top", "I");
                        jfieldID rightF = env->GetFieldID(rectCls, "right", "I");
                        jfieldID botF = env->GetFieldID(rectCls, "bottom", "I");
                        if (leftF && topbF && rightF && botF) {
                            boundsL = env->GetIntField(bounds, leftF);
                            boundsT = env->GetIntField(bounds, topbF);
                            boundsR = env->GetIntField(bounds, rightF);
                            boundsB = env->GetIntField(bounds, botF);
                            if (boundsR > boundsL && boundsB > boundsT) {
                                hasBounds = true;
                            }
                        }
                    }
                    env->DeleteLocalRef(bounds);
                }
            }
        }

        float metricsHf = (bottomMost - topMost);
        if (!std::isfinite(metricsHf) || metricsHf < 1.0f) metricsHf = 1.0f;
        if (!std::isfinite(metricsHf) || metricsHf < 1.0f) metricsHf = 1.0f;
        float lineHf = fontPx;
        if (!std::isfinite(lineHf) || lineHf < 1.0f) lineHf = metricsHf;
        float textHf = std::max(metricsHf, lineHf);
        if (!std::isfinite(textHf) || textHf < 1.0f) textHf = 1.0f;
        int textH = static_cast<int>(std::ceil(textHf));
        if (textH < 1) textH = 1;

        float textWdraw = contentWf;
        if (!std::isfinite(textWdraw) || textWdraw < 1.0f) textWdraw = static_cast<float>(textW);
        float textHdraw = textHf;
        if (!std::isfinite(textHdraw) || textHdraw < 1.0f) textHdraw = static_cast<float>(textH);

        const float gAlpha = 1.0f;
        auto mulAlpha = [&](int64_t argb, float a) -> int32_t {
            uint32_t c = static_cast<uint32_t>(argb);
            uint32_t ca = (c >> 24) & 0xFF;
            float fa = (static_cast<float>(ca) / 255.0f) * a;
            if (fa < 0.0f) fa = 0.0f;
            if (fa > 1.0f) fa = 1.0f;
            uint32_t na = static_cast<uint32_t>(std::round(fa * 255.0f)) & 0xFF;
            return static_cast<int32_t>((c & 0x00FFFFFFu) | (na << 24));
        };

        float bleed = 0.0f;
        bleed = std::max(bleed, std::max(0.0f, p.glowRadius) * 2.0f);
        bleed = std::max(bleed, std::max(0.0f, p.shadowBlur) * 2.0f + (std::fabs(p.shadowX) + std::fabs(p.shadowY)));
        bleed = std::max(bleed, std::max(0.0f, p.borderW));
        if (p.box) {
            bleed = std::max(bleed, std::max(0.0f, p.boxBorderW) * 0.5f);
        }
        if (!std::isfinite(bleed)) bleed = 0.0f;
        if (bleed < 0.0f) bleed = 0.0f;
        if (bleed > 80.0f) bleed = 80.0f;
        int pad = 0;
        if (p.padPx >= 0.0f && std::isfinite(p.padPx)) {
            float pp = p.padPx;
            if (pp < 0.0f) pp = 0.0f;
            if (pp > 200.0f) pp = 200.0f;
            pad = static_cast<int>(std::round(pp));
        } else {
            pad = static_cast<int>(std::ceil(bleed)) + 6;
        }
        int boxPad = 0;
        if (p.box) {
            float bp = p.boxPad;
            if (!std::isfinite(bp)) bp = 0.0f;
            if (bp < 0.0f) bp = 0.0f;
            if (bp > 1024.0f) bp = 1024.0f;
            boxPad = static_cast<int>(std::ceil(bp));
        }
        const int w = textW + pad * 2 + boxPad * 2;
        const int h = textH + pad * 2 + boxPad * 2;
        if (w <= 0 || h <= 0 || w > 4096 || h > 4096) {
            env->DeleteLocalRef(jtext);
            break;
        }

        jmethodID createBitmap = env->GetStaticMethodID(bitmapCls, "createBitmap", "(IILandroid/graphics/Bitmap$Config;)Landroid/graphics/Bitmap;");
        jfieldID argbField = env->GetStaticFieldID(bitmapCfgCls, "ARGB_8888", "Landroid/graphics/Bitmap$Config;");
        if (!createBitmap || !argbField) {
            env->DeleteLocalRef(jtext);
            break;
        }
        jobject cfg = env->GetStaticObjectField(bitmapCfgCls, argbField);
        jobject bmp = env->CallStaticObjectMethod(bitmapCls, createBitmap, w, h, cfg);
        env->DeleteLocalRef(cfg);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
        }
        if (!bmp) {
            env->DeleteLocalRef(jtext);
            break;
        }
        jmethodID eraseColor = env->GetMethodID(bitmapCls, "eraseColor", "(I)V");
        if (eraseColor) {
            env->CallVoidMethod(bmp, eraseColor, 0);
        }

        jmethodID canvasCtor = env->GetMethodID(canvasCls, "<init>", "(Landroid/graphics/Bitmap;)V");
        jmethodID drawText = env->GetMethodID(canvasCls, "drawText", "(Ljava/lang/String;FFLandroid/graphics/Paint;)V");
        jmethodID drawRoundRect = env->GetMethodID(canvasCls, "drawRoundRect", "(Landroid/graphics/RectF;FFLandroid/graphics/Paint;)V");
        jmethodID saveLayer = env->GetMethodID(canvasCls, "saveLayer", "(Landroid/graphics/RectF;Landroid/graphics/Paint;)I");
        jmethodID restoreToCount = env->GetMethodID(canvasCls, "restoreToCount", "(I)V");
        if (!canvasCtor || !drawText) {
            env->DeleteLocalRef(bmp);
            env->DeleteLocalRef(jtext);
            break;
        }
        jobject canvas = env->NewObject(canvasCls, canvasCtor, bmp);
        if (!canvas) {
            env->DeleteLocalRef(bmp);
            env->DeleteLocalRef(jtext);
            break;
        }

        jobject fillStyle = nullptr;
        jobject strokeStyle = nullptr;
        if (styleCls) {
            jfieldID fillF = env->GetStaticFieldID(styleCls, "FILL", "Landroid/graphics/Paint$Style;");
            jfieldID strokeF = env->GetStaticFieldID(styleCls, "STROKE", "Landroid/graphics/Paint$Style;");
            if (fillF) fillStyle = env->GetStaticObjectField(styleCls, fillF);
            if (strokeF) strokeStyle = env->GetStaticObjectField(styleCls, strokeF);
        }

        float leftFix = 0.0f;
        if (hasBoundsF && boundsLf < 0.0f) {
            leftFix = -boundsLf;
        } else if (hasBounds && boundsL < 0) {
            leftFix = static_cast<float>(-boundsL);
        }
        const float maxFix = static_cast<float>(pad);
        if (!std::isfinite(leftFix) || leftFix < 0.0f) leftFix = 0.0f;
        if (leftFix > maxFix) leftFix = maxFix;

        float bearingFix = 0.0f;
        if (pad <= 8 && boxPad == 0 && hasBoundsF && hasBounds) {
            float dl = boundsLf - static_cast<float>(boundsL);
            if (std::isfinite(dl) && dl > 0.0f) {
                const bool hasExplicitPadPx = (p.padPx >= 0.0f && std::isfinite(p.padPx));

                std::string fontLower;
                fontLower.reserve(p.font.size());
                for (const char c : p.font) {
                    fontLower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
                }
                const bool isItalicFont = (fontLower.find("italic") != std::string::npos);
                const bool isPacificoFont = (fontLower.find("pacifico") != std::string::npos);
                const int titleLen = static_cast<int>(p.title.size());

                if (dl > 6.0f && std::isfinite(boundsLf) && boundsLf > 0.0f) {
                    const float frac = boundsLf - std::floor(boundsLf);
                    if (std::isfinite(frac) && frac >= 0.0f && frac <= 1.0f) {
                        dl = frac;
                    }
                }

                float fudgeBase = hasExplicitPadPx ? 3.5f : 5.5f;
                if (!hasExplicitPadPx && pad >= 6) {
                    fudgeBase = 3.5f;
                }
                if (hasExplicitPadPx) {
                    if (titleLen >= 6) {
                        fudgeBase += 3.0f;
                    }
                    if (isItalicFont) {
                        fudgeBase += 2.0f;
                    }
                    if (isPacificoFont) {
                        fudgeBase -= 2.0f;
                    }
                }
                if (!std::isfinite(fudgeBase) || fudgeBase < 0.0f) fudgeBase = 0.0f;
                float fudge = fudgeBase;
                float kFont = 0.0f;
                if (std::isfinite(fontPx)) {
                    const float t = (fontPx - 1200.0f) / 600.0f;
                    kFont = std::min(1.0f, std::max(0.0f, t));
                    fudge = fudgeBase - 1.0f * kFont;
                }
                if (!std::isfinite(fudge) || fudge < 0.0f) fudge = 0.0f;
                if (kFont > 0.0f) {
                    float dlClamped = dl;
                    if (!std::isfinite(dlClamped) || dlClamped < 0.0f) dlClamped = 0.0f;
                    if (dlClamped > 10.0f) dlClamped = 10.0f;
                    float dlFactor = 1.0f - (0.12f * dlClamped * kFont);
                    if (!std::isfinite(dlFactor)) dlFactor = 1.0f;
                    if (dlFactor < 0.35f) dlFactor = 0.35f;
                    if (dlFactor > 1.0f) dlFactor = 1.0f;
                    fudge *= dlFactor;
                }
                float desired = dl + fudge;
                if (!std::isfinite(desired) || desired < 0.0f) desired = 0.0f;

                float desiredCap = (pad >= 6) ? 6.0f : 9.0f;
                if (pad >= 6) {
                    if (isPacificoFont) {
                        desiredCap = 5.0f;
                    } else if (titleLen >= 6) {
                        desiredCap = 9.0f;
                    } else if (isItalicFont) {
                        desiredCap = 8.0f;
                    } else if (titleLen == 1) {
                        desiredCap = 5.5f;
                    }
                }
                if (desired > desiredCap) desired = desiredCap;

                float maxNoClip = 0.0f;
                if (std::isfinite(boundsRf) && boundsRf > 0.0f) {
                    maxNoClip = static_cast<float>(w) - (static_cast<float>(pad + boxPad) + leftFix + boundsRf);
                } else {
                    maxNoClip = static_cast<float>(w) - (static_cast<float>(pad + boxPad) + leftFix + textWdraw);
                }
                if (!std::isfinite(maxNoClip) || maxNoClip < 0.0f) maxNoClip = 0.0f;

                bearingFix = std::min(desired, maxNoClip);
            }
        }
        const float baseX = static_cast<float>(pad + boxPad) + leftFix + bearingFix;
        float baseY = 0.0f;
        if (p.box) {
            // For box backgrounds, align glyph ink top to (pad + boxPad) so padding is symmetric.
            // Otherwise, the baseline centering logic can shift ink above the box top (negative top padding).
            float by = static_cast<float>(pad + boxPad) - topMost;
            if (!std::isfinite(by) || by < 0.0f) by = static_cast<float>(pad + boxPad);
            baseY = by;
        } else {
            float t = -ascent;
            const float rawH = (descent - ascent);
            const float slack = fontPx - rawH;
            if (std::isfinite(slack)) {
                t += slack * 0.5f;
            }
            if (!std::isfinite(t) || t < 0.0f) t = 0.0f;
            baseY = static_cast<float>(pad + boxPad) + t;
        }

        // Report ink-center delta (ink center minus bitmap center) for precise placement.
        // This accounts for font bearing/baseline and any internal padding we add.
        if (outInkCenterDxPx || outInkCenterDyPx) {
            float inkL = baseX;
            float inkT = baseY + topMost;
            float inkW = textWdraw;
            float inkH = (bottomMost - topMost);
            if (hasBoundsF && std::isfinite(boundsLf) && std::isfinite(boundsRf) && (boundsRf > boundsLf)) {
                inkL = baseX + boundsLf;
                inkW = (boundsRf - boundsLf);
            } else if (hasBounds && (boundsR > boundsL)) {
                inkL = baseX + static_cast<float>(boundsL);
                inkW = static_cast<float>(boundsR - boundsL);
            }
            if (!std::isfinite(inkW) || inkW <= 0.0f) inkW = textWdraw;
            if (!std::isfinite(inkH) || inkH <= 0.0f) inkH = (bottomMost - topMost);
            if (!std::isfinite(inkL)) inkL = baseX;
            if (!std::isfinite(inkT)) inkT = baseY;

            const float inkCx = inkL + 0.5f * inkW;
            const float inkCy = inkT + 0.5f * inkH;
            const float bmpCx = 0.5f * static_cast<float>(w);
            const float bmpCy = 0.5f * static_cast<float>(h);
            float dx = inkCx - bmpCx;
            float dy = inkCy - bmpCy;
            if (!std::isfinite(dx)) dx = 0.0f;
            if (!std::isfinite(dy)) dy = 0.0f;
            if (outInkCenterDxPx) *outInkCenterDxPx = dx;
            if (outInkCenterDyPx) *outInkCenterDyPx = dy;
        }

        if (s_textParityCount < 20) {
            LOGI(
                "TEXT_PARITY raster maskOnly=%d decorOnly=%d fontPx=%.3f titleLen=%d textWf=%.3f textW=%d metrics(top=%.3f asc=%.3f des=%.3f bot=%.3f) metricsHf=%.3f lineHf=%.3f textHf=%.3f textH=%d padPx=%.3f pad=%d boxPad=%d w=%d h=%d baseX=%.3f baseY=%.3f hasBounds=%d boundsL=%d hasBoundsF=%d boundsLf=%.3f leftFix=%.3f bearingFix=%.3f box=%d boxBorderW=%.3f boxRadius=%.3f borderW=%.3f glowRadius=%.3f shadow(x=%.3f y=%.3f blur=%.3f)",
                maskOnly ? 1 : 0,
                decorOnly ? 1 : 0,
                fontPx,
                static_cast<int>(p.title.size()),
                textWf,
                textW,
                top,
                ascent,
                descent,
                bottom,
                metricsHf,
                lineHf,
                textHf,
                textH,
                (p.padPx >= 0.0f && std::isfinite(p.padPx)) ? p.padPx : -1.0f,
                pad,
                boxPad,
                w,
                h,
                baseX,
                baseY,
                hasBounds ? 1 : 0,
                boundsL,
                hasBoundsF ? 1 : 0,
                std::isfinite(boundsLf) ? boundsLf : 0.0f,
                leftFix,
                bearingFix,
                p.box ? 1 : 0,
                p.boxBorderW,
                p.boxRadius,
                p.borderW,
                p.glowRadius,
                p.shadowX,
                p.shadowY,
                p.shadowBlur
            );
            if (p.box) {
                const float leftX = static_cast<float>(pad);
                const float topY = static_cast<float>(pad);
                const float rightX = static_cast<float>(pad + boxPad * 2) + textWdraw;
                const float bottomY = static_cast<float>(pad + boxPad * 2) + textHdraw;
                LOGI(
                    "TEXT_PARITY raster_box rect(l=%.3f t=%.3f r=%.3f b=%.3f) contentWHf=%.3fx%.3f contentWH=%dx%d boxPad=%d",
                    leftX,
                    topY,
                    rightX,
                    bottomY,
                    textWdraw,
                    textHdraw,
                    textW,
                    textH,
                    boxPad
                );

                const float inkL = baseX + (hasBoundsF ? boundsLf : static_cast<float>(boundsL));
                const float inkT = baseY + topMost;
                const float inkR = inkL + textWdraw;
                const float inkB = baseY + bottomMost;
                const float padL = inkL - leftX;
                const float padT = inkT - topY;
                const float padR = rightX - inkR;
                const float padB = bottomY - inkB;
                LOGI(
                    "BOX_PARITY raster_eff padLTRB=%.3f,%.3f,%.3f,%.3f inkLTRB=%.3f,%.3f,%.3f,%.3f boxLTRB=%.3f,%.3f,%.3f,%.3f",
                    padL,
                    padT,
                    padR,
                    padB,
                    inkL,
                    inkT,
                    inkR,
                    inkB,
                    leftX,
                    topY,
                    rightX,
                    bottomY
                );
            }
            s_textParityCount++;
        }

        jobject blurFilter = nullptr;
        if (p.animType == "blur_in" && blurMaskFilterCls && blurStyleCls && setMaskFilter) {
            float spd = p.animSpeed;
            if (!std::isfinite(spd)) spd = 1.0f;
            if (spd < 0.2f) spd = 0.2f;
            if (spd > 2.0f) spd = 2.0f;

            float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
            if (!std::isfinite(prog)) prog = 0.0f;
            if (prog < 0.0f) prog = 0.0f;
            if (prog > 1.0f) prog = 1.0f;

            const int step = static_cast<int>(std::round(prog * 30.0f));
            const float q = static_cast<float>(std::max(0, std::min(30, step))) / 30.0f;
            float blurR = (1.0f - q) * 12.0f;
            if (!std::isfinite(blurR)) blurR = 0.0f;
            if (blurR < 0.0f) blurR = 0.0f;
            if (blurR > 32.0f) blurR = 32.0f;

            jfieldID normF = env->GetStaticFieldID(blurStyleCls, "NORMAL", "Landroid/graphics/BlurMaskFilter$Blur;");
            jobject norm = normF ? env->GetStaticObjectField(blurStyleCls, normF) : nullptr;
            jmethodID blurCtor = (norm) ? env->GetMethodID(blurMaskFilterCls, "<init>", "(FLandroid/graphics/BlurMaskFilter$Blur;)V") : nullptr;
            if (blurCtor && norm) {
                blurFilter = env->NewObject(blurMaskFilterCls, blurCtor, blurR, norm);
                if (env->ExceptionCheck()) {
                    env->ExceptionClear();
                    blurFilter = nullptr;
                }
            }
            if (norm) env->DeleteLocalRef(norm);
        }

        // Box background
        if (!maskOnly && p.box && drawRoundRect && rectFCtor && fillStyle) {
            const float leftX = static_cast<float>(pad);
            const float topY = static_cast<float>(pad);
            const float rightX = static_cast<float>(pad + boxPad * 2) + textWdraw;
            const float bottomY = static_cast<float>(pad + boxPad * 2) + textHdraw;
            jobject rf = env->NewObject(rectFCls, rectFCtor, leftX, topY, rightX, bottomY);
            const float rectW = std::max(0.0f, rightX - leftX);
            const float rectH = std::max(0.0f, bottomY - topY);
            const float maxRad = 0.5f * std::min(rectW, rectH);
            const float rad = std::max(0.0f, std::min(maxRad, p.boxRadius));

            env->CallVoidMethod(paint, setStyle, fillStyle);
            env->CallVoidMethod(paint, setColor, static_cast<jint>(mulAlpha(p.boxColor, gAlpha)));
            env->CallVoidMethod(canvas, drawRoundRect, rf, rad, rad, paint);

            if (p.boxBorderW > 0.0f && strokeStyle) {
                env->CallVoidMethod(paint, setStyle, strokeStyle);
                env->CallVoidMethod(paint, setStrokeWidth, std::max(0.0f, p.boxBorderW));
                env->CallVoidMethod(paint, setColor, static_cast<jint>(mulAlpha(p.borderColor, gAlpha)));
                env->CallVoidMethod(canvas, drawRoundRect, rf, rad, rad, paint);
            }

            env->DeleteLocalRef(rf);
        }

        const bool isInnerGlow = (!maskOnly) && (p.effectType == "inner_glow");
        const bool isInnerShadow = (!maskOnly) && (p.effectType == "inner_shadow");
        const bool useInner = isInnerGlow || isInnerShadow;

        auto drawFillOnly = [&]() {
            if (decorOnly) return;
            if (fillStyle) env->CallVoidMethod(paint, setStyle, fillStyle);
            if (clearShadowLayer) env->CallVoidMethod(paint, clearShadowLayer);
            if (setMaskFilter) env->CallObjectMethod(paint, setMaskFilter, blurFilter);
            const int32_t col = maskOnly ? static_cast<int32_t>(0xFFFFFFFFu) : mulAlpha(p.fontColor, gAlpha);
            env->CallVoidMethod(paint, setColor, static_cast<jint>(col));
            env->CallVoidMethod(canvas, drawText, jtext, baseX, baseY, paint);
        };

        auto drawOuterGlow = [&]() {
            if (maskOnly) return;
            if (p.glowRadius <= 0.0f) return;
            if (fillStyle) env->CallVoidMethod(paint, setStyle, fillStyle);
            env->CallVoidMethod(paint, setColor, static_cast<jint>(mulAlpha(p.glowColor, gAlpha)));
            env->CallVoidMethod(paint, setShadowLayer, std::max(0.0f, p.glowRadius), 0.0f, 0.0f, static_cast<jint>(mulAlpha(p.glowColor, gAlpha)));
            env->CallVoidMethod(canvas, drawText, jtext, baseX, baseY, paint);
            if (clearShadowLayer) env->CallVoidMethod(paint, clearShadowLayer);
        };

        auto drawShadow = [&]() {
            if (maskOnly) return;
            if (p.shadowBlur <= 0.0f && p.shadowX == 0.0f && p.shadowY == 0.0f) return;
            if (fillStyle) env->CallVoidMethod(paint, setStyle, fillStyle);
            env->CallVoidMethod(paint, setColor, static_cast<jint>(mulAlpha(p.shadowColor, gAlpha)));
            const float blur = std::max(0.0f, p.shadowBlur);
            if (blur > 0.0f) {
                env->CallVoidMethod(paint, setShadowLayer, blur, p.shadowX, p.shadowY, static_cast<jint>(mulAlpha(p.shadowColor, gAlpha)));
                env->CallVoidMethod(canvas, drawText, jtext, baseX, baseY, paint);
                if (clearShadowLayer) env->CallVoidMethod(paint, clearShadowLayer);
            } else {
                if (clearShadowLayer) env->CallVoidMethod(paint, clearShadowLayer);
                env->CallVoidMethod(canvas, drawText, jtext, baseX + p.shadowX, baseY + p.shadowY, paint);
            }
        };

        auto drawOutline = [&]() {
            if (maskOnly) return;
            if (p.borderW <= 0.0f) return;
            if (!strokeStyle) return;
            env->CallVoidMethod(paint, setStyle, strokeStyle);
            env->CallVoidMethod(paint, setStrokeWidth, std::max(0.0f, p.borderW));
            env->CallVoidMethod(paint, setColor, static_cast<jint>(mulAlpha(p.borderColor, gAlpha)));
            env->CallVoidMethod(canvas, drawText, jtext, baseX, baseY, paint);
        };

        if (useInner && saveLayer && restoreToCount && rectFCtor && setXfermode && porterDuffModeCls && porterDuffXferCls) {
            jobject layerRect = env->NewObject(rectFCls, rectFCtor, 0.0f, 0.0f, static_cast<float>(w), static_cast<float>(h));
            const jint sc = env->CallIntMethod(canvas, saveLayer, layerRect, nullptr);
            // Destination: blurred glow/shadow
            if (isInnerGlow) {
                if (fillStyle) env->CallVoidMethod(paint, setStyle, fillStyle);
                env->CallVoidMethod(paint, setColor, static_cast<jint>(mulAlpha(p.glowColor, gAlpha)));
                env->CallVoidMethod(paint, setShadowLayer, std::max(0.0f, p.glowRadius), 0.0f, 0.0f, static_cast<jint>(mulAlpha(p.glowColor, gAlpha)));
                env->CallVoidMethod(canvas, drawText, jtext, baseX, baseY, paint);
            } else {
                if (fillStyle) env->CallVoidMethod(paint, setStyle, fillStyle);
                env->CallVoidMethod(paint, setColor, static_cast<jint>(mulAlpha(p.shadowColor, gAlpha)));
                const float blur = std::max(0.0f, p.shadowBlur);
                if (blur > 0.0f) {
                    env->CallVoidMethod(paint, setShadowLayer, blur, p.shadowX, p.shadowY, static_cast<jint>(mulAlpha(p.shadowColor, gAlpha)));
                    env->CallVoidMethod(canvas, drawText, jtext, baseX, baseY, paint);
                } else {
                    if (clearShadowLayer) env->CallVoidMethod(paint, clearShadowLayer);
                    env->CallVoidMethod(canvas, drawText, jtext, baseX + p.shadowX, baseY + p.shadowY, paint);
                }
            }
            if (clearShadowLayer) env->CallVoidMethod(paint, clearShadowLayer);

            // Mask with glyphs (DST_IN)
            jfieldID dstInF = env->GetStaticFieldID(porterDuffModeCls, "DST_IN", "Landroid/graphics/PorterDuff$Mode;");
            jobject dstIn = dstInF ? env->GetStaticObjectField(porterDuffModeCls, dstInF) : nullptr;
            jmethodID xferCtor = dstIn ? env->GetMethodID(porterDuffXferCls, "<init>", "(Landroid/graphics/PorterDuff$Mode;)V") : nullptr;
            jobject xfer = (dstIn && xferCtor) ? env->NewObject(porterDuffXferCls, xferCtor, dstIn) : nullptr;
            if (xfer) {
                env->CallObjectMethod(paint, setXfermode, xfer);
                if (fillStyle) env->CallVoidMethod(paint, setStyle, fillStyle);
                env->CallVoidMethod(paint, setColor, static_cast<jint>(0xFFFFFFFF));
                env->CallVoidMethod(canvas, drawText, jtext, baseX, baseY, paint);
                env->CallObjectMethod(paint, setXfermode, nullptr);
                env->DeleteLocalRef(xfer);
            }
            if (dstIn) env->DeleteLocalRef(dstIn);
            env->CallVoidMethod(canvas, restoreToCount, sc);
            env->DeleteLocalRef(layerRect);
        } else {
            // Normal render order
            drawOuterGlow();
            drawShadow();
            drawOutline();
            drawFillOnly();
        }

        if (setMaskFilter) {
            env->CallObjectMethod(paint, setMaskFilter, nullptr);
        }
        if (blurFilter) {
            env->DeleteLocalRef(blurFilter);
            blurFilter = nullptr;
        }

        if (fillStyle) env->DeleteLocalRef(fillStyle);
        if (strokeStyle) env->DeleteLocalRef(strokeStyle);

        AndroidBitmapInfo info;
        if (AndroidBitmap_getInfo(env, bmp, &info) != ANDROID_BITMAP_RESULT_SUCCESS) {
            env->DeleteLocalRef(canvas);
            env->DeleteLocalRef(bmp);
            env->DeleteLocalRef(jtext);
            break;
        }
        void* pixels = nullptr;
        if (AndroidBitmap_lockPixels(env, bmp, &pixels) != ANDROID_BITMAP_RESULT_SUCCESS || !pixels) {
            env->DeleteLocalRef(canvas);
            env->DeleteLocalRef(bmp);
            env->DeleteLocalRef(jtext);
            break;
        }

        outW = static_cast<int32_t>(info.width);
        outH = static_cast<int32_t>(info.height);
        const size_t stride = static_cast<size_t>(info.stride);
        outRgba.resize(static_cast<size_t>(outW) * static_cast<size_t>(outH) * 4u);
        const uint8_t* src = static_cast<const uint8_t*>(pixels);
        for (int32_t y = 0; y < outH; y++) {
            memcpy(outRgba.data() + static_cast<size_t>(y) * static_cast<size_t>(outW) * 4u, src + static_cast<size_t>(y) * stride, static_cast<size_t>(outW) * 4u);
        }
        AndroidBitmap_unlockPixels(env, bmp);

        env->DeleteLocalRef(canvas);
        env->DeleteLocalRef(bmp);
        env->DeleteLocalRef(jtext);
        env->DeleteLocalRef(paint);

        if (styleCls) env->DeleteLocalRef(styleCls);
        if (blurStyleCls) env->DeleteLocalRef(blurStyleCls);
        if (blurMaskFilterCls) env->DeleteLocalRef(blurMaskFilterCls);
        if (porterDuffXferCls) env->DeleteLocalRef(porterDuffXferCls);
        if (porterDuffModeCls) env->DeleteLocalRef(porterDuffModeCls);
        if (porterDuffCls) env->DeleteLocalRef(porterDuffCls);
        if (typefaceCls) env->DeleteLocalRef(typefaceCls);
        if (bitmapCfgCls) env->DeleteLocalRef(bitmapCfgCls);
        if (bitmapCls) env->DeleteLocalRef(bitmapCls);
        if (canvasCls) env->DeleteLocalRef(canvasCls);
        if (rectFCls) env->DeleteLocalRef(rectFCls);
        if (rectCls) env->DeleteLocalRef(rectCls);
        if (textPaintCls) env->DeleteLocalRef(textPaintCls);
        if (pathCls) env->DeleteLocalRef(pathCls);
        if (paintCls) env->DeleteLocalRef(paintCls);
        ok = (!outRgba.empty() && outW > 0 && outH > 0);
    } while (false);

    env->PopLocalFrame(nullptr);

    if (didAttach) {
        g_vidvizJvm->DetachCurrentThread();
    }
    return ok;
}

void shutdownTextRasterizer() {
    if (!g_assetManager) return;
    if (!g_vidvizJvm) {
        g_vidvizJvm = getJavaVmFallback();
    }
    if (!g_vidvizJvm) return;

    JNIEnv* env = nullptr;
    bool didAttach = false;
    const jint envRes = g_vidvizJvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (envRes == JNI_EDETACHED) {
        if (g_vidvizJvm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
            return;
        }
        didAttach = true;
    } else if (envRes != JNI_OK || !env) {
        return;
    }

    env->DeleteGlobalRef(g_assetManager);
    g_assetManager = nullptr;

    if (didAttach) {
        g_vidvizJvm->DetachCurrentThread();
    }
}

} // namespace gles
} // namespace android
} // namespace vidviz
