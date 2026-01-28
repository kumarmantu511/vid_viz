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

// UI'dan gelen slider (Glow)
uniform float uGlow;
uniform float uStroke;

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

void main() {
    vec2 res = uResolution.xy;
    vec2 uv = FlutterFragCoord().xy / res;

    // YÖN ÇEVİRME (Baslar Solda, Tizler Sağda)
    uv.x = 1.0 - uv.x;

    float t = uTime * (0.6 * uSpeed);

    // Frekans örnekleme
    float x = uv.x;
    float f = sampleFreq(x);
    // Genlik ayarı
    float baseAmp = clamp(f * uIntensity, 0.0, 1.2);

    // 3 Farklı Sinüs Dalgası
    float y0 = 0.50 + 0.12 * baseAmp * sin(10.0 * x + t);
    float y1 = 0.50 + 0.18 * baseAmp * sin(10.0 * x + t + 1.8);
    float y2 = 0.50 + 0.24 * baseAmp * sin(10.0 * x + t + 3.6);

    float px = 1.0 / min(res.x, res.y);

    // KALINLIK AYARI
    // uStroke slider'ı ile çizgi kalınlığını kontrol ediyoruz.
    // 0.6 çarpanı ile daha kibar/ince başlatıyoruz.
    float strokeVal = max(0.1, uStroke);
    float halfThickness = px * (strokeVal * 0.6);

    // Mesafeler
    float d0 = abs(uv.y - y0);
    float d1 = abs(uv.y - y1);
    float d2 = abs(uv.y - y2);

    // --- NETLİK (CORE) ---
    // Smoothstep ile jilet gibi keskin kenarlar
    float c0 = 1.0 - smoothstep(halfThickness, halfThickness + px, d0);
    float c1 = 1.0 - smoothstep(halfThickness, halfThickness + px, d1);
    float c2 = 1.0 - smoothstep(halfThickness, halfThickness + px, d2);

    // --- GLOW (PARLAMA) ---
    // uGlow 0 ise, glowInput 0 olur ve sadece core çizilir.
    float glowInput = max(uGlow, 0.0);

    // exp fonksiyonu ile ışık yayılımı.
    // Sayıyı (40.0) ne kadar büyütürsek ışık o kadar "sıkı" olur, dağılmaz.
    float g0 = exp(-d0 * 40.0) * glowInput * 0.6;
    float g1 = exp(-d1 * 40.0) * glowInput * 0.6;
    float g2 = exp(-d2 * 40.0) * glowInput * 0.6;

    // --- ALPHA HESAPLAMASI ---
    // Işık gücünü sadece Alpha (görünürlük) kanalında topluyoruz.
    // Rengi çarpmıyoruz!
    float totalAlpha = (c0 + g0) + (c1 + g1) + (c2 + g2);

    // Hiç görünmeyen pikselleri at (Performans)
    if (totalAlpha < 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // --- RENK SEÇİMİ ---
    // Gradient (Renk Geçişi)
    float gy = clamp(uv.y, 0.0, 1.0);
    vec3 baseColor = mix(uColor, uColor2, gy);

    // --- CAM EFEKTİ (BEYAZLAMA OLMADAN) ---
    // Sadece Alpha'yı 0-1 arasına sıkıştırıyoruz.
    float finalAlpha = clamp(totalAlpha, 0.0, 1.0);

    // --- PREMULTIPLIED ALPHA ÇIKIŞI ---
    // Flutter için kural: Renk * Alpha, Alpha
    // Burada rengi (baseColor) asla 1.0'dan büyük bir sayıyla çarpmıyoruz.
    // Sadece Alpha ile çarpıyoruz. Bu sayede renk ASLA değişmez/sarılaşmaz.
    fragColor = vec4(baseColor * finalAlpha, finalAlpha);
}