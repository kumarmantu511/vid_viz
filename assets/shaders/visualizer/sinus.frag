#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;   // Sol Renk
uniform float uBars;
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;  // Sağ Renk

uniform float uGlow;   // Parlama Şiddeti
uniform float uStroke; // Çizgi Kalınlığı

out vec4 fragColor;

float bandValue(int i) {
    return (i == 0) ? uFreq0 : (i == 1) ? uFreq1 : (i == 2) ? uFreq2 : (i == 3) ? uFreq3 :
    (i == 4) ? uFreq4 : (i == 5) ? uFreq5 : (i == 6) ? uFreq6 : uFreq7;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = (2.0 * fragCoord - uResolution) / uResolution.y;

    // --- 1. DALGA HESABI (Aynen korundu) ---
    float osc = 0.0;
    for (int i = 0; i < 8; i++) {
        float amp = clamp(bandValue(i), 0.0, 1.0);
        float w = 1.0 - float(i) / 10.0;
        float freq = float(i + 1);
        float phase = (0.6 + 0.1 * float(i)) * uSpeed;
        osc += w * amp * sin(freq * (uv.x * 4.0 + uTime * phase));
    }
    osc /= 8.0;

    // --- 2. HEDEF VE MESAFE ---
    float targetY = osc * uIntensity;
    float distY = abs(uv.y - targetY); // UV uzayındaki mesafe

    // Piksel cinsinden mesafe (Netlik için)
    float distInPixels = distY * uResolution.y * 0.5;

    // --- 3. KALINLIK VE NETLİK (Stroke) ---
    float avgAmp = (osc + 1.0) * 0.5;

    // Kalınlık hesabı (Senin kodundaki mantık + min 1.0px koruması)
    float baseThickness = max(1.0, uStroke * uResolution.y * 0.002);
    float thickness = baseThickness * (0.8 + 0.4 * avgAmp * uIntensity);

    // Jilet gibi net çizgi (Core Line)
    // Sadece en uçtaki 1.5 piksel yumuşatılır, gerisi tam doludur.
    float lineAlpha = 1.0 - smoothstep(thickness * 0.5, thickness * 0.5 + 1.5, distInPixels);

    // --- 4. GLOW (Parlama) - YENİ KISIM ---
    // Çizgi merkezinden uzaklaştıkça ışık azalır (Exponential falloff).
    // "20.0" değeri ışığın ne kadar uzağa yayılacağını belirler.
    // uGlow 0 gelirse burası 0 olur, etki kapanır.
    float glowInput = max(uGlow, 0.0);
    float glowAlpha = exp(-distY * 20.0) * glowInput;

    // --- 5. RENK KARIŞIMI ---
    // Ekranın solundan sağına (0.0 -> 1.0) saf geçiş
    float gx = clamp(fragCoord.x / uResolution.x, 0.0, 1.0);
    vec3 col = mix(uColor, uColor2, gx);

    // --- 6. BİRLEŞTİRME ---
    // Toplam Görünürlük = Çizgi + Parlama
    // clamp ile 1.0'ı geçmesini engelliyoruz.
    float totalAlpha = clamp(lineAlpha + glowAlpha, 0.0, 1.0);

    if (totalAlpha <= 0.0) {
        fragColor = vec4(0.0);
    } else {
        // Premultiplied Alpha (Leke yapmaması için standart)
        fragColor = vec4(col * totalAlpha, totalAlpha);
    }
}