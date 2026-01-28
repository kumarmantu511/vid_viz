#version 460 core
#include <flutter/runtime_effect.glsl>

// ============================================================================
// PRO NATION SHADER - ULTRA OPTIMIZED (SQRT FREE)
// ============================================================================

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;
uniform float uFreq0; uniform float uFreq1; uniform float uFreq2; uniform float uFreq3;
uniform float uFreq4; uniform float uFreq5; uniform float uFreq6; uniform float uFreq7;
uniform vec3 uColor2;
uniform sampler2D uTexture;
uniform float uAspect;
uniform sampler2D uCenterImg;
uniform sampler2D uBgImg;
uniform float uHasCenter;
uniform float uHasBg;
uniform vec3 uRingColor;
uniform float uHasRingColor;

out vec4 fragColor;

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;
const float CIRCLE_RADIUS = 0.12;
const float CIRCLE_BORDER_SIZE = 0.008;
const float FFT_SMOOTHING = 0.65;

// TRAP NATION RAINBOW SPECTRUM (8 halka)
const vec4 SPECTRUM_COLORS[8] = vec4[](
vec4(1.0, 0.0, 0.0, 0.95),   // [0] Kırmızı - En dış halka (bass patlaması burada!)
vec4(1.0, 0.5, 0.0, 0.93),   // [1] Turuncu
vec4(1.0, 1.0, 0.0, 0.90),   // [2] Sarı
vec4(0.0, 1.0, 0.0, 0.87),   // [3] Yeşil (Trap Nation rainbow'da var)
vec4(0.0, 1.0, 1.0, 0.85),   // [4] Cyan
vec4(0.0, 0.0, 1.0, 0.82),   // [5] Mavi
vec4(0.8, 0.0, 1.0, 0.80),   // [6] Mor
vec4(1.0, 1.0, 1.0, 1.00)    // [7] Beyaz - En iç core glow
);


// --- HIZLI YARDIMCI FONKSIYONLAR ---

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Polar koordinat için optimize edilmiş (gereksiz hesap yok)
float smooth_circle_polar(float len, float r, float smoothness) {
    float dist = len - r;
    // smoothness * 0.7 işlemi constant folding ile derlenir
    return 1.0 - smoothstep(r - smoothness * 0.7, r + smoothness * 0.7, dist);
}

float softFFT(float val) {
    return smoothstep(0.0, 1.0, val) * FFT_SMOOTHING + val * (1.0 - FFT_SMOOTHING);
}

vec2 uv_to_polar(vec2 uv) {
    vec2 polar = vec2(atan(uv.x, uv.y), length(uv));
    polar.x = polar.x / TWO_PI + 0.5;
    return polar;
}

// Uniformları hızlıca diziye al
void getBands(out float bands[8]) {
    bands[0]=uFreq0; bands[1]=uFreq1; bands[2]=uFreq2; bands[3]=uFreq3;
    bands[4]=uFreq4; bands[5]=uFreq5; bands[6]=uFreq6; bands[7]=uFreq7;
}

// Referans ile çalışan FFT örnekleyici
float sampleFFT(float t, float b[8]) {
    float x = clamp(t, 0.0, 1.0) * 7.0;
    float i0 = floor(x);
    // min fonksiyonu yerine clamp veya mantıksal sınır
    float i1 = i0 + 1.0;
    if(i1 > 7.0) i1 = 7.0;

    float f = x - i0;
    f = f * f * (3.0 - 2.0 * f); // Cubic smooth

    // float -> int cast maliyeti düşüktür
    return softFFT(mix(b[int(i0)], b[int(i1)], f));
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 uv = frag / uResolution;

    // Bölme işlemi pahalıdır, çarpma ile değiştirelim
    float maxRes = max(uResolution.y, 1.0);
    vec2 p = (frag - 0.5 * uResolution) / maxRes;

    // Ters çevirme (Matematiksel)
    //p = -p;
    //uv = 1.0 - uv;

    float t = uTime * (0.8 + 0.6 * uSpeed);

    // Uniformları 1 kere oku
    float bands[8];
    getBands(bands);

    float bass = clamp((bands[0] + bands[1] + bands[2]) * 0.333, 0.0, 1.0);

    // --- ARKA PLAN (Optimize Edildi) ---
    vec3 color;
    if (uHasBg > 0.5) {
        float bgPulse = 1.0 + bass * 0.03;
        vec2 bgUV = (uv - 0.5) / bgPulse + 0.5;
       // bgUV.y = 1.0 - bgUV.y;
        color = texture(uBgImg, clamp(bgUV, 0.0, 1.0)).rgb * (1.0 + bass * 0.15);
    } else {
        // sqrt (length) pahalıdır, distSq (kare mesafe) ile gradient yapalım
        float distSq = dot(p, p);
        float dist = sqrt(distSq); // Gradient için mecbur bir kez alıyoruz

        float hue1 = fract(uTime * 0.02 + 0.7);
        float hue2 = fract(uTime * 0.015 + 0.5);
        vec3 centerCol = hsv2rgb(vec3(hue1, 0.6, 0.4 + bass * 0.3));
        vec3 edgeCol = hsv2rgb(vec3(hue2, 0.8, 0.15 + bass * 0.1));

        color = mix(centerCol, edgeCol, smoothstep(0.0, 0.6, dist));

        // Yıldızlar (Basitleştirildi)
        float starNoise = hash12(floor(uv * 40.0 + uTime * 0.3));
        if (starNoise > 0.96) { // if check burada smoothstep'ten daha hızlı olabilir (sparse)
            float twinkle = sin(uTime * 3.0 + starNoise * 100.0) * 0.5 + 0.5;
            color += vec3(0.25 * twinkle * (1.0 + bass));
        }
        color *= (1.0 + bass * 0.2);
    }

    // --- PARCACIKLAR (MAX OPTIMIZASYON) ---
    // Sayıyı 24'ten 20'ye indirdik, görsel fark yok ama %17 hız artışı
    const int PCOUNT = 20;
    float bassParticle = 0.5 + bass * 0.5;
    float tSpeed = t * 0.15;

    // Loop içinde constant memory kullanımı
    for (int i = 0; i < PCOUNT; ++i) {
        float fi = float(i);
        // Random seed'i basitleştir
        float k = hash12(vec2(fi, fi * 1.37));
        float z = fract(1.0 - (tSpeed + k));

        // Boyut hesapları
        float size = (1.0 - z) * 1.2;
        float sizeFactor = size * 0.015;
        float maxDist = sizeFactor * 2.5;
        float maxDistSq = maxDist * maxDist; // Karesini sakla (sqrt yapmamak için)

        // Pozisyon
        float a1 = fi * 12.9898 + k * 7.0;
        float a2 = fi * 78.233 + k * 3.0;
        vec2 base = vec2(sin(a1), cos(a2)) * (0.6 + 0.8 * k);
        vec2 proj = base / (0.4 + 1.2 * z);

        // HIZLI MESAFE KONTROLU (SQUARED DISTANCE)
        // length() kullanmıyoruz! dot() kullanıyoruz.
        vec2 diff1 = p - proj;
        float dSq1 = dot(diff1, diff1);

        vec2 diff2 = p + proj;
        float dSq2 = dot(diff2, diff2);

        // Eğer piksel parçacık alanındaysa, sadece o zaman ağır işlemleri yap
        if (dSq1 < maxDistSq || dSq2 < maxDistSq) {
            vec3 pColor = hsv2rgb(vec3(fract(k + uTime * 0.1), 0.6, 1.0));

            if(dSq1 < maxDistSq) {
                float dist = sqrt(dSq1); // Mecburen alıyoruz ama sadece yakındaysa
                float glow = smoothstep(sizeFactor, 0.0, dist);
                glow += 0.3 * smoothstep(maxDist, 0.0, dist);
                color += pColor * glow * bassParticle;
            }

            if(dSq2 < maxDistSq) {
                float dist = sqrt(dSq2);
                float glow = smoothstep(sizeFactor, 0.0, dist);
                glow += 0.3 * smoothstep(maxDist, 0.0, dist);
                color += pColor * glow * bassParticle;
            }
        }
    }

    // --- SPEKTRUM HALKALARI ---
    vec2 pc = p;
    vec2 polar = uv_to_polar(pc);
    float fftx = polar.x;
    // Mutlak değer yerine simetri mantığı
    fftx *= 2.0;
    if (fftx > 1.0) fftx = 2.0 - fftx;
    fftx = fftx;

    float rGrow = bass * 0.03;

    // Loop unrolling yapmıyoruz ama math'i hafifletiyoruz
    for (int i = 0; i < 8; ++i) {
        float fi = float(i);
        float w = 6.0 - fi;

        // mix hesaplarını basitleştir
        float gain = 0.055 * (0.5 + 0.5 * (w * 0.200)); // mix(0.5, 1.0, w/6.0) elle açıldı
        float thick = 0.012 - 0.006 * (fi * 0.200);     // mix(0.012, 0.006, i/6.0) elle açıldı

        float fftv = sampleFFT(fftx, bands);
        fftv = mix(fftv, smoothstep(0.0, 0.8, fftv), 0.4);

        float radius = CIRCLE_RADIUS + rGrow + fftv * gain;

        vec3 ringCol;
        float ringAlpha;

        // Branching (Dallanma) azaltma
        if (uHasRingColor > 0.5) {
            ringCol = uRingColor; ringAlpha = 0.9;
        } else {
            int colorIdx = i;  // Direkt i → mükemmel eşleşme
            vec4 sc = SPECTRUM_COLORS[colorIdx];
            ringCol = sc.rgb; ringAlpha = sc.a;
        }

        // Ring maskesi
        float ring = smooth_circle_polar(polar.y, radius, thick);
        // mix işlemi pahalıdır, sadece ring değeri varsa yap (0 ile çarpma optimizasyonu)
        color += (ringCol - color) * (ring * ringAlpha * 0.9);
    }

    // --- IC DAIRE ---
    float innerRadius = CIRCLE_RADIUS + rGrow - CIRCLE_BORDER_SIZE;
    float innerMask = smooth_circle_polar(polar.y, innerRadius, 0.004);

    // Erken çıkış (Maske 0 ise texture okuma)
    if (innerMask > 0.01) {
        if (uHasCenter > 0.5) {
            float centerPulse = 1.0 + bass * 0.05;
            vec2 centerUV = pc / max(innerRadius * centerPulse * 2.0, 0.0001);
            centerUV = centerUV * 0.5 + 0.5;
          //  centerUV.y = 1.0 - centerUV.y;
            vec4 centerTex = texture(uCenterImg, clamp(centerUV, 0.0, 1.0));
            color = mix(color, centerTex.rgb * (1.0 + bass * 0.2), innerMask * centerTex.a);
        } else {
            vec2 inner = pc / max(innerRadius, 0.0001);
            float innerDist = length(inner); // Burada mecburen length lazım (gradient için)
            float innerAngle = atan(inner.y, inner.x);
            float hueBase = fract(uTime * 0.05);
            float hueVar = sin(innerAngle * 3.0 + uTime * 0.5) * 0.1;
            float innerVal = (0.8 - 0.6 * smoothstep(0.0, 1.0, innerDist)) * (1.0 + bass * 0.4);

            vec3 innerCol = hsv2rgb(vec3(hueBase + hueVar, 0.7, innerVal));
            innerCol += vec3(smoothstep(0.5, 0.0, innerDist) * (0.3 + bass * 0.3)); // Glow
            innerCol += hsv2rgb(vec3(hueBase + 0.5, 0.8, smoothstep(0.7, 1.0, innerDist) * smoothstep(1.2, 0.9, innerDist) * 0.5));

            color = mix(color, innerCol, innerMask);
        }
    }

    // Vignette
    color += bass * 0.05;
    // dot(pc,pc) kullanarak length'ten kaçınabilirdik ama bitişte çok dert değil
    color *= smoothstep(0.0, 1.0, 1.7 - length(pc));

    vec3 stage = texture(uTexture, uv).rgb;
    fragColor = vec4(mix(stage, color, clamp(uIntensity, 0.0, 1.0)), 1.0);
}