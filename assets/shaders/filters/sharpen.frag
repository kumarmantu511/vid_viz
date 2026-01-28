#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    // 1. ERKEN ÇIKIŞ (Performans)
    // Efekt kapalıysa 5 texture okuması yapma, sadece 1 tane yapıp çık.
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    vec2 texel = 1.0 / uResolution.xy;

    // Merkez piksel
    vec3 c = texture(uTexture, uv).rgb;

    // Komşular (Sol, Sağ, Üst, Alt)
    vec3 l = texture(uTexture, uv - vec2(texel.x, 0.0)).rgb;
    vec3 r = texture(uTexture, uv + vec2(texel.x, 0.0)).rgb;
    vec3 t = texture(uTexture, uv - vec2(0.0, texel.y)).rgb;
    vec3 b = texture(uTexture, uv + vec2(0.0, texel.y)).rgb;

    // 2. LAPLACIAN (Kenar Bulma) MANTIĞI
    // Keskinleştirme formülü: Merkez - Komşuların Ortalaması = Detay
    // 4.0 * c - (l + r + t + b) -> Bu bize sadece "kenarları/detayları" verir.
    vec3 detail = (4.0 * c) - (l + r + t + b);

    // 3. EFEKTİ UYGULA
    // Orijinal resme detayları ekliyoruz.
    // 'mix' kullanmıyoruz çünkü keskinleştirme toplamsal (additive) bir işlemdir.
    // uIntensity direkt gücü belirler.
    vec3 finalColor = c + detail * uIntensity;

    fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}