#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution.xy;

  // Radial direction from center for aberration offset
  vec2 dir = (uv - 0.5) * 2.0;
  float amount = 0.01 + 0.04 * clamp(uIntensity, 0.0, 1.0);
  vec2 off = dir * amount;

  // Clamp UV to avoid sampling outside
  vec2 uvR = clamp(uv + off, 0.0, 1.0);
  vec2 uvG = uv;
  vec2 uvB = clamp(uv - off, 0.0, 1.0);

  float r = texture(uTexture, uvR).r;
  float g = texture(uTexture, uvG).g;
  float b = texture(uTexture, uvB).b;
  vec3 effect = vec3(r, g, b);

  vec3 base = texture(uTexture, uv).rgb;
  vec3 finalColor = mix(base, effect, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalColor, 1.0);
}
