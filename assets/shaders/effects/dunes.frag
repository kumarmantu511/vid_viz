#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;
uniform float uIntensity;

out vec4 fragColor;

void main() {
    // 1. Koordinatları al
    vec2 pos = FlutterFragCoord().xy;
    vec2 uv = pos / uResolution;

    // 2. Texture'ı SADECE BIR KEZ oku (Çift okuma engellendi, %50 texture performans artışı)
    vec4 tex = texture(uTexture, uv);

    // 3. Efekt (Posterization) Hesabı
    // Orijinal koddaki shift değişkeni 'ölü koddu' (kullanılmıyordu), sildik.
    float sh = 4.0;
    float di = 0.5;

    // Renk derinliğini azaltma işlemi (Birebir aynı formül)
    vec3 effectColor = floor(tex.rgb * sh + di) / sh;

    // 4. Kenar maskesi (Sol ve alt 1 pikseli siyaha boyayan orijinal mantık)
    effectColor *= clamp(min(pos.x, pos.y) - 1.0, 0.0, 1.0);

    // 5. Karıştırma (Mix)
    vec3 finalColor = mix(tex.rgb, effectColor, clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(finalColor, 1.0);
}