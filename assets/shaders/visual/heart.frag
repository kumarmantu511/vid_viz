#include <flutter/runtime_effect.glsl>

precision highp float;

// --- UNIFORMLAR ---
uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform vec3 uColor2;
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform sampler2D uTexture;

out vec4 fragColor;

// --- YARDIMCI FONKSİYONLAR ---
#define PI 3.141592654

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float tanh_approx(float x) {
    float x2 = x*x;
    return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// Sinematik Renk Tonlaması (Daha gerçekçi kontrast)
vec3 aces_approx(vec3 v) {
    v = max(v, 0.0);
    v *= 0.6;
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((v*(a*v+b))/(v*(c*v+d)+e), 0.0, 1.0);
}

float pmin(float a, float b, float k) {
    float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
    return mix(b, a, h) - k*h*(1.0-h);
}

float pabs(float a, float k) {
    return -pmin(a, -a, k);
}

float dot2(vec2 p) {
    return dot(p, p);
}

// --- KALP ŞEKLİ (SDF) ---
float heart(vec2 p) {
    p.x = pabs(p.x, 0.05);
    if( p.y+p.x>1.0 )
    return sqrt(dot2(p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;
    return sqrt(min(dot2(p-vec2(0.00,1.00)),
    dot2(p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}

float df(vec2 p) {
    vec2 hp = p;
    float hz = 1.0;
    hp /= hz;
    hp.y -= -0.6;
    return heart(hp)*hz;
}

// Yükseklik Haritası (Damarlı yapı hissi için)
float hf(vec2 p) {
    float d = df(p);
    float h = (-20.0*d);
    h = tanh_approx(h);
    h -= 3.0*length(p);
    h = pmin(h, 0.0, 1.0);
    h *= 0.25;
    return h;
}

vec3 nf(vec2 p) {
    vec2 e = vec2(5.0/uResolution.y, 0);
    vec3 n;
    n.x = hf(p + e.xy) - hf(p - e.xy);
    n.y = hf(p + e.yx) - hf(p - e.yx);
    n.z = 2.0*e.x;
    return normalize(n);
}

// --- NOISE ---
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise(vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    vec2 i = floor(p + (p.x + p.y)*K1);
    vec2 a = p - i + (i.x + i.y)*K2;
    vec2 o = step(a.yx, a.xy);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0*K2;
    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h*h*h*h*vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}

float fbm(vec2 pos, float tm) {
    vec2 offset = vec2(cos(tm), sin(tm*sqrt(0.5)));
    float aggr = 0.0;
    aggr += noise(pos);
    aggr += noise(pos + offset) * 0.5;
    aggr += noise(pos + offset.yx) * 0.25;
    aggr += noise(pos - offset) * 0.125;
    aggr /= 1.9375;
    return (aggr * 0.5) + 0.5;
}

float divf(float offset, float f) {
    float r = abs(0.2 + offset - f);
    return max(r, 0.001);
}

// --- ELEKTRİK EFEKTİ ---
vec3 lightning(vec2 pos, vec2 pp, float offset, float beatIntensity) {
    vec3 sub = 0.03 * vec3(0.0, 1.0, 2.0).zyx * length(pp);

    // Zaman akışı
    float time = (uTime * uSpeed) + 123.4;
    float stime = time / 200.0;

    vec3 col = vec3(0.0);
    // Akış vektörü
    vec2 f = 10.0 * cos(vec2(sqrt(0.5), 1.0) * stime) + vec2(0.0, -11.0) * stime;

    float glow = 0.0125 + (beatIntensity * 0.02);

    // OPTİMİZASYON: Mobil için döngü sayısı 2'de tutuldu.
    for (float i = 0.0; i < 2.0; ++i) {
        vec3 gcol0 = (1.0 + cos(0.50 * vec3(0.0, 1.0, 2.0) + time + 3.0 * pos.x - 0.33 * i));
        gcol0 = mix(gcol0, uColor * 2.0, 0.5);

        vec3 gcol1 = (1.0 + cos(1.25 * vec3(0.0, 1.0, 2.0) + 2.0 * time + pos.y + 0.25 * i));
        gcol1 = mix(gcol1, uColor2 * 2.0, 0.5);

        float btime = stime * 85.0 + i;
        float rtime = stime * 75.0 + i;

        float div1 = divf(offset, fbm((pos + f) * 3.0, rtime));
        float div2 = divf(offset, fbm((pos + f) * 2.0, btime));

        float d1 = offset * glow / div1;
        float d2 = offset * glow / div2;

        col += (d1 * gcol0) - sub;
        col += (d2 * gcol1) - sub;
    }
    return col;
}

// --- EFEKT BİRLEŞTİRME ---
vec3 effect(vec2 p, vec2 pp, float beat) {
    float aa = 4.0 / uResolution.y;

    float d = df(p);
    float h = hf(p);
    vec3 n = nf(p);

    // Işık kaynağı pozisyonu
    const vec3 lp = vec3(-4.0, -5.0, 3.0);
    const vec3 ro = vec3(0.0, 0.0, 10.0);
    vec3 p3 = vec3(p, h);
    vec3 rd = normalize(p3 - ro);
    vec3 ld = normalize(lp - p3);
    vec3 r = reflect(rd, n);

    // Diffuse aydınlatma
    float diff = max(dot(ld, n), 0.0);

    // --- GERÇEKÇİ KALP RENGİ AYARLARI ---
    // 1. Taban Rengi: Daha derin, kan kırmızısı (Hue: 0.99, Sat: 0.95, Val: 0.6)
    vec3 bloodRed = hsv2rgb(vec3(0.99, 0.95, 0.6));

    // 2. Aydınlık kısımlar: Işığın vurduğu yerler daha canlı kırmızıya döner
    vec3 brightRed = hsv2rgb(vec3(0.0, 0.9, 0.8));

    // Gölgeler için çok koyu bordo
    vec3 shadowCol = vec3(0.1, 0.0, 0.0);

    // Diffuse karıştırma: Gölge -> Taban -> Aydınlık
    vec3 dcol = mix(shadowCol, bloodRed, smoothstep(0.0, 0.5, diff));
    dcol = mix(dcol, brightRed, smoothstep(0.5, 1.0, diff));

    // --- MATERYAL PARLAMASI (ISLAK GÖRÜNÜM) ---
    float spe = pow(max(dot(ld, r), 0.0), 12.0); // Daha dar, keskin parlama (ıslaklık hissi)
    vec3 wetSpec = vec3(1.0, 0.8, 0.8) * 0.8; // Hafif pembe/beyaz parlama
    vec3 scol = spe * wetSpec;

    float gd = d;
    vec2 gp = p;

    // Elektrik efekti (Kalbin üzerindeki enerji)
    vec3 gcol = lightning(gp, pp, gd, beat);

    vec3 hcol = dcol + scol;
    vec3 col = vec3(0.0);

    // Arka plan ışığı (Ambient Glow) - Koyu kırmızı atmosfer
    vec3 gbcol = hsv2rgb(vec3(0.99, 1.0, 0.005)) * (1.0 + beat * 5.0);
    col += gbcol / max(0.01 * (dot2(p) - 0.10), 0.0001);

    col += gcol;

    // Kalbi sahneye yerleştir
    col = mix(col, hcol, smoothstep(0.0, -aa, d));

    // --- KENAR EFEKTİ (RIM LIGHT / SUBSURFACE SCATTERING) ---
    // Kalbin kenarlarından ışık sızıyormuş gibi parlak, sıcak bir kırmızı
    vec3 rimColor = hsv2rgb(vec3(0.02, 1.0, 2.0)); // Neon turuncu/kırmızı
    float rimWidth = 0.015; // Kenar kalınlığı
    float rimMask = smoothstep(0.0, -aa, abs(d + rimWidth) - rimWidth);

    // Sadece dış kenarlara değil, ışığın vurduğu yüzeye göre
    float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
    col = mix(col, rimColor, rimMask * fresnel * 0.8);

    // Vinyet (Köşeleri karartma)
    col *= smoothstep(1.8, 0.5, length(pp));

    // Renk İşleme
    col = aces_approx(col); // Sinematik kontrast
    col = sqrt(col);        // Gamma düzeltmesi
    return col;
}

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 res = uResolution;

    // Bas analizi
    float bass = (uFreq0 + uFreq1) * 0.5;
    float beat = smoothstep(0.2, 0.8, bass);

    vec2 q = frag / res;

    // --- KOORDİNAT SİSTEMİ DÜZELTMESİ ---
    vec2 p = -1.0 + 2.0 * q;
    p.y = -p.y; // Kalbi ve dünyayı düzeltir
    // ------------------------------------

    vec2 pp = p;
    p.x *= res.x / res.y;

    // Beat ile hafif zoom
    float zoom = 1.0 - (beat * 0.10); // Biraz daha yumuşak zoom
    p *= zoom;

    vec3 col = effect(p, pp, beat);

    // Doku ile karıştırma
    vec2 uv = frag / res;
    vec3 stage = texture(uTexture, uv).rgb;
    vec3 finalMix = mix(stage, col, clamp(uIntensity, 0.0, 1.0));

    fragColor = vec4(finalMix, 1.0);
}