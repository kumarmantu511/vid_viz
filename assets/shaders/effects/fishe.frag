#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// Sabitler
const float SPEED = 1.2;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 normUV = fragCoord / uResolution;

    // 1. ERKEN ÇIKIŞ (Performans)
    if (uIntensity < 0.001) {
        fragColor = vec4(texture(uTexture, normUV).rgb, 1.0);
        return;
    }

    // 2. ASPECT RATIO DÜZELTMESİ (Yumurta şeklini önler)
    // Koordinatları merkeze al (-0.5 .. 0.5)
    vec2 uv = normUV - 0.5;

    // Ekranın en-boy oranını hesapla
    float aspect = uResolution.x / uResolution.y;

    // X eksenini genişlet (Kare uzayına geç)
    uv.x *= aspect;

    // 3. EFEKT GÜCÜ (Ghosting Çözümü)
    // Orijinal kodda 'mix' kullanılıyordu, bu yanlıştı.
    // Burada 'fishyness' değerini direkt intensity ile kontrol ediyoruz.
    // Böylece resim bulanıklaşmaz, fiziksel olarak bükülür (Morphing).

    // İsteğe bağlı: Hafif bir "nefes alma" efekti için cos(t) eklenebilir,
    // ama profesyonel araçlarda genelde sabit kontrol istenir.
    // Orijinal koddaki "kalp atışı" efektini intensity ile çarparak korudum:
    float t = uTime * SPEED;
    float pulse = 0.1 + 0.1 * cos(t);

    // Intensity arttıkça bükülme artar.
    // (0.5 + pulse) kısmı efektin karakteristiğidir.
    float fishyness = (0.4 + pulse) * uIntensity;

    // 4. FISHEYE MATEMATİĞİ
    // Orijinal koddaki formülü koruduk ama Aspect Ratio düzeltmesiyle uyguluyoruz.
    vec2 fishuv;
    fishuv.x = (1.0 - uv.y * uv.y) * fishyness * uv.x;
    fishuv.y = (1.0 - uv.x * uv.x) * fishyness * uv.y;

    // 5. CHROMATIC ABERRATION (Renk Sapması)
    // Bükülme vektörünü (fishuv) kullanarak renkleri ayrıştırıyoruz.

    // Aspect Ratio'yu geri alarak örnekleme yapacağız
    vec2 pos = uv;

    // Kırmızı kanal (Biraz daha az bükülür)
    vec2 uvR = pos - fishuv * 0.92;
    uvR.x /= aspect; // Normale dön
    uvR += 0.5;

    // Yeşil ve Mavi kanal (Tam bükülür)
    vec2 uvGB = pos - fishuv;
    uvGB.x /= aspect; // Normale dön
    uvGB += 0.5;

    // Texture Okuma (Base color okumaya gerek yok, direkt kanalları okuyoruz)
    float cr = texture(uTexture, uvR).r;
    vec2 cgb = texture(uTexture, uvGB).gb;
    vec3 color = vec3(cr, cgb);

    // 6. VIGNETTE (Köşe Karartma)
    // aspect düzeltmesi yapılmış 'uv' kullanıyoruz, böylece vignette de tam daire olur.
    float uvMagSqrd = dot(uv, uv);
    // Intensity'ye bağlı olarak vignette artar
    float vignette = 1.0 - uvMagSqrd * fishyness * 2.0;

    color *= clamp(vignette, 0.0, 1.0);

    // 7. KENAR TEMİZLİĞİ
    // Bükülme sırasında ekran dışına taşan pikselleri temizle
    // (İsteğe bağlı, siyah kenar istemezseniz silebilirsiniz)
    if (uvGB.x < 0.0 || uvGB.x > 1.0 || uvGB.y < 0.0 || uvGB.y > 1.0) {
        color = vec3(0.0);
    }

    fragColor = vec4(color, 1.0);
}