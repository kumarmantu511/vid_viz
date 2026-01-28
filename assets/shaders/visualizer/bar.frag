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

uniform float uGlow;     // Parlama
uniform float uBarFill;  // Doluluk oranı
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

// --- ANA FONKSİYON ---
void main() {
    // 1. Global ayarlar
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // FlutterFragCoord koordinatını alıyoruz
    vec2 fragCoord = FlutterFragCoord().xy;

    // 2. Koordinatları ayarla (UV hesabı)
    vec2 uv = vec2(fragCoord.x, iResolution.y - fragCoord.y) / iResolution.xy;

    // Yan Boşluklar (Margin)
    float sideMargin = 0.005;
    uv.x = (uv.x - sideMargin) / (1.0 - 2.0 * sideMargin);

    if (uv.x < 0.0 || uv.x > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Y eksenini scale et
    vec2 nv = uv;
    nv.y = (nv.y - 0.005) * 2.0;

    // --- 3. BAR GEOMETRİSİ ---
    float barCount = max(1.0, uBars);

    // Bar Genişliği
    float fillRatio = clamp(uBarFill, 0.05, 0.95);

    // Hangi barda olduğumuzu bul
    float barIndex = floor(uv.x * barCount);

    // Barın içindeki merkez X koordinatını bul
    float cellX = fract(uv.x * barCount);

    // Barın görünür yarıçapı
    float radiusX = fillRatio * 0.5;

    // --- 4. YÜKSEKLİK ---
    // texture() yerine _vidvizTexture kullanıldı
    float h = _vidvizTexture(iChannel0, vec2(barIndex / barCount, 0.0)).r;
    h = clamp(h * uIntensity, 0.0, 1.0);

    // --- 5. SDF (MESAFE ALANI) HESABI ---
    float aspect = iResolution.x / iResolution.y;
    float visibleBarWidthUV = (fillRatio / barCount);
    float radiusY = visibleBarWidthUV * aspect * 0.5 * 2.0;

    // Barın düz kısmının bittiği nokta
    float rectTop = h - radiusY;

    // Mesafe hesabı
    float dist = 0.0;
    float distToCenterX = abs(cellX - 0.5);

    if (nv.y < rectTop) {
        float dx = distToCenterX - radiusX;
        dist = dx * (iResolution.x / barCount);
    } else {
        float dxPx = (distToCenterX) * (iResolution.x / barCount);
        float dyPx = (nv.y - rectTop) * (iResolution.y / 2.0);
        float radiusPx = radiusY * (iResolution.y / 2.0);
        dist = length(vec2(dxPx, dyPx)) - radiusPx;
    }

    // --- 6. ÇİZİM VE GLOW ---
    float shapeAlpha = 1.0 - smoothstep(-0.5, 1.0, dist);

    if (nv.y < 0.0) shapeAlpha = 0.0;

    float glowInput = max(uGlow, 0.0);
    float glowDist = max(dist, 0.0);
    float glowAlpha = exp(-glowDist * 0.2) * glowInput;

    float finalAlpha = clamp(shapeAlpha + glowAlpha, 0.0, 1.0);

    // --- 7. RENK ---
    float gy = clamp(uv.y, 0.0, 1.0);
    vec3 tint = mix(uColor, uColor2, gy);

    // Renkleri birleştir ve çıktı ver
    if (finalAlpha <= 0.001) {
        fragColor = vec4(0.0);
    } else {
        fragColor = vec4(tint * finalAlpha, finalAlpha);
    }
}