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

uniform float uGlow;
uniform sampler2D iChannel0;

out vec4 fragColor;

vec3 iResolution;
float iTime;

#define M_2PI 6.28318530718

// Optimize edilmiş polar koordinat dönüşümü
vec2 polar(vec2 dPoint) {
    float r = length(dPoint);
    return vec2(r, atan(dPoint.y, dPoint.x));
}

// Optimize edilmiş random
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Optimize edilmiş kartezyen koordinat dönüşümü
vec2 decart(vec2 pPoint) {
    float c = cos(pPoint.y);
    float s = sin(pPoint.y);
    return pPoint.x * vec2(c, s);
}

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri ayarla
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // Flutter koordinatını al
    vec2 fragCoord = FlutterFragCoord().xy;

    // Y eksenini ters çevir
    vec2 flippedCoord = vec2(fragCoord.x, iResolution.y - fragCoord.y);

    vec2 center = iResolution.xy * 0.5;
    vec2 frag = flippedCoord - center;
    vec2 fragPolar = polar(frag);
    float lenCenter = length(center);

    const float bandPass = 720.0;
    const float angleDisp = M_2PI / (bandPass + 1.0);

    // Optimize: Parçacık sayısı ve yaşam ömrü sabitleri
    const float particlesCount = 150.0;
    const float particleLifetime = 15.0;
    const float particleMaxSize = 25.0;

    float globTime = iTime / particleLifetime;
    float timeDelta = bandPass;

    const float polarRadiusClip = 0.05;
    const float polarRadiusMax = 0.75;
    float polarRadiusDelta = polarRadiusMax - polarRadiusClip;

    float presence = 0.0;
    vec2 pPoint;

    // Loop
    for (float i = 0.0; i < particlesCount; i += 1.0) {
        float phase = i / particlesCount;

        float localTime = globTime + timeDelta * (2.0 * phase - 1.0) + phase;
        float particleTime = fract(localTime);

        // Hızlı üs alma işlemi (pow yerine çarpma)
        float pt2 = particleTime * particleTime;
        float pt4 = pt2 * pt2;
        float spaceTransform = pt4 * pt4; // ^8

        pPoint.x = lenCenter * ((polarRadiusClip + polarRadiusDelta * phase) + spaceTransform);

        // Early exit optimization (Menzil dışındakileri hesaplama)
        float distCheck = abs(pPoint.x - fragPolar.x);
        if (distCheck > particleMaxSize) continue;

        // Random seed
        float seed = floor(localTime);
        pPoint.y = floor(particleTime + bandPass * rand(vec2(mod(seed, 10000.0), 1.0))) * angleDisp;

        vec2 dPoint = decart(pPoint);
        float dist = length(dPoint - frag);
        float particleSize = particleMaxSize * spaceTransform;

        // Smooth geçiş
        float localPresence = smoothstep(particleSize * 1.2, 0.0, dist);
        presence += localPresence;
    }

    // --- ORTADAKİ TOPU GİZLEME ---
    // Merkezden itibaren 0 ile 50 piksel arasını maskeler.
    // fragPolar.x (yarıçap) kullanılarak merkeze yakın yerler 0.0 ile çarpılır.
    float centerMask = smoothstep(10.0, 50.0, fragPolar.x);
    presence *= centerMask;

    // Normalize ve clamp
    presence = clamp(presence * 0.5, 0.0, 1.0);

    // Renk + şeffaf arka plan
    float alpha = presence;
    float tcol = clamp(fragPolar.x / max(lenCenter, 1.0), 0.0, 1.0);
    vec3 tint = mix(uColor, uColor2, tcol);

    vec3 color = tint * alpha;

    fragColor = vec4(color, alpha);
}