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
uniform float uBarFill; // Bar Kalınlığı / Boşluk Ayarı
uniform sampler2D iChannel0;

out vec4 fragColor;

vec3 iResolution;
float iTime;

#define M_PI 3.14159265359

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

// HATA KAYNAĞI OLAN #define texture SİLİNDİ.

// --- YARDIMCI FONKSİYONLAR (Korundu) ---
vec2 rotate(vec2 point, vec2 center, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    point -= center;
    return vec2(point.x * c - point.y * s, point.x * s + point.y * c) + center;
}
vec4 capsule(vec4 color, vec4 background, vec4 region, vec2 uv) {
    vec2 diff = uv - region.xy;
    if (abs(diff.x) < region.z && abs(diff.y) < region.w) return color;
    float d1 = length(diff - vec2(0.0, region.w));
    float d2 = length(diff + vec2(0.0, region.w));
    if (d1 < region.z || d2 < region.z) return color;
    return background;
}
vec4 bar(vec4 color, vec4 background, vec2 position, vec2 dimensions, vec2 uv) {
    return capsule(color, background, vec4(position.x, position.y + dimensions.y * 0.5, dimensions.x * 0.5, dimensions.y * 0.5), uv);
}
vec4 rays(vec4 color, vec4 background, vec2 position, float radius, float rays, float ray_length, sampler2D sound, vec2 uv) {
    return background;
}

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri ayarla
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // Flutter koordinatını al
    vec2 fragCoord = FlutterFragCoord().xy;

    // Koordinat düzeltme (Ters Y ekseni için)
    vec2 flippedCoord = vec2(fragCoord.x, iResolution.y - fragCoord.y);

    // Merkeze hizalanmış koordinatlar
    vec2 p = (flippedCoord - 0.5 * iResolution.xy) / iResolution.y;

    float r = length(p);
    float a = atan(p.y, p.x);

    // --- AYARLAR ---
    // Bar sayısı (Min 4, Max 128)
    float raysCount = clamp(uBars, 4.0, 128.0);

    float innerRadius = 0.20;
    float maxLen = 0.28 * clamp(uIntensity, 0.5, 2.0);

    // --- KALINLIK VE BOŞLUK HESABI ---
    float fillRatio = clamp(uBarFill > 0.0 ? uBarFill : 0.5, 0.05, 1.0);

    // thickness: Yarıçap (half-width)
    float thickness = (M_PI * innerRadius / raysCount) * fillRatio;

    // En yakın "ray" (ışın) hesaplama
    float t = fract((a + M_PI) / (2.0 * M_PI));
    float idx = floor(t * raysCount);
    float ang = (idx + 0.5) / raysCount * (2.0 * M_PI) - M_PI;
    vec2 dir = vec2(cos(ang), sin(ang));

    // Ses verisini al
    float sampleX = (idx + 0.5) / raysCount;

    // BURASI DÜZELTİLDİ: texture -> _vidvizTexture
    float freq = _vidvizTexture(iChannel0, vec2(sampleX, 0.0)).x;

    freq = pow(clamp(freq, 0.0, 1.0), 0.7);
    float outerRadius = innerRadius + maxLen * freq;

    // Mesafe Alanı (SDF) Hesabı
    float along = dot(p, dir);
    vec2 perpV = p - dir * along;
    float perp = length(perpV);
    float clampedAlong = clamp(along, innerRadius, outerRadius);
    float dAlong = along - clampedAlong;

    // dist: Şekle olan en yakın mesafe.
    float dist = length(vec2(perp, dAlong)) - thickness;

    // --- NETLİK (Anti-Aliasing) ---
    float px = 1.0 / max(iResolution.y, 1.0);
    float aa = px * 1.75;
    // mask: 1.0 = Şeklin içi (Tam Net), 0.0 = Dışı
    float mask = 1.0 - smoothstep(0.0, aa, dist);

    // --- GLOW (PARLAMA) EKLENTİSİ ---
    float glowDist = max(dist, 0.0);
    // 20.0 çarpanı ışığın yayılma sertliği.
    float glowAmt = exp(-glowDist * 20.0) * max(uGlow, 0.0);

    // --- RENK (Gradient) ---
    float gy = (outerRadius > innerRadius) ? clamp((along - innerRadius) / (outerRadius - innerRadius), 0.0, 1.0) : 0.0;
    vec3 col = mix(uColor, uColor2, gy);

    // --- BİRLEŞTİRME ---
    float finalAlpha = clamp(mask + glowAmt, 0.0, 1.0);

    fragColor = vec4(col * finalAlpha, finalAlpha);
}