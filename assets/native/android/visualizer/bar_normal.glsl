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

// --- FREKANS OKUMA (Dokunulmadı) ---
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

// HATA KAYNAĞI OLAN "#define texture" SİLİNDİ.

// --- ANA FONKSİYON ---
void main() {
    // Global değişkenleri ayarla
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;

    // Flutter koordinatlarını al
    vec2 fragCoord = FlutterFragCoord().xy;

    // 1. Koordinatları ayarla
    vec2 uv = vec2(fragCoord.x, iResolution.y - fragCoord.y) / iResolution.xy;

    // Yan Boşluklar (Margin)
    float sideMargin = 0.005;
    uv.x = (uv.x - sideMargin) / (1.0 - 2.0 * sideMargin);

    // Kenar dışını temizle
    if (uv.x < 0.0 || uv.x > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Y eksenini yukarı kaydır ve ölçekle (Orijinal koddaki mantık)
    vec2 nv = uv;
    nv.y = (nv.y - 0.005) * 2.0;

    // --- 2. BAR GEOMETRİSİ ---
    float barCount = max(1.0, uBars);

    // Doluluk oranı (Genişlik)
    float fillRatio = clamp(uBarFill, 0.05, 0.95);

    // Hangi barda olduğumuzu bul
    float barIndex = floor(uv.x * barCount);

    // Barın içindeki lokal X (0..1)
    float localX = fract(uv.x * barCount);

    // --- 3. YÜKSEKLİK ---
    // Ses verisini al
    // BURASI DÜZELTİLDİ: 'texture' yerine '_vidvizTexture' kullanıldı
    float h = _vidvizTexture(iChannel0, vec2(barIndex / barCount, 0.0)).r;
    h = clamp(h * uIntensity, 0.0, 1.0);

    // --- 4. SDF (MESAFE ALANI) HESABI ---
    // Netlik ve Glow için piksel bazlı mesafe hesabı yapıyoruz.

    // X eksenindeki mesafe (Barın kenarına olan uzaklık)
    // Merkez (0.5)'ten uzaklık - Yarı genişlik
    float halfWidth = 0.5 * fillRatio;
    float dx = abs(localX - 0.5) - halfWidth;

    // Y eksenindeki mesafe (Barın tepesine olan uzaklık)
    float dy = nv.y - h;

    // Bu mesafeleri "Ekran Pikseline" çevirmeliyiz
    float dxPx = dx * (iResolution.x / barCount);

    // Y ekseni: nv.y 2 kat scale edildiği için piksel karşılığı iResolution.y / 2.0'dır.
    float dyPx = dy * (iResolution.y * 0.5);

    // Dikdörtgen Mesafesi (Box SDF mantığı)
    float dist = max(dxPx, dyPx);

    // --- 5. ÇİZİM VE GLOW ---

    // AA (Anti-aliasing)
    float shapeAlpha = 1.0 - smoothstep(0.0, 1.5, dist);

    // Alt kısımdan taşmayı engelle
    if (nv.y < 0.0) shapeAlpha = 0.0;

    // Glow (Parlama)
    float glowInput = max(uGlow, 0.0);
    float glowDist = max(dist, 0.0);
    float glowAlpha = exp(-glowDist * 0.2) * glowInput;

    // Toplam Görünürlük
    float finalAlpha = clamp(shapeAlpha + glowAlpha, 0.0, 1.0);

    // --- 6. RENK ---
    float gy = clamp(uv.y, 0.0, 1.0);
    vec3 tint = mix(uColor, uColor2, gy);

    if (finalAlpha <= 0.001) {
        fragColor = vec4(0.0);
    } else {
        // Premultiplied Alpha
        fragColor = vec4(tint * finalAlpha, finalAlpha);
    }
}