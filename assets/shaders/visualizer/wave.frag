#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;   // SOL RENK
uniform float uBars;
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;  // SAĞ RENK

uniform float uGlow;   // Parlama
uniform float uStroke; // Kalınlık
uniform sampler2D iChannel0;

out vec4 fragColor;

vec3 iResolution;
float iTime;

// --- FREKANS OKUMA (Dokunulmadı) ---
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

// HATA KAYNAĞI OLAN MAKROLAR SİLİNDİ (#define texture ve #define REAL_FFT)
// Yerine aşağıdaki yardımcı fonksiyon yazıldı:

float getRealFFT(float x) {
    // texture() yerine _vidvizTexture() kullanıldı.
    // Orijinal makro: pow(texture(iChannel0, vec2(clamp(x, 0.0, 1.0), 0.25)).r, 1.5)
    return pow(_vidvizTexture(iChannel0, vec2(clamp(x, 0.0, 1.0), 0.25)).r, 1.5);
}

// AYARLAR
#define SEGMENTS 24.0       // Segment sayısı
#define WAVE_HEIGHT 0.55    // Dalga yüksekliği

// Cubic Interpolation (Dalganın şeklini belirleyen fonksiyon - Dokunulmadı)
float cubicInterp(float t) {
    return t * t * (3.0 - 2.0 * t);
}

// Dalga Yüksekliği Hesaplama (Makro yerine fonksiyon kullanıldı)
float lowResWave(float x) {
    float seg = 1.0 / SEGMENTS;
    float i0 = floor(x / seg);
    float i1 = i0 + 1.0;
    float x0 = i0 * seg;
    float x1 = min(i1 * seg, 1.0);

    // REAL_FFT makrosu yerine getRealFFT fonksiyonu çağrıldı
    float a0 = getRealFFT(x0);
    float a1 = getRealFFT(x1);

    float t = (x - x0) / seg;
    return mix(a0, a1, cubicInterp(t));
}

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri ayarla
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // Flutter koordinatlarını al
    vec2 fragCoord = FlutterFragCoord().xy;

    vec2 uv = fragCoord / iResolution.xy;

    // Y eksenini düzeltme (Eski koddaki terslik korundu)
    uv.y = 1.0 - uv.y;

    // --- 1. DALGA GEOMETRİSİ ---
    float centerY = 0.5;
    // uIntensity ile yükseklik kontrolü
    float amp = lowResWave(uv.x) * uIntensity;
    float waveY = centerY + (amp - 0.5) * WAVE_HEIGHT;

    // Mesafe hesabı (SDF mantığı)
    float dist = abs(uv.y - waveY);
    // Piksel cinsinden mesafe (Netlik için şart)
    float distInPixels = dist * iResolution.y;

    // --- 2. NET ÇİZGİ (CORE) ---
    // uStroke ile kalınlık (Min 1.0 piksel)
    float thickness = max(1.0, uStroke * 2.0);

    // Çizginin kendisi (Sadece en uçtaki 1.5 piksel yumuşatılır, içi tam dolu)
    float lineAlpha = 1.0 - smoothstep(thickness * 0.5, thickness * 0.5 + 1.5, distInPixels);

    // --- 3. GLOW (PARLAMA) ---
    // Çizgiden uzaklaştıkça azalan ışık (Exponential falloff)
    float glowInput = max(uGlow, 0.0);
    float glowAlpha = exp(-dist * 50.0) * glowInput; // 50.0 yayılma katsayısı

    // --- 4. RENK ---
    // Soldan sağa temiz gradient (uColor -> uColor2)
    vec3 col = mix(uColor, uColor2, uv.x);

    // --- 5. BİRLEŞTİRME ---
    // Toplam görünürlük = Net Çizgi + Parlama
    float totalAlpha = clamp(lineAlpha + glowAlpha, 0.0, 1.0);

    if (totalAlpha <= 0.001) {
        fragColor = vec4(0.0);
    } else {
        // Premultiplied Alpha
        fragColor = vec4(col * totalAlpha, totalAlpha);
    }
}