#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// Luma katsayıları (İnsan gözünün algısına uygun gri tonlama)
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    // 1. OPTİMİZASYON: Erken Çıkış
    // Eğer efekt görünmeyecek kadar azsa veya kapalıysa,
    // 8-9 kez texture okumaya gerek yok. Direkt resmi ver.
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    vec2 texel = 1.0 / uResolution.xy;

    // Komşu pikselleri oku ve anında griye çevir (Dot Product)
    // Not: Merkez pikseli (c) okumuyoruz çünkü Sobel formülünde merkez 0 ile çarpılır.

    // Üst Satır
    float tl = dot(texture(uTexture, uv + texel * vec2(-1.0, -1.0)).rgb, LUMA);
    float t  = dot(texture(uTexture, uv + texel * vec2( 0.0, -1.0)).rgb, LUMA);
    float tr = dot(texture(uTexture, uv + texel * vec2( 1.0, -1.0)).rgb, LUMA);

    // Orta Satır (Sadece sol ve sağ)
    float l  = dot(texture(uTexture, uv + texel * vec2(-1.0,  0.0)).rgb, LUMA);
    float r  = dot(texture(uTexture, uv + texel * vec2( 1.0,  0.0)).rgb, LUMA);

    // Alt Satır
    float bl = dot(texture(uTexture, uv + texel * vec2(-1.0,  1.0)).rgb, LUMA);
    float b  = dot(texture(uTexture, uv + texel * vec2( 0.0,  1.0)).rgb, LUMA);
    float br = dot(texture(uTexture, uv + texel * vec2( 1.0,  1.0)).rgb, LUMA);

    // 2. OPTİMİZASYON: Matematiksel Sadeleştirme
    // Sobel Kernels:
    // Gx = [ -1  0  1 ]
    //      [ -2  0  2 ]
    //      [ -1  0  1 ]
    //
    // Gy = [ -1 -2 -1 ]
    //      [  0  0  0 ]
    //      [  1  2  1 ]

    // Gx Hesabı (Dikey çizgileri bulur)
    // (Sağ taraf - Sol taraf)
    float Gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);

    // Gy Hesabı (Yatay çizgileri bulur)
    // (Alt taraf - Üst taraf)
    float Gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);

    // Kenar şiddetini hesapla (Magnitude)
    // edge değerini biraz daha keskinleştirmek için çarpabilirsin (örn: length(...) * 1.5)
    float edge = length(vec2(Gx, Gy));

    // Kenarı görünür aralığa sıkıştır
    edge = clamp(edge, 0.0, 1.0);

    // Orijinal rengi (base) şimdi okuyoruz
    vec3 base = texture(uTexture, uv).rgb;

    // Kenarları beyaz olarak göster (Siyah arka plan istersen vec3(edge) kullan)
    // Profesyonel görünüm için genelde orijinal resmin üstüne bindirilir.
    // Burada orijinal koddaki gibi "mix" mantığını koruduk.
    vec3 edgeColor = vec3(edge);

    vec3 finalColor = mix(base, edgeColor, clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(finalColor, 1.0);
}