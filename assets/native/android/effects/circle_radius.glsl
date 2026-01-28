#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity;

out vec4 fragColor;

void main() {
    vec2 pos = FlutterFragCoord().xy;
    vec2 uv = pos / uResolution;

    // 1. Orijinal resmi al
    vec3 base = texture(uTexture, uv).rgb;

    // 2. Izgara (Grid) boyutunu ayarla
    // 57.0 nokta sıklığıdır. Sayı artarsa noktalar küçülür.
    float density = 57.0;
    float aspect = uResolution.x / uResolution.y;
    vec2 size = vec2(density * aspect, density);

    // 3. Koordinatları hazırla
    vec2 gd = floor(uv * size) / size;       // Kare merkezi
    vec2 st = fract(uv * size) - 0.5;        // Kare içi koordinat

    // 4. Nokta içindeki rengi oku
    // gd koordinatına yarım piksel ofset eklemek (0.5/size) titremeyi azaltabilir ama
    // performans için düz bırakıyoruz.
    vec3 texCol = texture(uTexture, gd).rgb;

    // OPTIMIZASYON: Parlaklık hesabı (Dot product çok daha hızlıdır)
    float brightness = dot(texCol, vec3(0.33333));

    // 5. Daireyi çiz
    // Nokta büyüklüğü parlaklığa göre değişir
    float radius = brightness * 0.5;
    float dist = length(st);

    // Siyah-Beyaz nokta maskesi
    float dots = smoothstep(0.01, -0.01, dist - radius);

    // 6. Karıştırma
    // Noktalar genelde siyahtır ama burada beyaz nokta çiziyor (effect).
    // Eğer siyah nokta istersen dots yerine (1.0 - dots) kullanabilirsin.
    vec3 finalColor = mix(base, vec3(dots), clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(finalColor, 1.0);
}