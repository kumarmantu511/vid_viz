#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// Sabitler
const float PI = 3.14159265359;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution.xy;

    // 1. ERKEN ÇIKIŞ (Performans İçin Kritik)
    // Efekt kapalıysa ağır matematik işlemleri yapma, direkt resmi bas.
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // 2. ASPECT RATIO (En-Boy) Düzeltmesi (Kaymayı Önlüyor)
    // Ekranın ortasını (0.5, 0.5) referans alıyoruz.
    vec2 centered = uv - 0.5;

    // Ekranın en-boy oranını hesapla
    float aspect = uResolution.x / uResolution.y;

    // X eksenini orana göre düzelt (Kare uzayına geç)
    centered.x *= aspect;

    // 3. BARREL DISTORTION (Bükülme)
    // Merkeze olan mesafenin karesi
    float r2 = dot(centered, centered);

    // Bükülme miktarı (Intensity ile kontrol edilir)
    float distAmount = 0.2 * uIntensity;

    // Koordinatları bük (Sadece intensity varken çalışır)
    // (1.0 + ...) formülü balık gözü efekti verir.
    vec2 distorted = centered * (1.0 + distAmount * r2);

    // Aspect Ratio düzeltmesini geri al (Dikdörtgen uzayına dön)
    distorted.x /= aspect;

    // UV koordinatlarını tekrar 0..1 aralığına çek
    vec2 uvd = distorted + 0.5;

    // 4. KENAR KONTROLÜ (Hard Border)
    // Görüntü dışına taşan yerleri sündürmek yerine siyah yap (TV Çerçevesi)
    // step fonksiyonu if'ten daha hızlıdır.
    float inBounds = step(0.0, uvd.x) * step(uvd.x, 1.0) * step(0.0, uvd.y) * step(uvd.y, 1.0);

    // 5. SCANLINES & MASK (Çizgiler)
    // Intensity'ye göre görünürlüğü ayarla
    float scanLineIntensity = 0.15 * uIntensity; // Çizgi gücü

    // Scanlines (Yatay)
    float scan = 1.0 - scanLineIntensity * (1.0 + cos(uvd.y * uResolution.y * PI));

    // Shadow Mask (Dikey - RGB maskesi gibi)
    float mask = 1.0 - scanLineIntensity * (1.0 + sin(uvd.x * uResolution.x * PI * 0.5));

    // 6. VIGNETTE (Köşe Karartma)
    // Yeni koordinatlara göre mesafe
    float distVig = dot(distorted, distorted); // Zaten centered hesaplamıştık
    // Intensity arttıkça köşeler daha çok kararır
    float vignette = smoothstep(0.6, 0.2, distVig * uIntensity * 1.5);

    // 7. RENK OKUMA VE BİRLEŞTİRME
    // Tek bir okuma yapıyoruz (Eski kodda 2 taneydi)
    vec3 color = texture(uTexture, uvd).rgb;

    // Efektleri uygula
    color *= scan * mask;     // Çizgiler
    color *= vignette;        // Köşe kararması
    color *= inBounds;        // Siyah çerçeve (Dışarı taşanları sil)

    // Eğer inBounds 0 ise (siyah kenar), texture rengi siyah olur.
    // Ancak mix ile yumuşak geçiş yapmak istersen (intensity düşükken):
    // Orijinal resimle bozulmuş resim arasında 'intensity' kadar geçiş yapmıyoruz,
    // çünkü yukarıda UV'leri zaten intensity ile bükerek 'morph' yaptık.
    // Bu yüzden ekstra bir mix'e gerek yok, bu matematiksel olarak daha doğrudur.

    fragColor = vec4(color, 1.0);
}