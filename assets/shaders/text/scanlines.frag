#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;   // 0,1
uniform float uTime;        // 2
uniform float uIntensity;   // 3
uniform float uSpeed;       // 4
uniform float uAngle;       // 5
uniform float uThickness;   // 6
uniform vec3 uColorA;       // 7,8,9
uniform vec3 uColorB;       // 10,11,12

out vec4 fragColor;

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res; // 0..1

  float n = mix(120.0, 300.0, clamp(uThickness, 0.0, 1.0));
  float t = uTime * uSpeed;
  float lines = step(0.5, fract((uv.y + 0.01*sin(t))*n));
  float mask = mix(0.6, 1.0, lines);

  vec3 base = mix(uColorA, uColorB, uv.x);
  vec3 col = base * mix(1.0, 1.25, uIntensity) * mask;
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
