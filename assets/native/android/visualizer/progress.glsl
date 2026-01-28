#version 300 es
precision highp float;
// --- UNIFORMS (Sıralama ve isimler korundu) ---
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
uniform float uAspect;
uniform float uProgress;
uniform float uStyle;
uniform float uThickness;
uniform float uTrackAlpha;
uniform float uCorner;
uniform float uGap;
uniform float uTheme;
uniform float uEffectAmount;
uniform vec3  uTrackColor;
uniform float uHeadAmount;
uniform float uHeadSize;
uniform float uHeadStyle;

out vec4 fragColor;

// --- YARDIMCI MATEMATİK FONKSİYONLARI ---

float safeDiv(float a, float b) {
    return (b == 0.0) ? 0.0 : a / b;
}

// Canonical Rounded Box SDF
float sdRoundedRect(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + vec2(r);
    return length(max(d, vec2(0.0))) - r;
}

// --- TEMA EFEKTLERİ FONKSİYONU ---
vec3 applyTheme(vec3 baseFill, float tx, float uvY, float centerY) {
    float effect = clamp(uEffectAmount, 0.0, 1.0);
    float glow = clamp(uIntensity, 0.0, 1.0);
    float glowFactor = mix(1.0, 2.2, glow);
    vec3 fillColor = baseFill * glowFactor;
    float t = uTime;
    float theme = uTheme;

    if (theme < 0.5) {
        // 0: Classic - Değişiklik yok
    } else if (theme < 1.5) {
        // 1: Fire
        float time = t * (1.0 + (0.8 + 1.2 * effect) * uSpeed);
        float flicker = 0.7 + mix(0.2, 1.0, effect) * clamp(sin(18.0 * tx + time * 4.0) * sin(time * 3.0) + 0.6 * sin(40.0 * tx + time * 7.0) * sin(8.0 * (uvY - centerY) + time * 5.0), -1.0, 1.0);
        float heat = clamp(tx + 0.25 * effect * sin(time + tx * 6.0), 0.0, 1.0);
        vec3 fireColor = mix(vec3(1.0, 0.25, 0.0), vec3(1.0, 0.55, 0.08), heat);
        fireColor = mix(fireColor, vec3(1.0, 0.98, 0.45), heat * heat);
        fillColor = mix(fillColor, fireColor * glowFactor * (0.8 + 0.9 * flicker * effect), effect);
    } else if (theme < 2.5) {
        // 2: Electric
        float time = t * (1.2 + (0.8 + 1.5 * effect) * uSpeed);
        float spark = 0.7 + (0.3 + 0.7 * effect) * max(0.5 + 0.5 * sin(24.0 * tx + time * 6.0), 1.0 - smoothstep(0.0, 0.25, abs(fract(tx * 6.0 - time * 1.4) - 0.5)));
        fillColor = mix(fillColor, mix(vec3(0.0, 0.65, 1.0), vec3(0.6, 1.0, 1.0), 0.5 + 0.5 * sin(24.0 * tx + time * 6.0)) * (1.2 + glow * 1.0 + 0.8 * effect) * spark, effect);
    } else if (theme < 3.5) {
        // 3: Neon
        float time = t * (0.8 + (0.7 + 1.2 * effect) * uSpeed);
        float stripes = clamp(0.5 * (0.5 + 0.5 * sin(36.0 * tx - time * 3.5 * (0.6 + 0.8 * effect))) + 0.5 * (0.5 + 0.5 * sin(120.0 * (uvY - centerY) + time * 4.0 * (0.6 + 0.8 * effect))), 0.0, 1.0);
        fillColor = mix(fillColor, mix(vec3(0.95, 0.2, 1.0), vec3(0.1, 1.0, 0.9), stripes) * (1.3 + glow * 1.0 + 0.7 * effect) * (1.0 + (0.2 + 0.9 * effect) * sin(time * 2.0)), effect);
    } else if (theme < 4.5) {
        // 4: Rainbow
        float time = t * (0.5 + (0.8 + 1.2 * effect) * uSpeed);
        float phase = tx * (4.0 + 4.0 * effect) + time;
        vec3 rainbow = 0.5 + 0.5 * vec3(sin(phase), sin(phase + 2.094), sin(phase + 4.188));
        fillColor = mix(fillColor, rainbow * (0.8 + 1.4 * glowFactor * effect) * (1.0 + 0.6 * effect * sin(time * 2.2)), effect);
    } else if (theme < 5.5) {
        // 5: Glitch
        float time = t * (0.8 + (1.0 + 2.0 * effect) * uSpeed);
        float bandMask = step(0.75, fract((uvY - centerY) * (8.0 + 8.0 * effect) + time * 1.3));
        float gx = clamp(tx + (fract(sin((tx + time) * 4373.0) * 10000.0) - 0.5) * 0.25 * effect, 0.0, 1.0);
        vec3 glitch = mix(vec3(0.1, 0.9, 1.0), vec3(1.0, 0.1, 0.8), 0.5 + 0.5 * sin(gx * 10.0 + time * 5.0));
        glitch = vec3(glitch.r, mix(glitch.g, glitch.r, 0.015 * effect), mix(glitch.b, glitch.g, 0.015 * effect));
        fillColor = mix(fillColor, glitch * (1.0 + glow * 1.2 + 0.8 * effect) * mix(0.3, 1.0, bandMask * effect), effect);
    } else if (theme < 6.5) {
        // 6: Soft
        float time = t * (0.4 + (0.4 + 0.8 * effect) * uSpeed);
        fillColor = mix(fillColor, mix(mix(baseFill, vec3(1.0), 0.25), mix(baseFill, vec3(1.0), 0.55), (0.5 + 0.5 * sin(tx * 3.0 + time)) * effect) * (0.9 + 0.4 * glow) * (1.0 + 0.25 * effect * sin(time * 0.8)), effect);
    } else if (theme < 7.5) {
        // 7: Sunset
        float time = t * (0.5 + (0.6 + 0.8 * effect) * uSpeed);
        float h = clamp(uvY + 0.1 * sin(tx * 2.5 + time * 0.7), 0.0, 1.0);
        vec3 sunset = mix(mix(vec3(0.06, 0.02, 0.10), vec3(0.85, 0.35, 0.10), h), vec3(1.0, 0.80, 0.45), h * h);
        fillColor = mix(fillColor, mix(sunset, baseFill, 0.25) * (1.0 + 0.4 * (0.5 + 0.5 * sin(tx * 5.0 - time * 1.5)) * effect + 0.3 * glow), effect);
    } else if (theme < 8.5) {
        // 8: Ice
        float time = t * (0.9 + (0.6 + 1.0 * effect) * uSpeed);
        float frost = 0.45 + 0.55 * abs(sin(20.0 * tx + time * 4.0) * sin(10.0 * (uvY - centerY) - time * 3.0));
        fillColor = mix(fillColor, mix(vec3(0.12, 0.60, 1.0), vec3(0.75, 1.0, 1.0), frost) * (0.9 + 0.5 * glow + 0.5 * effect * (0.6 + 0.4 * sin(tx * 35.0 + time * 6.0))), effect);
    } else if (theme < 9.5) {
        // 9: Matrix
        float time = t * (1.0 + (0.8 + 1.4 * effect) * uSpeed);
        float colIndex = floor(tx * 40.0);
        float streak = smoothstep(0.0, 0.3, 1.0 - fract(uvY * 10.0 + time * 3.0 + colIndex * 13.0));
        fillColor = mix(fillColor, mix(vec3(0.0, 0.08, 0.0), vec3(0.6, 1.0, 0.6), clamp(streak * (0.4 + 0.6 * effect) + (0.4 + 0.6 * sin(colIndex * 7.0 + time * 5.0)) * 0.15, 0.0, 1.0)) * (0.8 + 0.4 * glow + 0.6 * effect), effect);
    }

    return fillColor;
}

// --- MAIN RENDER LOGIC ---
void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 res = max(uResolution, vec2(1.0));
    vec2 uv = frag / res;
    float p = clamp(uProgress, 0.0, 1.0);
    float style = uStyle;
    float corner = clamp(uCorner, 0.0, 1.0);
    float effect = clamp(uEffectAmount, 0.0, 1.0);
    float glow = clamp(uIntensity, 0.0, 1.0);

    // Track layout
    float marginX = 12.0 / res.x;
    float trackL = marginX, trackR = 1.0 - marginX, trackW = max(trackR - trackL, 1e-4);
    float centerY = 0.5;
    float thicknessPx = max(uThickness, 1.0);
    float halfThick = 0.5 * thicknessPx / res.y;
    float tx = clamp(safeDiv(uv.x - trackL, trackW), 0.0, 1.0);

    // GÜNCELLEME: 'step' yerine 'smoothstep' kullanılarak barın üst/alt kenarlarındaki isli kırılmalar pürüzsüzleştirildi.
    float aaDist = 1.0 / res.y;
    float softY = 1.0 - smoothstep(halfThick - aaDist, halfThick + aaDist, abs(uv.y - centerY));
    float insideTrackX = smoothstep(trackL - (1.0/res.x), trackL, uv.x) * smoothstep(trackR + (1.0/res.x), trackR, uv.x);
    float trackMask = softY * insideTrackX;
    float fillMask = 0.0;

    // --- Style Logic (Mantık tamamen korundu) ---
    if (style < 0.5) { // 0: Capsule
        float trackWPx = max((trackR - trackL) * res.x, 1.0);
        float outerWidthPx = p * trackWPx;
        if (outerWidthPx > 0.0) {
            float rPx = (halfThick * res.y) * (corner * corner * (3.0 - 2.0 * corner));
            float distPx = sdRoundedRect(vec2(frag.x - (trackL * res.x + outerWidthPx * 0.5), frag.y - centerY * res.y), vec2(outerWidthPx * 0.5, halfThick * res.y), rPx);
            fillMask = (1.0 - smoothstep(-0.5, 0.5, distPx)) * softY;
        }
    } else if (style < 1.5 || (style >= 1.5 && style < 2.5)) { // 1 & 2: Segments & Steps
        float segCount = (style < 1.5) ? 16.0 : 8.0;
        float gap = mix(0.0, (style < 1.5 ? 0.9 : 0.8), uGap * uGap);
        float segT = fract(tx * segCount);
        // Segment aralarındaki isli pikselleri temizlemek için smoothstep eklendi
        float gapMask = smoothstep(gap * 0.5 - 0.01, gap * 0.5 + 0.01, segT) * smoothstep(1.0 - gap * 0.5 + 0.01, 1.0 - gap * 0.5 - 0.01, segT);
        fillMask = step(floor(tx * segCount), floor(p * segCount + 1e-3) - 1.0) * gapMask * softY;
    } else if (style < 3.5) { // 3: Centered
        float dx = abs(uv.x - 0.5 * (trackL + trackR));
        fillMask = (1.0 - smoothstep(0.5 * p * trackW - 1.0/res.x, 0.5 * p * trackW + 1.0/res.x, dx)) * softY;
    } else if (style < 4.5) { // 4: Outline
        float trackWPx = max((trackR - trackL) * res.x, 1.0);
        float outerWidthPx = p * trackWPx;
        if (outerWidthPx > 0.0) {
            vec2 pLocal = vec2(frag.x - (trackL * res.x + outerWidthPx * 0.5), frag.y - centerY * res.y);
            float rPx = halfThick * res.y * 0.7 * (corner * corner * (3.0 - 2.0 * corner));
            float distOuter = sdRoundedRect(pLocal, vec2(outerWidthPx * 0.5, halfThick * res.y), rPx);
            float borderNpx = max(1.5, (0.08 + 0.40 * corner) * thicknessPx);
            float distInner = sdRoundedRect(pLocal, max(vec2(outerWidthPx * 0.5, halfThick * res.y) - vec2(borderNpx), vec2(0.0)), max(rPx - borderNpx, 0.0));
            fillMask = clamp((1.0 - smoothstep(-0.5, 0.5, distOuter)) - (1.0 - smoothstep(-0.5, 0.5, distInner)), 0.0, 1.0) * softY;
        }
    } else { // 5: Thin
        fillMask = (1.0 - smoothstep((0.04 + 0.36 * corner) * thicknessPx / res.y - 0.5/res.y, (0.04 + 0.36 * corner) * thicknessPx / res.y + 0.5/res.y, abs(uv.y - centerY))) * step(0.0, tx) * step(tx, p) * insideTrackX;
    }

    fillMask = clamp(fillMask, 0.0, 1.0);
    vec3 baseFill = mix(uColor, uColor2, tx);
    vec3 fillColor = applyTheme(baseFill, tx, uv.y, centerY);

    // Head Glow Boost (Maske ile çarpılarak islilik önlendi)
    if (p > 0.0) {
        float headHighlight = smoothstep(mix(0.015, 0.06, effect), 0.0, abs(tx - p)) * fillMask;
        fillColor = mix(fillColor, fillColor * (1.0 + 1.5 * effect), headHighlight);
    }

    // Breathing animasyonu maskeye uygulandı
    float breath = (1.0 + mix(0.0, 0.12, glow) * sin(uTime * (0.8 + 0.4 * uSpeed)));
    float finalFillMask = fillMask * breath;

    // Track Background (SDF tabanlı pürüzsüz track)
    float tShaped = corner * corner * (3.0 - 2.0 * corner);
    float distTrack = sdRoundedRect(vec2(frag.x - 0.5 * (trackL + trackR) * res.x, frag.y - centerY * res.y), vec2(0.5 * (trackR - trackL) * res.x, halfThick * res.y), halfThick * res.y * tShaped);
    float trackShape = (1.0 - smoothstep(-0.5, 0.5, distTrack)) * insideTrackX;

    // GÜNCELLEME: Track rengi artık isli görünmemesi için alpha ile çarpılarak ön-hazırlandı.
    float finalTrackAlpha = uTrackAlpha * trackShape;
    vec3 trackBaseColor = mix(mix(uColor * 0.18, uColor2 * 0.18, tx), uTrackColor, step(0.001, max(uTrackColor.r, max(uTrackColor.g, uTrackColor.b))));
    vec3 trackLayer = trackBaseColor * finalTrackAlpha;

    // Head Orb/Spark (Alpha ve Renk ayrıştırıldı)
    vec3 headLayer = vec3(0.0); float headA = 0.0;
    if (p > 0.0 && uHeadAmount > 0.001) {
        vec2 headLocal = vec2(frag.x - mix(trackL * res.x, trackR * res.x, p), frag.y - centerY * res.y);
        float hDist = length(vec2(headLocal.x * 0.7, headLocal.y));
        float baseR = halfThick * res.y * mix(0.7, 1.8, uHeadSize) * (0.9 + 0.4 * effect);
        float coreM = 1.0 - smoothstep(baseR * 0.3, baseR * 0.55, hDist);
        float haloM = 1.0 - smoothstep(baseR * 0.55, baseR * (1.5 + 0.8 * uHeadAmount), hDist);
        float twin = (uHeadStyle < 0.5) ? 1.0 : (uHeadStyle < 1.5) ? 0.8 + 0.4 * sin(uTime * 2.5) : 0.7 + 0.3 * max(sin(uTime * 8.0 + tx * 60.0), sin(uTime * 15.0 + uv.y * 200.0));

        headA = uHeadAmount * (0.6 + 0.9 * effect) * (coreM * 0.9 + haloM * 0.4) * twin;
        headLayer = fillColor * (1.2 + 0.6 * glow) * headA;
    }

    // Glow Halo (GÜNCELLEME: 'isli cam' efekti burada toplamsal (additive) mantıkla temizlendi)
    float glowSize = mix(2.0, 12.0, glow);
    float glowShape = clamp((1.0 - smoothstep(-0.5, glowSize, distTrack)) - trackShape, 0.0, 1.0);
    // Glow'u progress'e göre sınırla
    glowShape *= ((style < 2.5 || style >= 4.5) ? smoothstep(p + 0.02, p - 0.02, tx) : (1.0 - smoothstep(0.5 * p * trackW - 0.01, 0.5 * p * trackW + 0.01, abs(uv.x - 0.5 * (trackL + trackR)))));

    float finalGlowAlpha = glow * (0.40 + 0.80 * effect) * glowShape;
    vec3 glowLayer = baseFill * (1.4 + 0.6 * glow) * finalGlowAlpha;

    // --- GÜNCELLEME: FINAL BLEND (Isli camı yok eden kritik kısım) ---
    // Premultiplied Alpha mantığı: Renkler zaten kendi alfalarıyla çarpıldı (trackLayer, headLayer vb.)
    // Bunları topluyoruz ve en sonda TOPLAM alfayı veriyoruz ama rengi bir daha alfayla ÇARPMIYORUZ.

    vec3 fillLayer = fillColor * finalFillMask;
    vec3 finalCol = trackLayer + fillLayer + glowLayer + headLayer;

    // Toplam geçirgenlik
    float finalAlpha = clamp(finalTrackAlpha + finalFillMask + (finalGlowAlpha * 0.6) + headA, 0.0, 1.0);

    if (finalAlpha < 0.003) {
        fragColor = vec4(0.0);
    } else {
        // HATA BURADAYDI: (finalCol * finalAlpha) yapılarak renk iki kez karartılıyordu.
        // DÜZELTME: finalCol zaten alfa-çarpımlı (premultiplied) bileşenlerden oluşuyor.
        fragColor = vec4(finalCol, finalAlpha);
    }
}