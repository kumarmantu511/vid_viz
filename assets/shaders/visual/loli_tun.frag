#version 460 core

#include <flutter/runtime_effect.glsl>

// Loli Tunnel (Flopine) - Shadertoy port
// - Raymarched cylindrical tunnel
// - Audio (uFreq2..uFreq5) modulates color palette and rotation speed

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
uniform sampler2D uTexture;
uniform float uAspect;

out vec4 fragColor;

#define PI 3.141592
#define TAU 2.0*PI
#define ITER 60

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, s, -s, c);
}

// iq's palette
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
  return a + b * cos(6.28318 * (c * t + d));
}

vec2 moda(vec2 p, float per) {
  float angle = atan(p.y, p.x);
  float l = length(p);
  angle = mod(angle - per / 2.0, per) - per / 2.0;
  return vec2(cos(angle), sin(angle)) * l;
}

float cylZ(vec3 p, float r) {
  return length(p.xy) - r;
}

float mapScene(vec3 p) {
  p.xy *= rot(-p.z);
  p.xy = moda(p.xy, TAU / 5.0);
  p.x -= 0.5;
  return cylZ(p, 0.3);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = uResolution;
  vec2 uv = 2.0 * (frag / res) - 1.0;
  uv.x *= res.x / max(res.y, 1.0);

  // Audio bands
  float mid = (uFreq2 + uFreq3 + uFreq4 + uFreq5) * 0.25;
  float bass = (uFreq0 + uFreq1) * 0.5;
  float time = uTime * uSpeed;

  float shad = 1.0;
  vec3 p = vec3(0.001, 0.001, -time * (0.3 + 0.4 * mid));
  vec3 dir = normalize(vec3(uv, 1.0));

  for (int i = 0; i < ITER; i++) {
    float d = mapScene(p);
    if (d < 0.001) {
      shad = float(i) / float(ITER);
      break;
    }
    p += dir * d;
  }

  vec3 pal = palette(
    p.z,
    vec3(0.0, 0.5, 0.5),
    vec3(0.5),
    vec3(5.0),
    vec3(0.0, 0.1, time * (0.2 + 0.4 * bass))
  );

  vec3 col = (1.0 - shad) * pal * 2.0;

  // Slight audio-driven brightness & contrast
  float audio = clamp(0.6 * bass + 0.4 * mid, 0.0, 1.0);
  col *= 0.9 + 1.4 * audio;

  // Mix with stage for visual mode
  vec2 uvStage = frag / res;
  vec3 stage = texture(uTexture, uvStage).rgb;
  vec3 finalMix = mix(stage, col, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalMix, 1.0);
}
