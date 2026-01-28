#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// Rastgele sayı üreteci (Banding/Çizgilenmeyi yok eder)
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    // 1. ERKEN ÇIKIŞ (Performans)
    // Efekt kapalıysa döngüye girme.
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // Zoom Merkezi (Ekran ortası)
    vec2 center = vec2(0.5, 0.5);

    // Yön Vektörü (Pikselden merkeze doğru)
    // Bu vektörü normalize etmiyoruz çünkü merkeze uzak olan pikseller
    // daha hızlı hareket etmeli (Zoom mantığı).
    vec2 toCenter = center - uv;

    // Rastgelelik (Jitter)
    // Her piksel için döngü başlangıcını hafifçe kaydırıyoruz.
    // Bu, 20 örneklemeyle oluşan çizgileri (banding) tamamen yok eder.
    float offset = random(uv);

    const int SAMPLES = 24; // Biraz artırdık, mobil için güvenli.
    vec3 acc = vec3(0.0);
    float totalWeight = 0.0;

    // Zoom Gücü
    // Intensity arttıkça mesafe uzar.
    float strength = uIntensity * 0.3;

    for (float t = 0.0; t <= float(SAMPLES); t++) {
        // İlerleme oranı (0.0 ile 1.0 arası)
        // 'offset' ekleyerek örneklemeyi karıştırıyoruz (Dithering)
        float percent = (t + offset) / float(SAMPLES);

        // Ağırlık Fonksiyonu
        // Merkeze yakın (orijinal piksel) örnekler daha ağırlıklı,
        // uzaktakiler daha silik. Bu "iz bırakma" efekti verir.
        float weight = 4.0 * (1.0 - percent);

        // Örnekleme Koordinatı
        // Orijinal konumdan merkeze doğru adım adım gidiyoruz.
        vec2 sampleUV = uv + toCenter * percent * strength;

        // Kenar Koruması
        sampleUV = clamp(sampleUV, 0.0, 1.0);

        acc += texture(uTexture, sampleUV).rgb * weight;
        totalWeight += weight;
    }

    // Sonuç
    vec3 finalColor = acc / totalWeight;

    // Ekstra mix yapmıyoruz.
    // Intensity zaten döngü içindeki 'strength' (mesafe) ile kontrol edildi.
    // Bu sayede görüntü bulanıklaşmaz, gerçek bir hareket (motion) hissi verir.

    fragColor = vec4(finalColor, 1.0);
}