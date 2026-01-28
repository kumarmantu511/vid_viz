#version 460 core

#include <flutter/runtime_effect.glsl>

// ============================================================================
// ULTRA REALISTIC CINEMATIC SNOW - (Soft Bokeh & Turbulence)
// ============================================================================

uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;

uniform float uIntensity;    // 0.0 - 1.0 (Görünürlük)
uniform float uSpeed;        // 0.5 - 2.0 (Hız)
uniform float uFlakeSize;    // 0.5 - 2.0 (Boyut)
uniform float uDensity;      // 0.0 - 1.0 (Sıklık)

out vec4 fragColor;

// Rastgelelik Fonksiyonu
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Kar Katmanı (Komşu Taramalı & Yumuşak)
float SnowLayer(vec2 uv, float depth) {
    float t = uTime * uSpeed;

    // Ölçekleme: Derinlik arttıkça taneler küçülür ve sıklaşır
    float scale = (4.0 + depth * 5.0) / clamp(uFlakeSize, 0.5, 2.0);

    vec2 gridUV = uv * scale;
    vec2 id = floor(gridUV);
    vec2 st = fract(gridUV) - 0.5;

    float layerSnow = 0.0;

    // 3x3 Komşu Taraması (Kesilmeyi önler)
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 neighborID = id + offset;

            // Rastgelelik (Her tane için kimlik)
            float n = hash21(neighborID);

            // Sıklık kontrolü
            if (n > uDensity) continue;

            // --- FİZİKSEL HAREKET (SALANA SALANA) ---

            // 1. Düşüş Hızı: Her tane farklı hızda düşer
            float fallSpeed = (0.8 + n * 0.4);
            float yPos = -t * fallSpeed * (0.5 + 1.5 / (depth + 1.0));

            // 2. Türbülans (Rüzgar):
            // İki farklı sinüs dalgasını karıştırıyoruz ki hareket robotik olmasın.
            // Büyük dalga (Ana rüzgar) + Küçük dalga (Titreme)
            float wiggle = sin(t * 1.5 + n * 10.0) * 0.2;     // Geniş salınım
            wiggle += cos(t * 4.0 + n * 30.0) * 0.05;         // Küçük titreme

            // Pozisyonu belirle
            // n sayısını kullanarak her hücrede farklı yerden başlatıyoruz
            vec2 p = offset + vec2(sin(n * 90.0), cos(n * 50.0)) * 0.4;

            // Hareketi uygula
            p.y -= fract(yPos + n * 10.0) * 2.5 - 1.25; // Sürekli döngü
            p.x += wiggle;

            // --- GÖRÜNÜM (STRAFORU YOK ETME KISMI) ---

            float d = length(st - p);

            // Boyut varyasyonu: Kimi büyük kimi küçük
            float sizeBase = (0.1 + n * 0.2) * (1.5 / (depth * 0.8 + 1.0));

            // Pırıltı (Twinkle): Düşerken ışık vurup sönsün
            // Strafor etkisini kıran en önemli detaylardan biri
            float sparkle = 0.8 + 0.4 * sin(t * 10.0 + n * 100.0);

            // --- YUMUŞAKLIK (SOFTNESS) ---
            // smoothstep kullanıyoruz ama kenarları çok geniş tutuyoruz.
            // pow(..., 2.0) yaparak kenarları hızla sönümlendiriyoruz (Bulanık kenar).
            float mask = smoothstep(sizeBase, 0.0, d);
            mask = pow(mask, 3.0); // Karesini/Küpünü alarak "top" görünümünü yumuşatıyoruz

            // Birikim (Parlaklık ile çarp)
            layerSnow += mask * sparkle;
        }
    }

    return layerSnow;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // Aspect Ratio düzeltmesi (Taneler ezilmesin)
    vec2 adjUV = uv;
    adjUV.x *= uResolution.x / uResolution.y;

    vec4 baseColor = texture(uTexture, uv);

    // --- KATMANLARI OLUŞTUR ---
    float snowAcc = 0.0;

    // 3 Farklı Derinlik Katmanı (Parallax)
    // Katmanlar arası kaydırma (vec2 ekleme) yaparak desenin tekrar etmesini önlüyoruz.

    // Katman 1: Çok Arka (Minik tozlar, çok bulanık)
    snowAcc += SnowLayer(adjUV, 5.0) * 0.4;

    // Katman 2: Orta (Normal kar)
    snowAcc += SnowLayer(adjUV + vec2(1.2, 3.4), 2.5) * 0.7;

    // Katman 3: En Ön (Büyük lapa kar, hızlı)
    snowAcc += SnowLayer(adjUV - vec2(2.1, 1.2), 0.8);

    // Kar miktarını sınırla
    snowAcc = clamp(snowAcc, 0.0, 1.0);

    // --- RENK VE IŞIK ---
    // Saf beyaz yerine hafif buz mavisi tonu veriyoruz (Daha soğuk/gerçekçi durur)
    vec3 snowColor = vec3(0.95, 0.98, 1.0);

    // Karıştırma
    // Mix kullanarak arka planı bozmuyoruz.
    // snowAcc ne kadar yoğunsa o kadar beyazlaşıyor.
    vec3 finalRGB = mix(baseColor.rgb, snowColor, snowAcc * uIntensity);

    // Hafif Atmosferik Soğukluk (Opsiyonel - kar yoğunsa resmi biraz soğutur)
    // Eğer bunu istemezsen satırı silebilirsin.
    finalRGB = mix(finalRGB, finalRGB * vec3(0.95, 0.95, 1.05), snowAcc * 0.2);

    fragColor = vec4(finalRGB, baseColor.a);
}