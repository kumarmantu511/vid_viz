#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution.xy;

    // 1. OPTİMİZASYON: Erken Çıkış
    // Efekt kapalıysa matematik yapma.
    if (uIntensity < 0.001) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // 2. ASPECT RATIO DÜZELTMESİ (Kayma Sorununu Çözer)
    // Ekranın ortasını (0,0) noktası kabul et
    vec2 p = uv - 0.5;

    // Ekranın en-boy oranını hesapla
    float aspect = uResolution.x / uResolution.y;

    // X eksenini orana göre genişlet (Kare uzayına geç)
    // Bu işlem yapılmazsa daireler yumurta gibi görünür.
    p.x *= aspect;

    // Merkeze olan mesafenin karesi
    float r2 = dot(p, p);

    // Efekt Gücü
    float k = 1.0 * uIntensity;

    // Barrel Distortion Formülü (Merceği Bükme)
    // (1.0 + k * r2) -> Klasik balık gözü formülü
    vec2 pd = p * (1.0 + k * r2);

    // Aspect Ratio düzeltmesini geri al (Normale dön)
    pd.x /= aspect;

    // Koordinatları tekrar 0..1 aralığına çek
    vec2 uvd = pd + 0.5;

    // 3. KENAR KONTROLÜ
    // Bükülme sonucu resmin dışına taşan koordinatları siyah yap (Lens etkisi)
    // Bunu yapmazsan kenarlardaki pikseller "sürüklenmiş" (clamp) gibi görünür.
    bool inBounds = (uvd.x >= 0.0 && uvd.x <= 1.0 && uvd.y >= 0.0 && uvd.y <= 1.0);

    vec3 color;

    if (inBounds) {
        color = texture(uTexture, uvd).rgb;
    } else {
        color = vec3(0.0); // Siyah çerçeve
    }

    // Mix işlemine gerek yok, çünkü UV koordinatlarını intensity'ye göre bükerek
    // zaten "morph" işlemi yaptık. Direkt sonucu basıyoruz.
    fragColor = vec4(color, 1.0);
}