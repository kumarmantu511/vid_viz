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

// --- FREKANS OKUMA ---
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

#define FILL_OPACITY 0.45
#define SCALE 0.35
#define AMP 1.0

const int shuffle[5] = int[5](1, 3, 0, 4, 2);

// --- YARDIMCI FONKSİYONLAR ---
float getFreq(int i) {
    int band = shuffle[i] * 6;
    // BURASI DÜZELTİLDİ: texture -> _vidvizTexture
    return _vidvizTexture(iChannel0, vec2(float(band) / 32.0, 0.0)).x;
}

float getScale(int i) {
    float x = abs(2.0 - float(i));
    return (3.0 - x) / 3.0 * AMP;
}

float smoothCubic(float t) {
    return t * t * (3.0 - 2.0 * t);
}

float sampleCurve(float t, float y[5]) {
    t = clamp(t, 0.0, 1.0);
    float st = t * 4.0;
    int i = int(st);
    float f = smoothCubic(fract(st));
    float y1 = y[i];
    float y2 = y[min(i + 1, 4)];
    return mix(y1, y2, f);
}

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri ayarla
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // Flutter koordinatını al
    vec2 fragCoord = FlutterFragCoord().xy;

    // Y eksenini ters çevir
    vec2 uv = vec2(fragCoord.x / iResolution.x, 1.0 - fragCoord.y / iResolution.y);

    // === PADDING ===
    float sidePadding = 0.005;
    uv.x = (uv.x - sidePadding) / (1.0 - 2.0 * sidePadding);

    // Kenar dışını temizle
    if (uv.x < 0.0 || uv.x > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 pxSize = 1.0 / iResolution.xy;

    // Kalınlık Ayarı (uStroke ile dinamik)
    float thickness = max(0.5, uStroke) * length(pxSize) * 2.0;

    // Dalga Yüksekliği Hesaplama
    float y[5];
    for (int i = 0; i < 5; i++) {
        float f = getFreq(i);
        y[i] = clamp(f * getScale(i) * SCALE * uIntensity, 0.0, 0.8);
    }

    float curveY = sampleCurve(uv.x, y);
    float baseY = 0.009;
    float lineY = baseY + curveY;

    // Mesafe Hesabı (SDF)
    float d = abs(uv.y - lineY);

    // 1. FILL (Dolgu)
    float fillAlpha = 0.0;
    if (uv.y >= baseY && uv.y <= lineY) {
        fillAlpha = FILL_OPACITY;
    }

    // 2. STROKE (Net Çizgi)
    float stroke = 1.0 - smoothstep(0.0, thickness, d);

    // 3. GLOW (Parlama)
    float glowInput = max(uGlow, 0.0);
    float glow = exp(-d * 20.0) * glowInput;

    // --- RENKLENDİRME ---
    vec3 grad = mix(uColor, uColor2, clamp(uv.y * 1.5, 0.0, 1.0));

    // Toplam Görünürlük
    float intensity = fillAlpha + stroke + glow;

    // Renk hesaplama
    vec3 finalColor = grad * intensity;

    // Alpha hesaplama
    float finalAlpha = clamp(intensity, 0.0, 1.0);

    // Çıktı
    fragColor = vec4(finalColor, finalAlpha);
}