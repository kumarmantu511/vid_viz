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

float bevel(vec2 p){
  // simple beveled height using layered abs(sin()) bands
  float f = 0.0;
  float w = 20.0 + 40.0 * clamp(uThickness, 0.0, 5.0);
  p = rotate(p, radians(uAngle));
  f += abs(sin(p.x*w))*0.6;
  f += abs(sin(p.y*w*0.7))*0.4;
  return clamp(f, 0.0, 1.5);
}

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res; // 0..1
  vec2 p = uv - 0.5;

  float t = uTime * uSpeed;
  p += 0.02 * vec2(sin(t), cos(t));

  float b = bevel(p);
  vec3 base = mix(uColorA, uColorB, smoothstep(0.2, 1.0, b));

  // specular-ish highlight
  float spec = pow(max(0.0, sin((p.x+p.y)*12.0 + t)), 10.0);
  vec3 col = base + spec * (0.2 + 0.6 * uIntensity);
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
