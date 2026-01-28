#version 300 es
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

uniform float uGlow;   // Parlama Şiddeti
uniform float uStroke; // Çizgi Kalınlığı

out vec4 fragColor;

// Yardımcı fonksiyon: Frekans değerlerini al
float bandValue(int i) {
    return (i == 0) ? uFreq0 : (i == 1) ? uFreq1 : (i == 2) ? uFreq2 : (i == 3) ? uFreq3 :
    (i == 4) ? uFreq4 : (i == 5) ? uFreq5 : (i == 6) ? uFreq6 : uFreq7;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    // UV koordinatlarını standartlaştır (Merkez 0,0)
    vec2 uv = (2.0 * fragCoord - uResolution) / uResolution.y;

    // --- 1. DALGA FORMU HESABI (Aynen korundu) ---
    float osc = 0.0;
    for (int i = 0; i < 8; i++) {
        float amp = bandValue(i);
        float w = 1.0 - float(i) / 10.0;

        float freq = float(i + 1) / 8.0;
        freq *= freq;

        float phase = (0.3 + 0.1 * float(i)) * uSpeed;

        // Orijinal "elektrikli" yapı
        osc += w * amp * sin(freq * (uv.x * 1000.0 + uTime * 500.0 * phase));
    }
    osc /= 8.0;

    // --- 2. HEDEF VE MESAFE ---
    float targetY = osc * uIntensity;
    float distY = abs(uv.y - targetY); // UV uzayındaki mesafe
    float distInPixels = distY * uResolution.y * 0.5; // Piksel mesafesi

    // --- 3. NET ÇİZGİ (STROKE) ---
    // Bu kısım o "kusursuz netlik" dediğin yer.
    float baseThickness = max(1.0, uStroke * 2.0);
    float thickness = baseThickness;

    // Çizginin kendisi (Sadece son 1.5 piksel yumuşak, gerisi tam dolu)
    float coreAlpha = 1.0 - smoothstep(thickness * 0.5, thickness * 0.5 + 1.5, distInPixels);

    // --- 4. GLOW (PARLAMA) - YENİ ---
    // Çizgi merkezinden dışarı doğru ışık yayılımı.
    // 20.0 değeri ışığın yayılma mesafesidir.
    float glowInput = max(uGlow, 0.0);
    float glowAlpha = exp(-distY * 20.0) * glowInput;

    // --- 5. RENK (SAF GRADYAN) ---
    float gx = clamp(fragCoord.x / uResolution.x, 0.0, 1.0);
    vec3 col = mix(uColor, uColor2, gx);

    // --- 6. BİRLEŞTİRME ---
    // Net Çizgi + Parlama
    float totalAlpha = clamp(coreAlpha + glowAlpha, 0.0, 1.0);

    // Çıktı
    if (totalAlpha <= 0.0) {
        fragColor = vec4(0.0);
    } else {
        // Premultiplied Alpha
        fragColor = vec4(col * totalAlpha, totalAlpha);
    }
}