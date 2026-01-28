#version 460 core

#include <flutter/runtime_effect.glsl>

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

uniform float uGlow;    // Parlama Şiddeti
uniform float uBarFill; // Bar Boşluk/Doluluk oranı
out vec4 fragColor;

float sampleFreq(float x) {
    float fi = clamp(x, 0.0, 1.0) * 7.0;
    float i0 = floor(fi);
    float i1 = min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float f0 = (i0 < 0.5) ? uFreq0 : (i0 < 1.5) ? uFreq1 : (i0 < 2.5) ? uFreq2 : (i0 < 3.5) ? uFreq3 :
    (i0 < 4.5) ? uFreq4 : (i0 < 5.5) ? uFreq5 : (i0 < 6.5) ? uFreq6 : uFreq7;
    float f1 = (i1 < 0.5) ? uFreq0 : (i1 < 1.5) ? uFreq1 : (i1 < 2.5) ? uFreq2 : (i1 < 3.5) ? uFreq3 :
    (i1 < 4.5) ? uFreq4 : (i1 < 5.5) ? uFreq5 : (i1 < 6.5) ? uFreq6 : uFreq7;
    return mix(f0, f1, t);
}

// Kapsül Mesafe Fonksiyonu (SDF)
float capsuleDist(vec2 uv, vec2 center, float halfWidth, float halfHeight) {
    vec2 p = uv - center;
    float r = halfWidth;
    float lineHalf = max(halfHeight - r, 0.0);
    float y = clamp(p.y, -lineHalf, lineHalf);
    vec2 q = p - vec2(0.0, y);
    return length(q) - r;
}

void main() {
    vec2 res = uResolution.xy;
    vec2 uv = FlutterFragCoord().xy / res;

    // Bar sayısı limiti
    float bars = clamp(uBars, 4.0, 128.0);

    float totalWidth = 0.90;
    float barW = totalWidth / bars;

    // --- BOŞLUK HESABI (KORUNDU) ---
    // uBarFill mantığı aynen korundu:
    // 1.0 -> Az boşluk (Kalın bar)
    // 0.0 -> Çok boşluk (İnce bar)
    float fill = 1.0 - clamp(uBarFill > 0.0 ? uBarFill : 0.8, 0.05, 1.0);

    float spacing   = barW * fill;
    float halfWidth = (barW - spacing) * 0.5;

    // Negatif genişlik hatasını önlemek için güvenlik
    halfWidth = max(halfWidth, 0.0001);

    float idx = floor(uv.x * bars);
    float barStart = idx / bars;
    float barCenterX = barStart + barW * 0.5;

    // Frekans örnekleme
    float sampleX = pow((idx + 0.5) / bars, 0.8);
    float f = sampleFreq(sampleX);

    // Yükseklik hesaplaması
    float height = clamp(max(f, 0.01) * (0.8 + 0.4 * uIntensity), 0.02, 0.98);
    height *= (0.95 + 0.1 * clamp(uSpeed, 0.0, 2.0));

    float halfHeight = height * 0.48;

    // Mesafe hesabı (SDF)
    // dist < 0 : Barın içi
    // dist > 0 : Barın dışı
    float dist = capsuleDist(uv, vec2(barCenterX, 0.5), halfWidth, halfHeight);

    // --- 1. NETLİK (SHAPE) ---
    float px = 1.0 / min(res.x, res.y);
    // Barın kendisi (Jilet gibi net)
    float shapeAlpha = 1.0 - smoothstep(0.0, px * 2.0, dist);

    // --- 2. GLOW (PARLAMA) - YENİ ---
    // Barın dışına (dist > 0) taşan ışık
    float glowInput = max(uGlow, 0.0);
    float glowDist = max(dist, 0.0);
    // 20.0 faktörü ışığın ne kadar uzağa yayılacağını belirler (Daha küçük = Daha geniş)
    float glowAlpha = exp(-glowDist * 70.0) * glowInput;

    // --- 3. RENK ---
    float gy = clamp(uv.y, 0.0, 1.0);
    vec3 grad = mix(uColor, uColor2, gy);

    // --- 4. BİRLEŞTİRME ---
    // Toplam Görünürlük = Bar + Parlama
    float finalAlpha = clamp(shapeAlpha + glowAlpha, 0.0, 1.0);

    if (finalAlpha <= 0.001) {
        fragColor = vec4(0.0);
    } else {
        // Premultiplied Alpha
        fragColor = vec4(grad * finalAlpha, finalAlpha);
    }
}