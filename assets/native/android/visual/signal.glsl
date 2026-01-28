#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity; // Sinyal gücü ve Glitch miktarı
uniform float uSpeed;
uniform vec3 uColor;      // Ana sinyal rengi
uniform float uBars;
uniform float uFreq0; uniform float uFreq1; uniform float uFreq2; uniform float uFreq3;
uniform float uFreq4; uniform float uFreq5; uniform float uFreq6; uniform float uFreq7;
uniform vec3 uColor2;     // İkincil parıltı rengi
uniform sampler2D uTexture;

out vec4 fragColor;

// Rastgelelik fonksiyonu
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Gürültü fonksiyonu (Sinyaldeki organik titreşim için)
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Sinyal Fonksiyonu: Elektrik dalgası oluşturur
float signalWave(vec2 uv, float time, float freqAvg) {
    // Temel dalga
    float wave = sin(uv.x * 10.0 + time * 2.0);

    // Karmaşıklık ekle (Harmonikler)
    wave += sin(uv.x * 20.0 - time * 5.0) * 0.5;
    wave += sin(uv.x * 50.0 + time * 8.0) * 0.2;

    // Gürültü ile boz (Elektrik cızırtısı gibi)
    float n = noise(vec2(uv.x * 20.0, time * 10.0));
    wave += (n - 0.5) * (0.5 + freqAvg * 2.0); // Müzikle titreşim artar

    return wave * 0.15; // Yüksekliği ayarla
}

// Arka plan ızgarası
float grid(vec2 uv, float t) {
    vec2 size = vec2(10.0, 10.0); // Izgara sıklığı
    uv += vec2(t * 0.2, t * 0.1); // Izgara hareketi
    vec2 grid = abs(fract(uv * size) - 0.5);
    float lines = smoothstep(0.48, 0.5, max(grid.x, grid.y));
    return lines * 0.1; // Çok silik olsun
}

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 uv = (frag - 0.5 * uResolution) / uResolution.y;

    // --- SES VE ZAMAN ANALİZİ ---
    float t = uTime * (0.5 + 0.5 * uSpeed);
    // Bas ve Tiz frekansların ortalaması
    float bass = (uFreq0 + uFreq1) / 2.0;
    float mid = (uFreq2 + uFreq3 + uFreq4) / 3.0;
    float treble = (uFreq5 + uFreq6 + uFreq7) / 3.0;
    float totalAudio = (bass + mid + treble) / 3.0; // Genel ses şiddeti

    // --- ARKA PLAN (GRID) ---
    // Hafif bir siber ızgara
    vec3 bgCol = vec3(0.05, 0.05, 0.08); // Çok koyu gri/mavi taban
    float g = grid(uv, t);
    bgCol += uColor2 * g * (0.5 + bass); // Izgara müzikle parlasın

    // --- SİNYAL ÇİZİMİ ---
    vec3 signalCol = vec3(0.0);

    // 3 Katmanlı Sinyal Çiziyoruz (RGB Ayrışması efekti için hafif kaydırma)
    for(float i = 0.0; i < 3.0; i++) {
        // Her katmanı hafifçe kaydır (Chromatic Aberration)
        float offset = i * 0.005 * (1.0 + bass * 2.0);

        // Sinyalin Y pozisyonunu hesapla
        float waveY = signalWave(uv + vec2(0.0, offset), t, totalAudio);

        // Genlik (Amplitude): Kenarlarda sönsün, ortada güçlü olsun
        float amplitude = (1.0 - abs(uv.x * 1.5)) * (0.5 + totalAudio * 1.5);
        amplitude = clamp(amplitude, 0.0, 1.5);

        // Mesafe hesapla (Distance Field)
        float dist = abs(uv.y - waveY * amplitude);

        // GLOW (Parlaklık) Formülü: 1.0 / distance
        // uIntensity burada sinyalin kalınlığını ve keskinliğini ayarlar
        float glow = 0.008 / (dist + 0.001);

        // Keskin çizgi (Core)
        float core = smoothstep(0.02, 0.0, dist);

        // Renk Karışımı
        vec3 col = mix(uColor, uColor2, i * 0.5); // Renk geçişi
        signalCol += col * (glow * 0.6 + core) * clamp(uIntensity, 0.0, 1.5);
    }

    // --- TEXTURE İLE BİRLEŞTİRME ---
    // Görüntüyü hafifçe dijital bozulmaya uğrat (Glitch)
    float glitchX = noise(vec2(uv.y * 10.0, t * 20.0)) * 0.01 * bass * uIntensity;
    vec4 texColor = texture(uTexture, (frag / uResolution) + vec2(glitchX, 0.0));

    // --- TARAMA ÇİZGİLERİ (SCANLINES) ---
    float scanline = sin(frag.y * 0.5 + t * 10.0) * 0.5 + 0.5;
    texColor.rgb *= (0.8 + 0.2 * scanline); // Resme retro TV havası ver

    // --- FİNAL KOMPOZİSYON ---
    // Arka plan + Sinyal
    vec3 scene = bgCol + signalCol;

    // Resim ile Sinyali birleştir
    // Sinyal resmin üzerinde "Screen" modu gibi bindirilir
    vec3 finalRGB = mix(texColor.rgb, scene, 0.5 * uIntensity); // uIntensity karışımı kontrol eder

    // Sinyalin olduğu yerlerde parlaklığı artır (Additive Blending)
    finalRGB += signalCol * texColor.a; // Sadece resmin olduğu yerlerde parlasın istiyorsan texColor.a ile çarp

    // Vinyet (Kenarları karart)
    float vignette = 1.0 - length(uv) * 0.5;
    finalRGB *= vignette;

    fragColor = vec4(finalRGB, texColor.a);
}