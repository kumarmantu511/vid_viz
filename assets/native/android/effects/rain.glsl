#version 300 es
precision highp float;
// ============================================================================
// RAIN GLASS - ULTIMATE MOBILE EDITION (Single Pass + Fake Blur)
// ============================================================================

uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;

uniform float uIntensity;   // 0.0 - 1.0
uniform float uSpeed;       // 0.5 - 2.0
uniform float uDropSize;    // 0.5 - 2.0
uniform float uDensity;     // 0.0 - 1.0

out vec4 fragColor;

// --- RASTGELELIK ---
vec3 N13(float p) {
    vec3 p3 = fract(vec3(p) * vec3(.1031, .11369, .13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float N(float t) {
    return fract(sin(t * 12345.564) * 7658.76);
}

// --- ANA DAMLA (TEK GECISTE NORMAL VE MASKE) ---
// Return: xy=Normal, z=Maske, w=Iz
vec4 Drops(vec2 uv, float t, float dSize, float density) {
    vec2 UV = uv;
    uv.y = -uv.y;
    uv.y += t * 0.8;

    vec2 a = vec2(6., 1.);
    vec2 grid = a * 2.;

    // Offset eklendi (Cizgi hatasi icin)
    vec2 gridUV = uv + vec2(1000.0, 1000.0);
    vec2 id = floor(gridUV * grid);

    // Density Kontrolü (Erken Cikis)
    float check = N(id.x * 35.2 + id.y * 2376.1);
    if (check > density) return vec4(0.0);

    vec3 n = N13(id.x * 35.2 + id.y * 2376.1);
    uv.y += N(id.x);

    vec2 st = fract(gridUV * grid) - vec2(.5, 0);

    float x = n.x - .5;
    float y = UV.y * 20.;
    float distort = sin(y + sin(y));
    x += distort * (.5 - abs(x)) * (n.z - .5);
    x *= .7;
    x = clamp(x, -0.35, 0.35);

    float ti = fract(t + n.z);
    y = (smoothstep(0., .85, ti) * smoothstep(1., .85, ti) - .5) * .9 + .5;
    vec2 p = vec2(x, y);

    // --- NORMAL HESABI (OPTIMIZASYON) ---
    // 3 kere cagirmak yerine matematiksel vektor farkini aliyoruz
    vec2 dropVec = (st - p) * a.yx;
    float d = length(dropVec);

    float currentDropSize = 0.2 * dSize;
    float Drop = smoothstep(currentDropSize, .0, d);

    float r = sqrt(smoothstep(1., y, st.y));
    float cd = abs(st.x - x);

    float trail = smoothstep((currentDropSize * .5 + .03) * r, (currentDropSize * .5 - .05) * r, cd);
    float trailFront = smoothstep(-.02, .02, st.y - y);
    trail *= trailFront;

    y = UV.y;
    y += N(id.x);
    float trail2 = smoothstep(currentDropSize * r, .0, cd);
    float droplets = max(0., (sin(y * (1. - y) * 120.) - st.y)) * trail2 * trailFront * n.z;
    y = fract(y * 10.) + (st.y - .5);

    vec2 dropletVec = st - vec2(x, y);
    float dd = length(dropletVec);
    float dropletMask = smoothstep(currentDropSize * N(id.x), 0., dd);
    droplets = dropletMask;

    float m = Drop + droplets * r * trailFront;
    float borderMask = smoothstep(0.5, 0.35, abs(st.x));

    // Normalleri ve maskeyi paketle
    vec2 finalNormal = (dropVec * Drop + dropletVec * droplets) * borderMask;

    return vec4(finalNormal, m * borderMask, trail * borderMask);
}

// STATIK DAMLALAR (Return: xy=Normal, z=Maske)
vec3 StaticDrops(vec2 uv, float t, float dSize) {
    uv *= 30.;
    vec2 gridUV = uv + vec2(1000.0, 1000.0);
    vec2 id = floor(gridUV);
    uv = fract(gridUV) - .5;

    vec3 n = N13(id.x * 107.45 + id.y * 3543.654);
    vec2 p = (n.xy - .5) * 0.5;

    vec2 diff = uv - p; // Normal Vektoru
    float d = length(diff);

    float fade = smoothstep(0., .025, fract(t + n.z)) * smoothstep(1., .025, fract(t + n.z));
    float c = smoothstep(dSize * 0.2, 0., d) * fract(n.z * 10.) * fade;

    return vec3(diff * c, c);
}

// TEK GECISLI YAGMUR FONKSIYONU
vec4 Rain(vec2 uv, float t, float dSize, float density) {
    vec3 s = StaticDrops(uv, t, dSize);
    vec4 r1 = Drops(uv, t, dSize, density);
    vec4 r2 = Drops(uv * 1.8, t, dSize, density); // Katman 2

    // Normalleri topla
    vec2 normal = s.xy + r1.xy + r2.xy;

    // Maskeleri topla
    float c = s.z + r1.z + r2.z;
    c = smoothstep(.3, 1., c);

    return vec4(normal, c, max(r1.w, r2.w));
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = (fragCoord - .5 * uResolution.xy) / uResolution.y;
    vec2 UV = fragCoord / uResolution.xy;

    vec4 baseColor = texture(uTexture, UV);
    // Alpha kontrolu
    if (baseColor.a < 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    float T = uTime * clamp(uSpeed, 0.2, 3.0);
    float t = T * .2;
    float dSize = clamp(uDropSize, 0.5, 2.0);
    float density = clamp(uDensity, 0.1, 1.0);

    UV = (UV - .5) * .98 + .5;

    // --- TEK SEFERDE TUM VERIYI AL (OPTIMIZASYON) ---
    // Artik Rain fonksiyonunu 3 kere cagirmiyoruz!
    vec4 data = Rain(uv, t, dSize, density);

    vec2 n = data.xy;   // Normal (Kırılma Vektörü)
    float mask = data.z; // Damla Maskesi
    float trail = data.w; // İz Maskesi

    // --- FAKE BLUR & RENK ---
    // Normal buğulu cam (Blur yerine hafif grileşmiş/beyazlaşmış görüntü)
    vec3 foggyBg = mix(baseColor.rgb, vec3(0.95), 0.2);

    // Damlanın içi (Net görüntü + Kırılma)
    // Normal vektörü (n) ile UV'yi kaydırıyoruz
    vec3 clearDrop = texture(uTexture, UV + n * 2.0).rgb; // n * 2.0 kırılma gücüdür

    // Karıştırma
    // Damla varsa (mask) veya iz varsa net görüntü, yoksa buğulu görüntü
    vec3 finalRGB = mix(foggyBg, clearDrop, clamp(mask + trail * 0.5, 0.0, 1.0));

    // İzleri biraz daha parlat
    finalRGB += trail * 0.1;

    // Intensity ayarı
    finalRGB = mix(baseColor.rgb, finalRGB, clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(finalRGB, baseColor.a);
}