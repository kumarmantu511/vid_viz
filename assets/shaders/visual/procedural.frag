#version 460 core

#include <flutter/runtime_effect.glsl>

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

out vec4 fragColor;

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  float t = uTime * (0.8 + 0.4*uSpeed);

  vec2 p = uv;
  vec2 col = uv * 20.0;
  for (float i = 1.0; i < 4.0; i += 1.0) {
    p += col;
    col = cos(p.yx * i + t);
  }
  vec3 pattern = vec3(col, 1.0);
  vec3 grad = mix(uColor, uColor2, uv.y);
  vec3 effect = mix(grad, pattern, 0.5);

  vec3 tex = texture(uTexture, uv).rgb;
  vec3 finalMix = mix(tex, effect, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalMix, 1.0);
}
