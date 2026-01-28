#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// Sabitler
const float PI = 3.14159265359;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // 1. ERKEN ÇIKIŞ
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // 2. EKRAN BÜKME (CRT/Sphere Curve)
    // Orijinal koddaki 'outlineCurve' mantığının optimize edilmiş hali.
    // pow() yerine çarpma kullanarak GPU'yu rahatlatıyoruz.

    // UV'yi merkeze al (-0.5 ile 0.5 arası)
    vec2 centered = uv - 0.5;

    // Bükülme miktarı (Intensity ile kontrol edilebilir)
    // Y eksenine göre X'i, X eksenine göre Y'yi büküyoruz.
    float distSq = dot(centered, centered);

    // 'warp' faktörü: Kenarlara gittikçe koordinatları içeri çek
    vec2 warp = centered * (1.0 + 0.4 * distSq * uIntensity);

    // UV'yi tekrar 0..1 aralığına getir
    vec2 warpedUV = warp + 0.5;

    // 3. KENAR KONTROLÜ (Siyah Çerçeve)
    // if blokları yerine step kullanıyoruz.
    // Eğer warpedUV 0.0-1.0 aralığının dışına çıktıysa 'mask' 0 olur.
    vec2 bounds = step(vec2(0.0), warpedUV) * step(warpedUV, vec2(1.0));
    float mask = bounds.x * bounds.y;

    // 4. SCANLINES (Tarama Çizgileri)
    // Sinüs dalgası ile TV çizgisi efekti
    float scanParams = warpedUV.y * uResolution.y * 0.5; // Sıklık
    float scanline = sin(scanParams * PI * 2.0);

    // Çizgileri yumuşat (0.0 ile 1.0 arasına çek ve intensity ile karıştır)
    // intensity 1.0 ise çizgiler net, 0.0 ise çizgiler yok.
    float scanMask = 1.0 - (0.5 * scanline + 0.5) * 0.1 * uIntensity;

    // 5. VIGNETTE (Köşe Karartma)
    // Ekranın köşelerini hafifçe karart
    float vig = 16.0 * warpedUV.x * warpedUV.y * (1.0 - warpedUV.x) * (1.0 - warpedUV.y);
    vig = pow(vig, 0.15); // Parlaklık eğrisi

    // 6. RENK OKUMA
    // Eğer mask 0 ise (ekran dışı) texture okumaya gerek yok, siyah bas.
    vec3 color = vec3(0.0);

    if (mask > 0.0) {
        // Bükülmüş koordinattan resim oku
        color = texture(uTexture, warpedUV).rgb;

        // Efektleri uygula
        color *= scanMask; // Çizgiler
        color *= vig;      // Köşe kararması
    }

    // Sonuç (Maske ile ekran dışını siyah yap)
    fragColor = vec4(color * mask, 1.0);
}