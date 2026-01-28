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

    vec3 base = texture(uTexture, uv).rgb;

    // 2. MANTIK DÜZELTMESİ (Ters Orantı)
    // Orijinal kodda intensity artınca levels artıyordu (efekt kayboluyordu).
    // Doğrusu: Intensity artınca levels DÜŞMELİ (efekt güçlenmeli).

    // Intensity 0.0 -> 255.0 Level (Orijinal görüntü)
    // Intensity 1.0 -> 2.0 Level (Güçlü Retro/Comic efekti)
    float levels = mix(255.0, 2.0, uIntensity);

    // 3. POSTERIZATION MATEMATİĞİ
    // Formül: floor(renk * seviye) / seviye
    vec3 effect = floor(base * levels) / levels;

    // 4. MIX YOK
    // Posterizasyon efekti "yavaşça beliren" bir şey değildir.
    // Seviye sayısı değiştikçe efekt zaten yumuşakça değişir.
    // O yüzden 'mix(base, effect)' yapıp hayalet görüntü oluşturmuyoruz.

    fragColor = vec4(effect, 1.0);
}