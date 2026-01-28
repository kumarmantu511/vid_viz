#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    // 1. ERKEN ÇIKIŞ
    // Efekt kapalıysa işlem yapma
    if (uIntensity < 0.01) {
        fragColor = vec4(texture(uTexture, uv).rgb, 1.0);
        return;
    }

    // 2. MERKEZLEME VE ASPECT RATIO
    // Ekranın ortasını (0,0) alıyoruz.
    vec2 p = uv - 0.5;

    // Aspect ratio düzeltmesi (Dairenin oval olmaması için)
    float aspect = uResolution.x / uResolution.y;
    p.x *= aspect;

    // 3. BURGU (SWIRL) MATEMATİĞİ
    float r = length(p);

    // Efektin gücü (Açı)
    // Intensity arttıkça açı artar.
    // 3.14159 * 2.0 diyerek daha güçlü bir burgu yapabilirsin.
    float maxAngle = 3.14159 * 1.5 * uIntensity;

    // Yarıçap maskesi: Merkezde en güçlü, kenarda (0.5) sıfır etki.
    // 1.0 - smoothstep(...) kullanarak yumuşak bir geçiş sağlıyoruz.
    // r * 2.0 diyerek etkiyi ekranın ortasına odaklıyoruz.
    float strength = 1.0 - smoothstep(0.0, 1.0, r * 2.0);

    // Dönüş açısı
    float angle = strength * maxAngle;

    // 4. ROTASYON (Matris yerine direkt sin/cos)
    float s = sin(angle);
    float c = cos(angle);

    // Vektör döndürme formülü:
    // x' = x*cos - y*sin
    // y' = x*sin + y*cos
    vec2 pr = vec2(p.x * c - p.y * s, p.x * s + p.y * c);

    // 5. NORMALE DÖNÜŞ
    pr.x /= aspect; // Aspect ratio geri al
    vec2 finalUV = pr + 0.5;

    // 6. KENAR KONTROLÜ
    // Eğer burgu çok güçlüyse ve kenardan siyah çekiyorsa clamp yerine
    // siyah veya şeffaf basmak daha iyidir. Ama şimdilik clamp tutalım.
    // Sündürmeyi engellemek istersen 'if' kullanabilirsin.
    bool inBounds = (finalUV.x >= 0.0 && finalUV.x <= 1.0 && finalUV.y >= 0.0 && finalUV.y <= 1.0);

    vec3 color;
    if (inBounds) {
        color = texture(uTexture, finalUV).rgb;
    } else {
        color = vec3(0.0); // Dışarı taşan kısımlar siyah olsun (Sündürme yapmaz)
    }

    fragColor = vec4(color, 1.0);
}