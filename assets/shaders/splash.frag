#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

// --- YARDIMCI FONKSİYONLAR ---

mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// --- HARF ÇİZİMİ ---
float charV(vec2 p) {
    return min(sdSegment(p, vec2(-0.07, 0.1), vec2(0.0, -0.1)),
               sdSegment(p, vec2(0.0, -0.1), vec2(0.07, 0.1)));
}
float charI(vec2 p) { return sdSegment(p, vec2(0.0, 0.1), vec2(0.0, -0.1)); }
float charD(vec2 p) {
    float d = sdSegment(p, vec2(-0.06, 0.1), vec2(-0.06, -0.1));
    d = min(d, sdSegment(p, vec2(-0.06, 0.1), vec2(0.02, 0.07)));
    d = min(d, sdSegment(p, vec2(0.02, 0.07), vec2(0.02, -0.07)));
    d = min(d, sdSegment(p, vec2(0.02, -0.07), vec2(-0.06, -0.1)));
    return d;
}
float charZ(vec2 p) {
    float d = sdSegment(p, vec2(-0.06, 0.1), vec2(0.06, 0.1));
    d = min(d, sdSegment(p, vec2(0.06, 0.1), vec2(-0.06, -0.1)));
    d = min(d, sdSegment(p, vec2(-0.06, -0.1), vec2(0.06, -0.1)));
    return d;
}

// YAZI ÇİZİMİ
float getText(vec2 p) {
    float d = 100.0;
    p.y += 0.65; // Yazı Konumu
    p.x += 0.50; // Ortalama
    float spacing = 0.20;

    d = min(d, charV(p)); p.x -= spacing;
    d = min(d, charI(p)); p.x -= spacing;
    d = min(d, charD(p)); p.x -= spacing;
    d = min(d, charV(p)); p.x -= spacing;
    d = min(d, charI(p)); p.x -= spacing;
    d = min(d, charZ(p));
    return d;
}

// --- AURORA (KUZEY IŞIKLARI) EFEKTİ ---
float aurora(vec2 uv, float time) {
    vec2 p = uv * 2.0;
    float color = 0.0;
    for(float i = 1.0; i < 4.0; i++) {
        p.x += sin(p.y + time * 0.5) * 0.5;
        float w = abs(1.0 / (sin(p.x + time * 0.2) + 2.0 * i));
        color += w;
    }
    return color * 0.2;
}

void main() {
    // 1. KOORDİNATLAR
    vec2 uv = (FlutterFragCoord().xy - 0.5 * uResolution.xy) / uResolution.y;

    // KOORDİNAT SİSTEMİNİ DÜZELTME
    uv.y *= -1.0;
    uv *= 3.0; // Zoom

    // Arka plan koordinatı
    vec2 bgUV = uv;

    // --- ARKA PLAN ---
    vec3 bgCol = vec3(0.01, 0.0, 0.05);

    // Aurora Efekti
    float aur = aurora(bgUV + vec2(0.0, uTime * 0.1), uTime);
    bgCol += vec3(0.2, 0.0, 0.8) * aur;
    bgCol += vec3(0.0, 0.5, 1.0) * aur * 0.5;

    // Yıldızlar
    float particles = 0.0;
    for(float i=0.0; i<5.0; i++) {
        float size = 4.0 + i * 2.0;
        vec2 pPos = bgUV;
        pPos.y += uTime * (0.05 + i * 0.02);
        pPos.x += sin(uTime * 0.2 + i) * 0.2;

        vec2 id = floor(pPos * size);
        vec2 gv = fract(pPos * size) - 0.5;

        float n = hash(id);
        if(n > 0.9) {
            float dP = length(gv);
            float spark = 0.02 / (dP + 0.001);
            spark *= 0.5 + 0.5 * sin(uTime * 4.0 + n * 10.0);
            particles += spark * 0.3;
        }
    }
    bgCol += vec3(0.6, 0.8, 1.0) * particles;

    // --- LOGO KOORDİNATI VE DÜZELTME ---
    vec2 logoUV = uv;
    logoUV.y -= 0.3;
    logoUV.y *= -1.0;

    // --- LOGO ANİMASYONU ---
    float hover = sin(uTime * 1.0) * 0.05;
    logoUV.y += hover;

    float pulse = 1.0 + sin(uTime * 3.0) * 0.02;
    vec2 p = logoUV / pulse;

    // --- LOGO ÇİZİMİ ---
    // Sol Bacak
    vec2 pL = p; pL.x += 0.15; pL.y -= 0.02; pL *= rot(0.45);
    float dLeft = sdRoundedBox(pL, vec2(0.11, 0.45), 0.1);

    // Sağ Bacak
    vec2 pR = p; pR.x -= 0.15; pR.y -= 0.02; pR *= rot(-0.45);
    float dRight = sdRoundedBox(pR, vec2(0.11, 0.45), 0.1);

    // Renkler
    vec3 colL = mix(vec3(0.6, 0.0, 1.0), vec3(0.3, 0.0, 0.8), -p.y + 0.5);
    vec3 colR = mix(vec3(0.0, 0.8, 1.0), vec3(0.0, 0.4, 0.9), -p.y + 0.5);

    vec3 finalColor = vec3(0.0);
    float maskL = smoothstep(0.005, 0.0, dLeft);
    float maskR = smoothstep(0.005, 0.0, dRight);

    finalColor += colL * maskL;
    vec3 blendColor = mix(finalColor, colR, 0.8);
    finalColor = mix(finalColor, blendColor, maskR);

    float intersection = maskL * maskR;
    finalColor += vec3(0.5, 0.8, 1.0) * intersection * 0.4;

    // Ses Dalgası
    vec2 wUV = p; wUV.y += 0.25;
    float waveY = sin(wUV.x * 18.0 + uTime * 8.0) * 0.06 * (sin(uTime)*0.3+0.8);
    float dWave = abs(wUV.y - waveY);
    float waveLine = smoothstep(0.02, 0.005, dWave);
    float logoMask = max(maskL, maskR);
    float fadeSides = smoothstep(0.45, 0.0, abs(wUV.x));
    finalColor += vec3(0.7, 0.95, 1.0) * waveLine * logoMask * fadeSides * 2.0;

    // Glow
    float dist = min(dLeft, dRight);
    float glowIntensity = 0.015 / (abs(dist) + 0.002);
    vec3 glowColor = mix(vec3(0.5, 0.0, 1.0), vec3(0.0, 0.8, 1.0), 0.5 + 0.5 * sin(uTime));
    float outerGlow = glowIntensity * (1.0 - logoMask * 0.8);
    finalColor += glowColor * outerGlow;

    // --- YAZI ÇİZİMİ VE PARLAMA ---
    vec2 textUV = uv;
    float dText = getText(textUV);

    float textAlpha = smoothstep(0.01, 0.001, dText);
    float textGlow = 0.008 / (abs(dText) + 0.001);

    vec3 textColor = vec3(1.0);
    vec3 textGlowCol = vec3(0.0, 0.8, 1.0);

    vec3 finalTextElement = (textColor * textAlpha) + (textGlowCol * textGlow * 0.8);

    // --- BURASI EKLENDİ: JİLET PARLAMASI (SHEEN EFFECT) ---
    float shineSpeed = uTime * 2.5; // Hız
    float shineBand = textUV.x * 1.5 + textUV.y * 0.5; // Çapraz eksen

    // Keskin, jilet gibi ince ışık çizgisi
    float shineVal = smoothstep(-0.2, 0.2, sin(shineBand - shineSpeed));
    shineVal = pow(shineVal, 30.0); // 30.0 değeri keskinliği artırır

    vec3 shineColor = vec3(0.8, 0.4, 1.0) * 2.0; // Parlak Mor

    // Işığı yazıya ekle (sadece yazı üzerinde)
    finalTextElement += shineColor * shineVal * textAlpha;
    // -----------------------------------------------------

    // --- BİRLEŞTİRME ---
    vec3 foreground = finalColor + finalTextElement;
    float alpha = clamp(maskL + maskR + outerGlow + textAlpha + textGlow, 0.0, 1.0);

    vec3 pixel = mix(bgCol, foreground, alpha);
    pixel += finalTextElement * 0.5;

    // Vignette
    pixel *= 1.0 - dot(uv * 0.35, uv * 0.35);

    fragColor = vec4(pixel, 1.0);
}