#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;

// Parametreler
uniform float uIntensity;    // 0.0 - 1.0
uniform float uBlurRadius;   // 0.0 - 50.0

out vec4 fragColor;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float GOLDEN_ANGLE = 2.39996323;

// --- DÜZELTME ---
// Bozulmayı engellemek için ITERATION sayısını artırdık.
// 64.0, mobil cihazlar için "High Quality" standardıdır.
// Daha düşüğü (32 gibi) büyük yarıçapta "noktalanma" yapar.
const float ITERATIONS = 64.0;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // Erken Çıkış
    if (uIntensity < 0.01 || uBlurRadius < 0.5) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    vec4 sourceColor = texture(uTexture, uv);

    // Pixel boyutunu hesapla
    vec2 pixelSize = 1.0 / uResolution;

    // Yarıçapı, ekranın kısa kenarına göre normalize et (Tutarlılık için)
    // Bu sayede blur miktarı ekran çözünürlüğünden bağımsız doğru çalışır.
    float radiusFactor = uBlurRadius * 1.5;

    vec3 acc = vec3(0.0);
    float totalWeight = 0.0;

    // --- GOLDEN ANGLE SPIRAL (ARTIFACT KORUMALI) ---
    for (float i = 0.0; i < ITERATIONS; i++) {

        // 1. İlerleme Oranı (0.0 -> 1.0)
        float progress = i / ITERATIONS;

        // 2. Açı (Spiral)
        float theta = i * GOLDEN_ANGLE;

        // 3. Mesafe (Karekök ile doğal yayılım)
        float r = sqrt(progress);

        // 4. Koordinat Ofseti
        // Buradaki cos/sin ile spiral çiziyoruz.
        // pixelSize ile çarparak "gerçek piksel" mesafesinde kalıyoruz.
        vec2 offset = vec2(cos(theta), sin(theta)) * r * radiusFactor * pixelSize;

        // Aspect Ratio Düzeltmesi (Dairenin ovalleşmesini engeller)
        offset.x *= uResolution.y / uResolution.x;

        // 5. BOZULMAYI ÖNLEYEN AĞIRLIK (Gaussian Falloff)
        // Merkezden uzaklaştıkça (r arttıkça) piksellerin etkisini azaltıyoruz.
        // Eğer bunu yapmazsak, en dıştaki pikseller "ayrık" görünür ve bozulma olur.
        // 'r * r * 2.5' değeri, yumuşaklık ve netlik arasındaki en iyi dengedir.
        float weight = exp(-r * r * 2.5);

        // 6. KENAR KORUMASI (CLAMP)
        // Blur yaparken resmin dışına çıkıp siyah/bozuk renk çekmemesi için clamp'liyoruz.
        vec2 samplePos = clamp(uv + offset, 0.0, 1.0);

        acc += texture(uTexture, samplePos).rgb * weight;
        totalWeight += weight;
    }

    vec3 finalBlur = acc / totalWeight;

    // Mix işlemi
    vec3 result = mix(sourceColor.rgb, finalBlur, clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(result, 1.0);
}