#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor; // Uygulamadan gelen renk
uniform float uBars;
uniform float uFreq0; uniform float uFreq1; uniform float uFreq2; uniform float uFreq3;
uniform float uFreq4; uniform float uFreq5; uniform float uFreq6; uniform float uFreq7;
uniform vec3 uColor2;
uniform sampler2D uTexture;

out vec4 fragColor;

// --- Gürültü ve Matematik ---
float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.5);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Dalga detayı
float fbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 4; i++) {
        f += w * noise(p);
        p *= 2.2;
        w *= 0.48;
    }
    return f;
}

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 uv = frag / uResolution;

    // Koordinatları hazırla ve Ters Çevir (Gökyüzü yukarı)
    vec2 p = (frag - 0.5 * uResolution) / uResolution.y;
    p.y *= -1.0;

    // Zaman ve Hız
    float t = uTime * (0.1 + 0.1 * uSpeed);

    // Güneş Pozisyonu (Tam batarken, ufka yakın)
    vec2 sunPos = vec2(0.0, 0.12);

    // --- GÖKYÜZÜ RENKLERİ (GÜN BATIMI) ---
    // Griliği atmak için canlı renkler seçiyoruz
    vec3 skyNight = vec3(0.05, 0.1, 0.3);   // En tepedeki derin lacivert
    vec3 skySunset = vec3(1.0, 0.4, 0.1);   // Ufuktaki canlı turuncu
    vec3 skyHorizon = vec3(0.8, 0.2, 0.3);  // Ufuk çizgisi geçişi (kızıl)

    // Gökyüzü gradyanı
    float skyMix = smoothstep(-0.1, 0.6, p.y);
    vec3 skyCol = mix(skyHorizon, skyNight, skyMix);
    // Güneşin etrafına turuncuyu ekle
    float sunAtmosphere = 1.0 - length(p - sunPos);
    skyCol = mix(skyCol, skySunset, smoothstep(0.5, 1.0, sunAtmosphere) * 0.8);

    // Bulutlar
    if (p.y > -0.1) {
        vec2 cloudUV = p * vec2(1.0, 3.0) + vec2(t * 0.15, 0.0);
        float cl = fbm(cloudUV * 4.0);
        float cloudAlpha = smoothstep(0.4, 0.8, cl) * 0.5;
        // Bulutlar gün batımı rengini alsın (hafif pembe/turuncu)
        vec3 cloudColor = vec3(1.0, 0.8, 0.8);
        skyCol = mix(skyCol, cloudColor, cloudAlpha);
    }

    // Güneş Çizimi
    float d = length(p - sunPos);
    float sun = smoothstep(0.06, 0.050, d);
    float glow = exp(-5.0 * d);
    skyCol += vec3(1.0, 0.8, 0.4) * (sun + glow * 0.6); // Altın rengi güneş


    // --- SU VE DALGALAR ---
    vec3 waterCol = vec3(0.0);

    if (p.y < 0.0) {
        float z = 1.0 / abs(p.y);
        vec2 planeUV = vec2(p.x * z, z);

        // Dalga Hareketleri
        vec2 waveMov1 = planeUV * 0.5 + vec2(t, t * 0.8);
        vec2 waveMov2 = planeUV * 0.7 + vec2(-t * 0.5, t);

        float w1 = noise(waveMov1 * 4.0);
        float w2 = noise(waveMov2 * 4.0);
        float waves = (w1 + w2) * 0.5;

        // Normal (Eğim) Hesabı
        vec2 tilt = vec2(
        noise(waveMov1 * 4.1) - w1,
        noise(waveMov2 * 4.1) - w2
        ) * 1.5;

        float fresnel = pow(1.0 - abs(p.y), 4.0);

        // --- SU RENGİ AYARLAMASI (Giri önlemek için) ---
        // Burası kritik: Griliği önlemek için "Sert Mavi" ekliyoruz.
        vec3 deepSeaBlue = vec3(0.0, 0.2, 0.6); // Saf okyanus mavisi
        // uColor (kullanıcı rengi) ile saf maviyi karıştır
        vec3 baseWaterColor = mix(uColor, deepSeaBlue, 0.6);
        // Dalga tepeleri biraz daha açık mavi olsun
        vec3 waterBody = mix(baseWaterColor, vec3(0.0, 0.4, 0.8), waves * 0.3);

        // --- Yansımalar ---
        vec2 refUV = vec2(p.x, -p.y) + tilt * 0.15 * (1.0 - abs(p.y));

        // Yansıyan Gökyüzü (Ufuk çizgisindeki kızıllığı yansıt)
        // Ancak suyun kendi mavisini korumak için yansımayı biraz azaltıyoruz
        vec3 refSkyColor = mix(skyHorizon, skyNight, smoothstep(0.0, 1.0, refUV.y));

        // Güneş Yansıması (Yakamoz) - Altın Sarısı
        float sunRefFactor = length(vec2(p.x, p.y + sunPos.y * 3.0) + tilt * 0.3);
        float glitter = smoothstep(0.4, 0.0, sunRefFactor);
        glitter *= smoothstep(0.4, 1.0, waves); // Sadece dalga tepeleri parlasın

        // BİRLEŞTİRME
        // Su = %40 Yansıma + %60 Kendi Mavi Rengi (Fresnel ile değişir)
        waterCol = mix(waterBody, refSkyColor, fresnel * 0.5);

        // Yakamoz ekle
        waterCol += vec3(1.0, 0.7, 0.3) * glitter * 3.5; // Turuncu parıltı

        // Ufuk Çizgisi Yumuşatma
        // Su ile gökyüzü birleşimi hafif puslu olsun
        waterCol = mix(waterCol, skyHorizon, smoothstep(-0.1, 0.0, p.y));

    } else {
        waterCol = skyCol;
    }

    // --- SON RÜTUŞLAR ---
    float vignette = 1.0 - dot(uv - 0.5, uv - 0.5) * 0.6;
    waterCol *= vignette;

    // Renkleri biraz daha canlı yap (Saturation artırma taklidi)
    waterCol = pow(waterCol, vec3(0.9));

    // Texture ve Sahne Karışımı
    float distortion = (p.y < 0.0) ? noise(uv * 15.0 + t) * 0.002 : 0.0;
    vec4 texColor = texture(uTexture, uv + distortion);
    vec4 sceneColor = vec4(waterCol, 1.0);

    fragColor = mix(texColor, sceneColor, clamp(uIntensity, 0.0, 1.0));
}