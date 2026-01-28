#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// Sabitleri const olarak tutmak iyidir
const float speed = 0.2;
const float frequency = 8.0;

// Shift fonksiyonunu kaldırdık ve main içine gömdük (inlining)
// Bu sayede ortak hesaplamaları tekrar etmeyeceğiz.

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 r = fragCoord / uResolution.xy; // 0..1

    // OPTİMİZASYON 1: Eğer efekt görünmüyorsa işlem yapma (Pil Tasarrufu)
    if (uIntensity <= 0.001) {
        fragColor = vec4(texture(uTexture, r).rgb, 1.0);
        return;
    }

    // Ortak zaman ve frekans hesabı (Tek sefer yapılır)
    float timeVal = uTime * speed;

    // f1: shift(r) için hesap
    vec2 f1 = frequency * (r + timeVal);

    // f2: shift(r + 1.0) için hesap.
    // Tekrar çarpma yapmak yerine f1'e frequency ekliyoruz.
    // Çünkü: frequency * (r + 1.0 + time) = frequency * (r + time) + frequency
    vec2 f2 = f1 + vec2(frequency);

    // P Vektörü Hesabı (Orijinal Matematik)
    vec2 p = cos(vec2(
    cos(f1.x - f1.y) * cos(f1.y),
    sin(f1.x + f1.y) * sin(f1.y)
    ));

    // Q Vektörü Hesabı (Orijinal Matematik)
    vec2 q = cos(vec2(
    cos(f2.x - f2.y) * cos(f2.y),
    sin(f2.x + f2.y) * sin(f2.y)
    ));

    // Koordinat bozulma hesabı
    float amplitude = 2.0 / uResolution.x;
    vec2 s = r + amplitude * (p - q);

    // Kenar taşmalarını engelle
    s = clamp(s, 0.0, 1.0);

    // Texture okumaları
    vec3 base = texture(uTexture, r).rgb;
    vec3 warped = texture(uTexture, s).rgb;

    // Karıştırma
    vec3 finalColor = mix(base, warped, clamp(uIntensity, 0.0, 1.0));
    fragColor = vec4(finalColor, 1.0);
}