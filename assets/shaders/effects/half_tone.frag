#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);
const float SCALE = 80.0; // Nokta sıklığı (Daha düşük = Daha büyük noktalar)

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // 1. ERKEN ÇIKIŞ
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // Ekran En-Boy Oranı
    float aspect = uResolution.x / uResolution.y;

    // 2. GRID KOORDİNATLARI (Aspect Ratio Düzeltmeli)
    vec2 st = uv;
    st.x *= aspect; // X eksenini genişlet (Daireler yuvarlak olsun)
    st *= SCALE;

    // 3. KAYDIRMA (Staggered Grid)
    // Her satırı yarım birim kaydır (Klasik gazete görünümü)
    // 0.5 ekleyerek kaydırma yapıyoruz.
    st.x += step(1.0, mod(st.y, 2.0)) * 0.5;

    // 4. HÜCRE MERKEZİ BULMA (Center Sampling)
    // Burası çok önemli! Parlaklığı pikselden değil, noktanın merkezinden okuyacağız.
    vec2 cellIndex = floor(st);
    vec2 cellCenter = (cellIndex + 0.5) / SCALE; // Normale dön

    // Aspect ratio düzeltmesini geri alarak texture koordinatını bul
    cellCenter.x /= aspect;
    // Kaydırma (stagger) etkisini texture koordinatında düzeltmeye gerek yok,
    // çünkü grid zaten kaydırıldı, merkez doğru yerde.

    // Texture'u HÜCRE MERKEZİNDEN oku
    vec3 centerColor = texture(uTexture, cellCenter).rgb;
    float luminance = dot(centerColor, LUMA);

    // 5. NOKTA ÇİZİMİ
    // Hücre içindeki koordinat (-0.5 ile 0.5 arası)
    vec2 cellUV = fract(st) - 0.5;
    float dist = length(cellUV);

    // Nokta Yarıçapı
    // Parlaklık arttıkça nokta küçülür (Siyah nokta mantığı)
    // sqrt kullanıyoruz çünkü alan yarıçapın karesiyle orantılıdır.
    // sqrt kullanmazsak orta tonlar çok koyu görünür.
    float radius = sqrt(1.0 - luminance) * 0.5;

    // Antialiasing (Kenar yumuşatma)
    // intensity ile karışımı burada maskeye uyguluyoruz
    float mask = smoothstep(radius, radius - 0.1, dist);

    // 6. RENK OLUŞTURMA
    // Halftone (Siyah Nokta, Beyaz Zemin)
    vec3 halftone = mix(vec3(1.0), vec3(0.0), mask);

    // Eğer renkli halftone (CMYK tarzı) istersen:
    // vec3 halftone = mix(vec3(1.0), centerColor, mask); yapabilirsin.

    // Orijinal resimle karıştır
    vec3 base = texture(uTexture, uv).rgb;
    vec3 finalColor = mix(base, halftone, clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(finalColor, 1.0);
}