#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity;      // 0.0 - 1.0

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // 1. ERKEN ÇIKIŞ (Performans)
    // Intensity 0 ise hiç matematik yapma, resmi bas geç.
    if (uIntensity < 0.001) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // 2. ASPECT RATIO DÜZELTMESİ (Doğru Daire)
    // Orijinal kodda ikisiyle de çarpılıyordu, bu yanlıştı.
    // Sadece X eksenini çarparak dikdörtgen ekranlarda ovalleşmeyi önlüyoruz.
    vec2 coord = uv - 0.5;
    coord.x *= (uResolution.x / uResolution.y);

    // Sabit ölçekleme (Orijinal koddaki * 2.0 mantığı)
    coord *= 4.0;

    // 3. MATEMATİK OPTİMİZASYONU (Sqrt Yok)
    // Orijinal: rf = sqrt(dot) * Falloff; ... rf*rf ...
    // Yeni: rf2 = dot * Falloff * Falloff;
    // Karekök alıp tekrar karesini almak yerine direkt karelerle çalışıyoruz.

    float Falloff = 0.25;
    float distSq = dot(coord, coord); // Uzaklığın karesi
    float rfSq = distSq * (Falloff * Falloff); // Falloff karesiyle çarpım

    float rf2_1 = rfSq + 1.0;

    // Vignette Maskesi (0.0 = Karanlık, 1.0 = Aydınlık)
    // Formül: 1 / (r^2 + 1)^2
    float mask = 1.0 / (rf2_1 * rf2_1);

    // 4. MIX MANTIĞI
    // Renkleri karıştırmak yerine, Maske değerini karıştırıyoruz.
    // mix(1.0, mask, uIntensity) -> Efekt yoksa 1.0 (etkisiz), varsa maske değeri.
    float finalMask = mix(1.0, mask, uIntensity);

    // Tek doku okuması ve tek çarpma işlemi
    vec3 texColor = texture(uTexture, uv).rgb;
    fragColor = vec4(texColor * finalMask, 1.0);
}