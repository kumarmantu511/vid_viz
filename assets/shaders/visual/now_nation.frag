#version 460 core

#include <flutter/runtime_effect.glsl>

// ============================================================================
// NOW NATION SHADER - Pro Nation'in Alternatif Versiyonu
// ============================================================================
// Pro Nation ile ayni performans, farkli gorsel stil
// Daha buyuk daire, farkli halka stili
// ============================================================================

// --- UNIFORM TANIMLARI (pro_nation ile ayni) ---
uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;
uniform float uFreq0; uniform float uFreq1; uniform float uFreq2; uniform float uFreq3;
uniform float uFreq4; uniform float uFreq5; uniform float uFreq6; uniform float uFreq7;
uniform vec3 uColor2;
uniform sampler2D uTexture;
uniform float uAspect;

// --- OVERLAY (pro_nation ile ayni) ---
uniform sampler2D uCenterImg;
uniform sampler2D uBgImg;
uniform float uHasCenter;
uniform float uHasBg;
uniform vec3 uRingColor;
uniform float uHasRingColor;

out vec4 fragColor;

// --- SABITLER (farkli stil icin ayarlanmis) ---
const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;
const float CIRCLE_RADIUS = 0.18;        // Pro'dan buyuk daire
const float CIRCLE_BORDER_SIZE = 0.012;
const float FFT_SMOOTHING = 0.7;

// --- SPEKTRUM RENKLERI (farkli palet) ---
const vec3 RING_COLORS[6] = vec3[](
  vec3(0.0, 1.0, 1.0),   // Cyan
  vec3(0.0, 0.5, 1.0),   // Mavi
  vec3(0.5, 0.0, 1.0),   // Mor
  vec3(1.0, 0.0, 0.5),   // Pembe
  vec3(1.0, 0.3, 0.0),   // Turuncu
  vec3(1.0, 1.0, 0.0)    // Sari
);

// --- YARDIMCI FONKSIYONLAR ---
vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 rotate(vec2 v, float a) {
  float s = sin(a), c = cos(a);
  return mat2(c, s, -s, c) * v;
}

float sampleFFT(float t) {
  float bands[8];
  bands[0]=uFreq0; bands[1]=uFreq1; bands[2]=uFreq2; bands[3]=uFreq3;
  bands[4]=uFreq4; bands[5]=uFreq5; bands[6]=uFreq6; bands[7]=uFreq7;
  float x = clamp(t, 0.0, 1.0) * 7.0;
  int i0 = int(floor(x));
  int i1 = min(7, i0 + 1);
  float f = fract(x);
  f = f * f * (3.0 - 2.0 * f);  // Smoothstep
  float raw = mix(bands[i0], bands[i1], f);
  return smoothstep(0.0, 1.0, raw) * FFT_SMOOTHING + raw * (1.0 - FFT_SMOOTHING);
}

// --- ANA SHADER ---
void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  vec2 p = (frag - 0.5 * uResolution) / max(uResolution.y, 1.0);
  
  // 180 derece dondur
  p = rotate(p, PI);
  uv = 1.0 - uv;
  
  float t = uTime * (0.8 + 0.6 * uSpeed);
  float bass = clamp((uFreq0 + uFreq1 + uFreq2) / 3.0, 0.0, 1.0);
  
  // === ARKAPLAN ===
  vec3 color;
  if (uHasBg > 0.5) {
    float bgPulse = 1.0 + bass * 0.03;
    vec2 bgUV = (uv - 0.5) / bgPulse + 0.5;
    bgUV.y = 1.0 - bgUV.y;
    color = texture(uBgImg, clamp(bgUV, 0.0, 1.0)).rgb * (1.0 + bass * 0.15);
  } else {
    // Kozmik gradient
    float dist = length(p);
    float hue1 = fract(uTime * 0.015 + 0.6);
    float hue2 = fract(uTime * 0.02 + 0.3);
    vec3 c1 = hsv2rgb(vec3(hue1, 0.7, 0.35 + bass * 0.25));
    vec3 c2 = hsv2rgb(vec3(hue2, 0.8, 0.1 + bass * 0.1));
    color = mix(c1, c2, smoothstep(0.0, 0.7, dist));
    
    // Yildizlar
    float star = hash12(floor(uv * 35.0 + uTime * 0.2));
    float starMask = smoothstep(0.95, 0.98, star);
    color += vec3(0.2 * starMask * (0.5 + 0.5 * sin(uTime * 4.0 + star * 50.0)));
  }
  
  // === PARCACIKLAR (optimize) ===
  float bassP = 0.5 + bass * 0.5;
  for (int i = 0; i < 25; ++i) {
    float fi = float(i);
    float k = hash12(vec2(fi, fi * 1.37));
    float z = fract(1.0 - (t * 0.12 + k));
    float size = (1.0 - z) * 0.018;
    vec2 base = vec2(sin(fi * 12.9 + k * 7.0), cos(fi * 78.2 + k * 3.0)) * (0.5 + 0.7 * k);
    vec2 proj = base / (0.3 + 1.5 * z);
    vec3 pCol = hsv2rgb(vec3(fract(k + uTime * 0.08), 0.5, 1.0));
    float d1 = length(p - proj);
    float d2 = length(p + proj);
    float g1 = smoothstep(size, 0.0, d1);
    float g2 = smoothstep(size, 0.0, d2);
    color += pCol * (g1 + g2) * bassP * 0.6;
  }
  
  // === POLAR KOORDINATLAR ===
  vec2 polar = vec2(atan(p.x, p.y) / TWO_PI + 0.5, length(p));
  float fftx = polar.x * 2.0;
  if (fftx > 1.0) fftx = 2.0 - fftx;
  fftx = 1.0 - fftx;
  
  float rGrow = bass * 0.04;
  
  // === SPEKTRUM HALKALARI (6 halka) ===
  for (int i = 0; i < 6; ++i) {
    float fi = float(i);
    float gain = 0.06 * (1.0 - fi * 0.1);
    float thick = 0.015 - fi * 0.001;
    float fftv = sampleFFT(fftx);
    fftv = mix(fftv, smoothstep(0.0, 0.7, fftv), 0.5);
    float radius = CIRCLE_RADIUS + rGrow + fftv * gain - fi * 0.008;
    
    // Halka rengi
    vec3 ringCol;
    if (uHasRingColor > 0.5) {
      ringCol = uRingColor;
    } else {
      ringCol = RING_COLORS[i];
    }
    
    float ring = smoothstep(thick, 0.0, abs(polar.y - radius));
    color = mix(color, ringCol, ring * 0.85);
  }
  
  // === IC DAIRE ===
  float innerR = CIRCLE_RADIUS + rGrow - CIRCLE_BORDER_SIZE;
  float innerMask = smoothstep(innerR + 0.005, innerR - 0.005, polar.y);
  
  if (uHasCenter > 0.5 && innerMask > 0.01) {
    float pulse = 1.0 + bass * 0.05;
    vec2 cUV = p / max(innerR * pulse, 0.0001) * 0.5 + 0.5;
    cUV.y = 1.0 - cUV.y;
    vec4 cTex = texture(uCenterImg, clamp(cUV, 0.0, 1.0));
    color = mix(color, cTex.rgb * (1.0 + bass * 0.2), innerMask * cTex.a);
  } else {
    // Animasyonlu gradient
    vec2 inner = p / max(innerR, 0.0001);
    float iDist = length(inner);
    float iAngle = atan(inner.y, inner.x);
    float hue = fract(uTime * 0.04 + sin(iAngle * 2.0 + uTime) * 0.1);
    float val = mix(0.9, 0.15, smoothstep(0.0, 1.0, iDist)) * (1.0 + bass * 0.5);
    vec3 iCol = hsv2rgb(vec3(hue, 0.6, val));
    iCol += vec3(smoothstep(0.6, 0.0, iDist) * (0.25 + bass * 0.25));
    color = mix(color, iCol, innerMask);
  }
  
  // === SON ISLEMLER ===
  color += bass * 0.04;
  color *= smoothstep(0.0, 1.0, 1.8 - length(p));
  
  vec3 stage = texture(uTexture, uv).rgb;
  fragColor = vec4(mix(stage, color, clamp(uIntensity, 0.0, 1.0)), 1.0);
}
