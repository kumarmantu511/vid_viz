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
uniform sampler2D iChannel0;

out vec4 fragColor;

vec3 iResolution;
float iTime;

const float PI = 3.14159265359;

// --- FREKANS OKUMA ---
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

// HATA KAYNAĞI OLAN MAKRO SİLİNDİ.

// --- YARDIMCI FONKSİYONLAR ---
float normalizeAngle(float a) {
    if(a > PI * 0.5) a = PI - a;
    if(a < -PI * 0.5) a = -PI - a;
    return 1.0 - ((a / (PI * 0.5)) + 1.0) * 0.5;
}

vec3 map(float v, float edge, vec3 c1, vec3 c2, float t) {
    float m = t / iResolution.x;
    float d = v - edge;
    float a = abs(d);

    if(a <= m) {
        float b = ((d + m) * 0.5) / m;
        return mix(c1, c2, smoothstep(0.0, 1.0, b));
    } else if (d < 0.0) {
        return c1;
    } else {
        return c2;
    }
}

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri ayarla
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // Flutter koordinatını al
    vec2 fragCoord = FlutterFragCoord().xy;

    // Y eksenini ters çevir
    vec2 flippedCoord = vec2(fragCoord.x, iResolution.y - fragCoord.y);

    // Basit ortalama (Bass frekansları için)
    float bass = (_vidvizSample8(0.0) + _vidvizSample8(0.1)) * 0.5;

    // Ana animasyon değişkeni (Intensity ile güçlendirilmiş)
    float s1 = min(pow(bass * 0.8, 4.0) * 5.0 * uIntensity, 1.0);

    // Titreme efekti
    float wiggle = max(0.0, bass - 0.7) * 0.03;
    vec2 uv = (flippedCoord / iResolution.xy) + vec2(sin(iTime * 18.0), cos(iTime * 17.0)) * wiggle;

    vec2 ar = vec2(iResolution.x / iResolution.y, 1.0);
    vec2 p = uv * ar * 2.0 - ar;

    // Açı hesaplamaları
    float angle = atan(p.y, p.x);
    float angle2 = angle - PI * 0.25;
    angle = normalizeAngle(angle);
    angle2 = normalizeAngle(angle2);

    float d = length(p);
    vec3 bg = vec3(0.0);

    // "Sample" değerini hesapla (Struct yerine doğrudan hesaplama)
    // Daire etrafındaki frekans görselleştirmesi
    // Açıyı (0-1 aralığında) frekans girişine dönüştür
    float samplePos = abs(angle); // Simetrik olsun diye abs
    // _vidvizTexture kullanarak frekansı al
    float so = _vidvizTexture(iChannel0, vec2(samplePos, 0.0)).r;
    // Frekansı biraz yumuşat ve güçlendir
    so = smoothstep(0.2, 0.8, so) * uIntensity;

    // Görsel Parametreler
    float baseSize = 0.4;
    float ringSize = 0.03;
    float outerGrowth = 0.1;
    float innerGrowth = 0.3;
    float colorDistortion = 0.025;

    float innerBorder = s1 * innerGrowth * 0.2 + baseSize * 0.3;
    float outerBorder = s1 * innerGrowth * 0.7 + baseSize;

    // Gradyanlar
    vec3 sub = vec3(s1 * 0.2 * sqrt(d));
    float minCol = 0.02;
    float maxCol = 0.2;

    vec3 grad1 = vec3(0.01) + vec3(minCol + max(0.0, (0.5 - angle2)) * maxCol) * 2.0 * pow(d / max(0.001, innerBorder), 2.0) - sub;
    vec3 grad2 = vec3(0.01) + vec3(minCol + max(0.0, (angle2 - 0.5)) * maxCol) * 2.0 * (d / max(0.001, outerBorder)) - sub;

    // Renk Halkaları (Chromatic Aberration Efekti)
    float cds = 0.02 * iResolution.x;
    vec3 col1 = grad1;
    float ring = ringSize + ringSize * sqrt(s1);
    float dynamicRadius = s1 * innerGrowth + baseSize + ring;

    col1 = map(d, innerBorder, col1, grad2, 0.004 * iResolution.x);
    col1 = map(d, outerBorder, col1, vec3(1.0), 0.003 * iResolution.x);

    // RGB Separation halkaları
    // Renkleri uColor ve uColor2 ile harmanlayalım
    vec3 cRed = mix(vec3(1.0, 0.0, 0.0), uColor, 0.5);
    vec3 cGreen = mix(vec3(0.0, 1.0, 0.0), uColor, 0.3);
    vec3 cBlue = mix(vec3(0.0, 0.0, 1.0), uColor2, 0.5);

    col1 = map(d, dynamicRadius + so * outerGrowth, col1, vec3(1.0, 1.0, 0.0), 2.0 + so * cds);
    col1 = map(d, dynamicRadius + so * (outerGrowth + colorDistortion), col1, cRed, 2.0 + so * cds);
    col1 = map(d, dynamicRadius + so * (outerGrowth + colorDistortion * 2.0), col1, cBlue, 2.0 + so * cds);
    col1 = map(d, dynamicRadius + so * (outerGrowth + colorDistortion * 3.0), col1, cGreen, 2.0 + so * cds);

    // Dış kesim
    col1 = map(d, dynamicRadius - 0.002 + so * (outerGrowth + colorDistortion * 4.0), col1, bg, 2.0 + so * cds);

    // Normalize
    float m = max(max(col1.r, col1.g), col1.b);
    if(m > 1.0) {
        col1 /= m;
    }

    // Kullanıcının seçtiği renkle hafif tint (Tonlama)
    col1 = mix(col1, col1 * uColor, 0.3);

    // Alpha (Şeffaf arka plan için)
    // Siyah olan yerler şeffaf olsun, renkli yerler görünür olsun.
    float alpha = smoothstep(0.05, 1.5, length(col1));

    // Premultiplied Alpha
    fragColor = vec4(col1 * alpha, alpha);
}