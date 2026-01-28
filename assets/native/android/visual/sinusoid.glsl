#version 300 es
precision highp float;
// Modern Audio Visualizer
// - Multi-layered sine waves
// - Neon glow using inverse distance
// - Chromatic aberration for modern look

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity; // Opacity of the effect
uniform float uSpeed;
uniform vec3 uColor;      // Start Color
uniform float uBars;      // (Unused but kept for compatibility)
uniform float uFreq0;     // Bass
uniform float uFreq1;
uniform float uFreq2;     // Mids
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;     // Highs
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;     // End Color
uniform sampler2D uTexture; // Background stage texture

out vec4 fragColor;

// Basit bir hash fonksiyonu (rastgelelik için)
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// Dalga fonksiyonu: Sese göre şekil alır
float getWaveHeight(vec2 uv, float time, float audioLow, float audioHigh) {
    float x = uv.x * 6.0; // Genişlik çarpanı

    // 3 Katmanlı Sinüs (Fractal toplama benzeri)
    float y = sin(x + time) * 0.4;
    y += sin(x * 2.1 + time * 1.5) * 0.2;
    y += sin(x * 4.3 - time * 0.8) * 0.1;

    // Audio modülasyonu: Bass büyük dalgaları, Tiz küçük titremeleri etkiler
    float amp = 0.5 + 1.5 * audioLow;
    float detail = 0.5 + 2.0 * audioHigh;

    // Kenarlara doğru sönümleme (Vignette for wave)
    float fade = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);

    return y * amp * fade * 0.5; // Yüksekliği scale et
}

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 uv = frag / uResolution;

    // Aspect ratio düzeltmesi (Dalgaların ezilmemesi için)
    // uv.x *= uResolution.x / uResolution.y; // İsteğe bağlı, tam ekran etkisi için kapattım

    float time = uTime * uSpeed;

    // Audio Gruplama
    // Bass (Güçlü hareket)
    float bass = (uFreq0 + uFreq1) * 0.5;
    // Mid (Renk yoğunluğu)
    float mid = (uFreq2 + uFreq3 + uFreq4) * 0.33;
    // Treble (Detay/Titreme)
    float treble = (uFreq5 + uFreq6 + uFreq7) * 0.33;

    // Audio input yoksa varsayılan hafif bir hareket olsun
    float totalAudio = bass + mid + treble;
    if (totalAudio < 0.01) {
        bass = 0.2;
        treble = 0.1;
    }

    // Koordinatları merkeze al (Y ekseni için)
    vec2 p = uv;
    p.y = p.y * 2.0 - 1.0; // -1 to 1

    // --- RENDER ---

    vec3 waveColor = vec3(0.0);
    float glowWidth = 0.02 + 0.05 * bass; // Bass vurdukça kalınlaşır

    // Kromatik Aberasyon: RGB kanallarını hafifçe kaydırarak hesapla
    for(float i = 0.0; i < 3.0; i++) {
        // Kanal ofseti (0.005 kadar sağa sola kaydır)
        float offset = (i - 1.0) * 0.008 * (1.0 + bass);

        // Dalga Yüksekliğini hesapla
        float waveY = getWaveHeight(vec2(uv.x + offset, uv.y), time, bass, treble);

        // Mesafe (Distance Field)
        float dist = abs(p.y - waveY);

        // Neon Glow Formülü: 1.0 / (mesafe ^ güç)
        // Intensity burada parlaklığı ayarlar
        float intensity = 0.008 / (dist + 0.001);

        // Dikey birleşimlerde patlamayı önle
        intensity = clamp(intensity, 0.0, 50.0);

        // Kanallara böl (0=R, 1=G, 2=B)
        if(i == 0.0) waveColor.r += intensity;
        if(i == 1.0) waveColor.g += intensity;
        if(i == 2.0) waveColor.b += intensity;
    }

    // Renk Karışımı (Gradyan)
    vec3 gradientCol = mix(uColor, uColor2, uv.x + sin(time * 0.5) * 0.2);

    // Beyaz çekirdek + Renkli dış hare
    // waveColor şu an siyah-beyaz maske gibi, onu renkle çarpıyoruz
    vec3 finalGlow = waveColor * gradientCol;

    // Çok parlak yerleri beyaza çek (HDR tonlama benzeri)
    finalGlow += vec3(smoothstep(5.0, 10.0, waveColor.r)) * 0.5;

    // Arka plan dokusu ile birleştirme
    vec4 stageTex = texture(uTexture, frag / uResolution);
    vec3 bg = stageTex.rgb;

    // Siyah arkaplan üzerine bindirme (Additive Blending mantığı)
    vec3 composited = bg + finalGlow * uIntensity;

    // Hafif vignette (Ekran kenarlarını karartma)
    float vignette = 1.0 - dot(uv - 0.5, uv - 0.5) * 1.5;
    composited *= clamp(vignette, 0.7, 1.0);

    fragColor = vec4(composited, 1.0);
}