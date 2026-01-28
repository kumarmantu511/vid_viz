#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;   // 0,1
uniform float uTime;        // 2
uniform float uIntensity;   // 3
uniform float uSpeed;       // 4
uniform float uAngle;       // 5 (degrees)
uniform float uThickness;   // 6
uniform vec3 uColorA;       // 7,8,9
uniform vec3 uColorB;       // 10,11,12

out vec4 fragColor;

vec2 rotate(vec2 p, float a){
  float c = cos(a), s = sin(a);
  return mat2(c,-s,s,c) * p;
}

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res; // 0..1
  vec2 p = uv - 0.5;
  float ang = radians(uAngle);
  p = rotate(p, ang);

  float t = uTime * uSpeed;
  float w = 10.0 + 10.0 * uThickness; // wave frequency
  float amp = 0.15 * uIntensity;       // wave amplitude
  float y = p.y + sin(p.x * w + t) * amp;

  float g = smoothstep(-0.3, 0.3, y);
  vec3 col = mix(uColorA, uColorB, g);
  fragColor = vec4(col, 1.0);
}
