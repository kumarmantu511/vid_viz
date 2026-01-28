#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    // 1. ERKEN ÇIKIŞ (Performans)
    // Eğer efekt çok azsa (neredeyse 0), matematik yapma, orijinali bas geç.
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // 2. PİKSEL BOYUTU HESABI
    // 1.0 (Orijinal) ile 40.0 (Büyük bloklar) arasında geçiş.
    // 40.0 değerini artırarak blokları daha da büyütebilirsin.
    float px = 1.0 + 40.0 * uIntensity;

    // 3. KOORDİNAT MATEMATİĞİ (GRID SNAP)
    // UV uzayında bloklama yapıyoruz.
    // Önce UV'yi blok sayısına (dims) göre ölçekle, tam sayıya yuvarla (floor), sonra geri böl.
    vec2 dims = uResolution / px;
    vec2 uvPixelated = floor(uv * dims) / dims;

    // Örneklemeyi bloğun tam ortasından yap (Yarım piksel kaydır)
    // Bu, kenarlardaki titremeyi ve yanlış renk okumayı engeller.
    uvPixelated += (0.5 / dims);

    // 4. TEK SEFERDE OKUMA
    // 'base' ve 'mix' yok. Direkt hesaplanan koordinatı okuyoruz.
    // Bu sayede görüntü "bulanıklaşmaz", piksel blokları net bir şekilde büyür.
    vec3 finalColor = texture(uTexture, uvPixelated).rgb;

    fragColor = vec4(finalColor, 1.0);
}