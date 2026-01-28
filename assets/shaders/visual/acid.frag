#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;     // paint size
uniform float uTime;           // seconds
uniform float uIntensity;      // 0..1 mix
uniform float uSpeed;          // 0.5..2.0
uniform vec3 uColor;           // base color
uniform float uBars;           // reserved
uniform float uFreq0;          // 8-band spectrum
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;          // gradient color
uniform sampler2D uTexture;    // stage texture (captured video/image)

out vec4 fragColor;

vec3 palette(float t) {
  vec3 a = vec3(0.5, 0.5, 0.5);
  vec3 b = vec3(0.5, 0.5, 0.5);
  vec3 c = vec3(1.0, 1.1, 1.0);
  vec3 d = vec3(0.263, 0.416, 0.557);
  return a + b * cos(6.28318 * (c * t + d));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag * 2.0 - uResolution.xy) / uResolution.y;
  vec2 uv0 = uv;
  vec3 finalColor = vec3(0.0);

  float time = uTime * uSpeed;

  // Build simple audio strength (used subtly)
  float low = 0.5 * (uFreq0 + uFreq1);
  float mid = (uFreq2 + uFreq3 + uFreq4) / 3.0;
  float high = (uFreq5 + uFreq6 + uFreq7) / 3.0;
  float audio = clamp(0.6*low + 0.3*mid + 0.1*high, 0.0, 1.0);

  for (float i = 0.0; i < 5.0; i += 1.0) {
    uv = fract(uv * (1.6 + 0.10*audio)) - 0.5;
    float d = length(uv);
    vec3 col = palette(length(uv0) + time);
    d = sin(d * 8.0 + time) / 8.0;
    d = abs(d);
    d = pow(0.01 / max(d, 1e-4), 1.8);
    finalColor += col * d;
  }

  // Tint with gradient color along Y and base color
  float gy = clamp(frag.y / max(uResolution.y, 1.0), 0.0, 1.0);
  vec3 grad = mix(uColor, uColor2, gy);
  vec3 effect = finalColor * mix(vec3(1.0), normalize(grad + 1e-3), 0.25);

  // Mix with stage for background-style overlay
  vec3 tex = texture(uTexture, frag / uResolution).rgb;
  vec3 finalMix = mix(tex, effect, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalMix, 1.0);
}
