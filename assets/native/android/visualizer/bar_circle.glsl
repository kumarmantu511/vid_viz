#version 300 es
precision highp float;
precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;

uniform float uGlow;
uniform float uBarFill;
uniform sampler2D iChannel0;

out vec4 fragColor;

vec3 iResolution;
float iTime;

const float PI = 3.14159265359;

// --- SES VERİSİ OKUMA ---
float _vidvizSample8(float x) {
    x = clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float f0 = (i0 < 0.5) ? uFreq0 : (i0 < 1.5) ? uFreq1 : (i0 < 2.5) ? uFreq2 : (i0 < 3.5) ? uFreq3 :
    (i0 < 4.5) ? uFreq4 : (i0 < 5.5) ? uFreq5 : (i0 < 6.5) ? uFreq6 : uFreq7;
    float f1 = (i1 < 0.5) ? uFreq0 : (i1 < 1.5) ? uFreq1 : (i1 < 2.5) ? uFreq2 : (i1 < 3.5) ? uFreq3 :
    (i1 < 4.5) ? uFreq4 : (i1 < 5.5) ? uFreq5 : (i1 < 6.5) ? uFreq6 : uFreq7;
    return mix(f0, f1, t);
}

// Özel texture fonksiyonu
vec4 _vidvizTexture(sampler2D s, vec2 uv) {
    float v = _vidvizSample8(uv.x);
    return vec4(v, v, v, 1.0);
}

// --- MATEMATİKSEL YARDIMCILAR ---
float distToLineSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri başlat
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // FlutterFragCoord koordinatını al
    vec2 fragCoord = FlutterFragCoord().xy;

    // 1. Ekranı ortala
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // --- GÖRSEL AYARLAR ---
    float barCount = max(1.0, uBars);
    float innerRadius = 0.20;
    float maxBarLength = 0.22 * clamp(uIntensity, 0.5, 2.0);

    // Bar kalınlığı
    float barThickness = 0.008 * mix(0.6, 1.8, clamp(uBarFill > 0.0 ? uBarFill : 0.8, 0.0, 1.0));
    float minBarLength = 0.01;

    // 2. Açı Hesabı
    float angle = atan(uv.y, uv.x) + PI * 0.5;
    float normalizedAngle = fract(angle / (2.0 * PI));
    float currentBarIdx = floor(normalizedAngle * barCount);

    // Döngü içinde en yakın mesafeyi bulacağız (SDF Mantığı)
    float minDist = 1000.0; // Başlangıçta çok uzak

    // 3. Çizim Döngüsü (Komşu pikselleri kontrol et)
    for (int i = -1; i <= 1; i++) {
        float neighborIdx = currentBarIdx + float(i);
        float safeIdx = mod(neighborIdx, barCount);

        // --- SİMETRİK FREKANS DAĞILIMI ---
        float t = safeIdx / barCount;
        float symmetryT = abs(2.0 * t - 1.0);
        float freqIndex = 1.0 - symmetryT;

        // Frekansı oku (texture yerine _vidvizTexture kullandık)
        float intensity = _vidvizTexture(iChannel0, vec2(freqIndex, 0.0)).r;
        intensity = pow(intensity, 0.85);

        // Çubuk Açısı ve Pozisyonu
        float barAngle = (neighborIdx) / barCount * 2.0 * PI - PI * 0.5;
        vec2 dir = vec2(cos(barAngle), sin(barAngle));

        vec2 startPos = dir * innerRadius;
        vec2 endPos = dir * (innerRadius + minBarLength + (intensity * maxBarLength));

        // Bu çubuğa olan mesafe
        float dist = distToLineSegment(uv, startPos, endPos);

        // En yakın mesafeyi sakla
        minDist = min(minDist, dist);
    }

    // --- 4. NETLİK VE GLOW HESABI ---
    // minDist: Pikselin en yakın bara olan uzaklığı (Merkez çizgisine)

    // a) Net Şekil (Core Shape)
    float pixelSize = 1.0 / iResolution.y;
    // barThickness kadar mesafe şeklin içidir.
    float shapeAlpha = 1.0 - smoothstep(barThickness - pixelSize, barThickness + pixelSize, minDist);

    // b) Glow (Parlama)
    // Şeklin kenarından dışarı olan mesafe
    float distFromEdge = max(minDist - barThickness, 0.0);
    float glowInput = max(uGlow, 0.0);
    // 25.0 faktörü ışığın yayılma miktarını belirler
    float glowAlpha = exp(-distFromEdge * 25.0) * glowInput;

    // --- 5. RENK VE BİRLEŞTİRME ---
    // Toplam Görünürlük
    float totalAlpha = clamp(shapeAlpha + glowAlpha, 0.0, 1.0);

    // Renk Gradyanı
    float gy = clamp(fragCoord.y / max(iResolution.y, 1.0), 0.0, 1.0);
    vec3 col = mix(uColor, uColor2, gy);

    // Şeffaf, lekesiz çıktı (Premultiplied Alpha)
    if (totalAlpha <= 0.001) {
        fragColor = vec4(0.0);
    } else {
        fragColor = vec4(col * totalAlpha, totalAlpha);
    }
}