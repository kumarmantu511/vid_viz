#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;

uniform float uIntensity;   // 0.0 - 1.0
uniform float uSpeed;       // 0.5 - 2.0
uniform float uDropSize;    // 0.5 - 2.0
uniform float uDensity;     // 0.0 - 1.0

out vec4 fragColor;

// Rastgelelik
vec3 N13(float p) {
    vec3 p3 = fract(vec3(p) * vec3(.1031, .11369, .13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

float N(float t) {
    return fract(sin(t * 12345.564) * 7658.76);
}

// Ana Damla Fonksiyonu (Düzeltilmiş ve Optimize Edilmiş)
vec2 Drops(vec2 uv, float t, float dSize, float density) {
    vec2 UV = uv;
    uv.y = -uv.y;
    uv.y += t * 0.8;

    vec2 a = vec2(6., 1.);
    vec2 grid = a * 2.;

    // Merkez hatası fix
    vec2 gridUV = uv + vec2(1000.0, 1000.0);
    vec2 id = floor(gridUV * grid);

    float randomID = N(id.x * 35.2 + id.y * 2376.1);
    vec3 n = N13(id.x * 35.2 + id.y * 2376.1);

    if (n.x > density) return vec2(0.0);

    float colShift = N(id.x);
    uv.y += colShift;

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

    float d = length((st - p) * a.yx);
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
    float dd = length(st - vec2(x, y));
    droplets = smoothstep(currentDropSize * N(id.x), 0., dd);

    float m = Drop + droplets * r * trailFront;
    float borderMask = smoothstep(0.5, 0.35, abs(st.x));

    return vec2(m * borderMask, trail * borderMask);
}

float StaticDrops(vec2 uv, float t, float dSize) {
    uv *= 30.;
    vec2 gridUV = uv + vec2(1000.0, 1000.0);
    vec2 id = floor(gridUV);
    uv = fract(gridUV) - .5;
    vec3 n = N13(id.x * 107.45 + id.y * 3543.654);
    vec2 p = (n.xy - .5) * 0.5;
    float d = length(uv - p);
    float fade = smoothstep(0., .025, fract(t + n.z)) * smoothstep(1., .025, fract(t + n.z));
    return smoothstep(dSize * 0.2, 0., d) * fract(n.z * 10.) * fade;
}

vec2 Rain(vec2 uv, float t, float dSize, float density) {
    float s = StaticDrops(uv, t, dSize);
    vec2 r1 = Drops(uv, t, dSize, density);
    vec2 r2 = Drops(uv * 1.8, t, dSize, density);
    float c = s + r1.x + r2.x;
    c = smoothstep(.3, 1., c);
    return vec2(c, max(r1.y, r2.y));
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = (fragCoord - .5 * uResolution.xy) / uResolution.y;
    vec2 UV = fragCoord / uResolution.xy;

    vec4 baseColor = texture(uTexture, UV);
    if (baseColor.a < 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    float T = uTime * clamp(uSpeed, 0.2, 3.0);
    float t = T * .2;
    float dSize = clamp(uDropSize, 0.5, 2.0);
    float density = clamp(uDensity, 0.1, 1.0);

    // Zoom
    UV = (UV - .5) * .98 + .5;

    // 1. Yağmur Maskesi
    vec2 c = Rain(uv, t, dSize, density);

    // 2. Normal (Kırılma) Hesapla
    vec2 e = vec2(.001, 0.);
    float cx = Rain(uv + e, t, dSize, density).x;
    float cy = Rain(uv + e.yx, t, dSize, density).x;
    vec2 n = vec2(cx - c.x, cy - c.x);

    // --- GERÇEK BLUR (OPTIMIZE EDİLMİŞ) ---
    // Orijinal 64 döngü yerine 9 döngü (3x3 Box Blur).
    // Mobilde "buzlu cam" etkisi yaratmak için yeterlidir.

    vec3 blurredColor = vec3(0.0);
    float blurSteps = 1.0;
    float blurRadius = 0.004; // Bulanıklık miktarı (Artırırsan daha çok bulanık olur)

    // -1'den +1'e kadar (3x3 = 9 örnek)
    for (float i = -1.0; i <= 1.0; i++) {
        for (float j = -1.0; j <= 1.0; j++) {
            vec2 offset = vec2(i, j) * blurRadius;
            blurredColor += texture(uTexture, UV + offset).rgb;
        }
    }
    blurredColor /= 9.0; // Ortalamayı al

    // Blur'lu rengi biraz beyazla karıştır (Buhar etkisi)
    vec3 foggyBg = mix(blurredColor, vec3(0.9, 0.95, 1.0), 0.25);

    // --- NET DAMLA GÖRÜNTÜSÜ ---
    // Damlanın olduğu yeri blur'suz, temiz texture'dan al
    // + Kırılma efekti ekle (n)
    vec3 clearDrop = texture(uTexture, UV + n).rgb;

    // Damla parlaklığı
    float trail = clamp(c.y, 0.0, 1.0);

    // 3. BİRLEŞTİRME
    // Maske: c.x (damlalar) + trail (izler)
    // Eğer maske 0 ise (damla yok) -> FoggyBg (Blur)
    // Eğer maske 1 ise (damla var) -> ClearDrop (Net)
    float mask = clamp(c.x + trail * 0.7, 0.0, 1.0);

    vec3 finalRGB = mix(foggyBg, clearDrop, mask);

    // Damlalara hafif parlaklık ekle
    finalRGB += trail * 0.15;

    // Intensity ayarı (Orijinal resim ile efektli resim arası geçiş)
    finalRGB = mix(baseColor.rgb, finalRGB, clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(finalRGB, baseColor.a);
}