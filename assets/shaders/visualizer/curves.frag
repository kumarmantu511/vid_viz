#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;

uniform float uGlow;    // Parlama şiddeti
uniform float uStroke;  // Çizgi kalınlığı
uniform sampler2D iChannel0;

out vec4 fragColor;

vec3 iResolution;
float iTime;

// --- FREKANS OKUMA FONKSİYONLARI ---
float _vidvizSample8(float x) {
    x = clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float f0 = (i0 < 0.5) ? uFreq0 : (i0 < 1.5) ? uFreq1 : (i0 < 2.5) ? uFreq2 : (i0 < 3.5) ? uFreq3 :
    (i0 < 4.5) ? uFreq4 : (i0 < 5.5) ? uFreq5 : (i0 < 6.5) ? uFreq6 : uFreq7;
    float f1 = (i1 < 0.5) ? uFreq0 : (i1 < 1.5) ? uFreq1 : (i1 < 2.5) ? uFreq2 : (i1 < 3.5) ? uFreq3 :
    (i1 < 4.5) ? uFreq4 : (i1 < 5.5) ? uFreq5 : (i1 < 6.5) ? uFreq6 : uFreq7;
    return mix(f0, f1, t);
}

// Özel texture fonksiyonu
vec4 _vidvizTexture(sampler2D s, vec2 uv) {
    float v = _vidvizSample8(uv.x);
    return vec4(v, v, v, 1.0);
}

// HATA KAYNAĞI OLAN "#define texture" SİLİNDİ.

// --- YAPILANDIRMA VE SABİTLER ---
#define FILL_ENABLED true
#define FILL_OPACITY 0.5
#define SCALE 0.2
#define SHIFT 0.08
#define WIDTH 0.04
#define AMP 1.0

// Orijinal renkler
#define COLOR1 vec3(203.0, 36.0, 128.0) / 255.0
#define COLOR2 vec3(41.0, 200.0, 192.0) / 255.0
#define COLOR3 vec3(24.0, 137.0, 218.0) / 255.0

const int shuffle[5] = int[5](1, 3, 0, 4, 2);

// --- YARDIMCI FONKSİYONLAR ---
float getFreq(int channel, int i) {
    int band = 2 * channel + shuffle[i] * 6;
    float normalizedBand = float(band) / 32.0;
    // BURASI DÜZELTİLDİ: texture -> _vidvizTexture
    return _vidvizTexture(iChannel0, vec2(normalizedBand, 0.0)).x;
}

float getScale(int i) {
    float x = abs(2.0 - float(i));
    float s = 3.0 - x;
    return s / 3.0 * AMP;
}

float smoothCubic(float t) {
    return t * t * (3.0 - 2.0 * t);
}

float getInversionFactor(int index) {
    if (index == 0 || index == 4) return -1.0;
    else return 1.0;
}

float sampleCurveY(float t, float y[5], bool upper) {
    t = clamp(t, 0.0, 1.0);
    float extendedT = t * 1.4 - 0.2;

    if (extendedT <= 0.0) {
        float blend = smoothCubic((extendedT + 0.2) / 0.2);
        float displacement = (y[0] - 0.5) * getInversionFactor(0);
        float result = 0.5 + displacement * blend;
        return upper ? result : (1.0 - result);
    } else if (extendedT >= 1.0) {
        float blend = smoothCubic(1.0 - (extendedT - 1.0) / 0.2);
        float displacement = (y[4] - 0.5) * getInversionFactor(4);
        float result = 0.5 + displacement * blend;
        return upper ? result : (1.0 - result);
    }

    float scaledT = extendedT * 4.0;
    int index = int(scaledT);
    float frac = fract(scaledT);
    frac = smoothCubic(frac);

    float y1, y2, inv1, inv2;
    if (index >= 4) {
        y1 = y2 = y[4];
        inv1 = inv2 = getInversionFactor(4);
    } else {
        y1 = y[index];
        y2 = y[min(index + 1, 4)];
        inv1 = getInversionFactor(index);
        inv2 = getInversionFactor(min(index + 1, 4));
    }

    float disp1 = (y1 - 0.5) * inv1;
    float disp2 = (y2 - 0.5) * inv2;
    float displacement = mix(disp1, disp2, frac);
    float result = 0.5 + displacement;

    if (!upper) result = 1.0 - result;
    return result;
}

float getFillIntensity(vec2 uv, int channel) {
    float m = 0.5;
    float totalWidth = 15.0 * WIDTH;
    float offset = (1.0 - totalWidth) / 2.0;
    float channelShift = float(channel) * SHIFT;
    float startX = offset + channelShift;
    float endX = offset + channelShift + totalWidth;

    if (uv.x < startX || uv.x > endX) return 0.0;

    float y[5];
    for (int i = 0; i < 5; i++) {
        float freq = getFreq(channel, i);
        float scaleFactor = getScale(i);
        y[i] = max(0.0, m - scaleFactor * SCALE * freq);
    }

    float t = (uv.x - startX) / (endX - startX);
    float upperY = sampleCurveY(t, y, true);
    float lowerY = sampleCurveY(t, y, false);
    float minY = min(upperY, lowerY);
    float maxY = max(upperY, lowerY);

    if (uv.y >= minY && uv.y <= maxY) return 1.0;
    return 0.0;
}

float getOutlineDistance(vec2 uv, int channel) {
    float m = 0.5;
    float totalWidth = 15.0 * WIDTH;
    float offset = (1.0 - totalWidth) / 2.0;
    float channelShift = float(channel) * SHIFT;
    float startX = offset + channelShift;
    float endX = offset + channelShift + totalWidth;

    float y[5];
    for (int i = 0; i < 5; i++) {
        float freq = getFreq(channel, i);
        float scaleFactor = getScale(i);
        y[i] = max(0.0, m - scaleFactor * SCALE * freq);
    }

    float minDist = 1000.0;
    if (uv.x >= startX && uv.x <= endX) {
        float t = (uv.x - startX) / (endX - startX);
        float upperY = sampleCurveY(t, y, true);
        float lowerY = sampleCurveY(t, y, false);
        minDist = min(minDist, abs(uv.y - upperY));
        minDist = min(minDist, abs(uv.y - lowerY));
    } else {
        minDist = abs(uv.y - m);
    }
    return minDist;
}

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri ayarla
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // Flutter koordinatını al
    vec2 fragCoord = FlutterFragCoord().xy;

    vec2 uv = fragCoord / iResolution.xy;
    vec3 finalColor = vec3(0.0);

    // Çizgi kalınlığı
    vec2 pixelSize = 1.0 / iResolution.xy;
    float baseStroke = max(0.5, uStroke);
    float lineThickness = baseStroke * length(pixelSize);

    // 3 Kanalı çiz (Sırasıyla Pembe, Cyan, Mavi)
    for (int channel = 0; channel < 3; channel++) {
        vec3 channelColor;
        if (channel == 0) channelColor = COLOR1;
        else if (channel == 1) channelColor = COLOR2;
        else channelColor = COLOR3;

        // 1. Dolgu (Fill) İşlemi
        if (FILL_ENABLED) {
            float fillIntensity = getFillIntensity(uv, channel);
            if (fillIntensity > 0.0) {
                vec3 fillColor = channelColor * FILL_OPACITY * fillIntensity;
                finalColor += fillColor;
            }
        }

        // 2. Çizgi (Stroke) ve GLOW (Parlama)
        float dist = getOutlineDistance(uv, channel);

        // a) Net Çizgi
        float stroke = 1.0 - smoothstep(0.0, lineThickness, dist);

        // b) Glow Hesabı
        float glowInput = max(uGlow, 0.0);
        float glowEffect = exp(-dist * 20.0) * glowInput;

        // Yoğunluk
        float intensity = stroke + glowEffect;

        // Renk Karışımı
        vec3 layerColor = channelColor * intensity;
        finalColor = finalColor + layerColor - finalColor * layerColor;
    }

    // Genel renk tonu (Tint)
    vec3 tint = mix(uColor, uColor2, clamp(uv.y, 0.0, 1.0));
    finalColor *= tint;

    // Alpha hesabı
    float a = clamp(max(finalColor.r, max(finalColor.g, finalColor.b)), 0.0, 1.0);

    // Çıktı
    fragColor = vec4(finalColor, a);
}