#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// Luma katsayıları (Parlaklık hesabı için)
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    // 1. OPTİMİZASYON: Erken Çıkış
    // Efekt kapalıysa ağır blur işlemini yapma
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    vec2 texel = 1.0 / uResolution.xy;

    // Merkez pikseli oku (Bunu blur hesabında tekrar kullanacağız)
    vec3 base = texture(uTexture, uv).rgb;

    // 2. OPTİMİZASYON: Blur Hesabı
    // Merkez pikseli tekrar okumuyoruz, 'base' değişkenini kullanıyoruz.
    // Gaussian Kernel (3x3): Merkez ağırlıklı

    vec3 blur = base * 0.25; // Merkez (%25 ağırlık)

    // Komşular
    blur += texture(uTexture, uv + texel * vec2(-1.0, -1.0)).rgb * 0.0625;
    blur += texture(uTexture, uv + texel * vec2( 0.0, -1.0)).rgb * 0.1250;
    blur += texture(uTexture, uv + texel * vec2( 1.0, -1.0)).rgb * 0.0625;
    blur += texture(uTexture, uv + texel * vec2(-1.0,  0.0)).rgb * 0.1250;
    // Merkez buradaydı, kaldırdık.
    blur += texture(uTexture, uv + texel * vec2( 1.0,  0.0)).rgb * 0.1250;
    blur += texture(uTexture, uv + texel * vec2(-1.0,  1.0)).rgb * 0.0625;
    blur += texture(uTexture, uv + texel * vec2( 0.0,  1.0)).rgb * 0.1250;
    blur += texture(uTexture, uv + texel * vec2( 1.0,  1.0)).rgb * 0.0625;

    // 3. KESKİNLEŞTİRME (Unsharp Mask Logic)
    // Orijinal - Blur = Detaylar (High Pass)
    vec3 detail = base - blur;

    // Halo (Hale) Azaltma
    // Çok parlak kenarların "parlamasını" engellemek için detayı biraz bastırıyoruz.
    float lumaDetail = dot(detail, LUMA);

    // Detay çok yüksekse (çok beyaz veya çok siyah), biraz yumuşat.
    // Bu, profesyonel sharpening filtrelerinde "Threshold" ayarı gibidir.
    float mask = 1.0 - smoothstep(0.1, 0.5, abs(lumaDetail));

    // 4. SONUÇ
    // Efekti tek seferde uyguluyoruz.
    // Strength katsayısı (2.0 ile çarparak daha belirgin hale getirdik)
    float strength = uIntensity * 2.0;

    // Detayı ana resme ekle (Sharpening budur)
    // base + (detail * strength)
    vec3 sharp = base + detail * strength;

    // Kontrast artırma (İsteğe bağlı, hafifçe eklendi)
    // Keskinleşen resim bazen soluklaşabilir, bunu engeller.
    if (uIntensity > 0.5) {
        sharp = mix(sharp, sharp * sharp * (3.0 - 2.0 * sharp), 0.1 * uIntensity);
    }

    // Renkleri 0..1 aralığında tut
    fragColor = vec4(clamp(sharp, 0.0, 1.0), 1.0);
}