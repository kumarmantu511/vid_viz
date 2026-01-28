#version 300 es
precision highp float;
uniform vec2 uResolution;   // 0,1
uniform float uTime;        // 2
uniform float uIntensity;   // 3
uniform float uSpeed;       // 4
uniform float uAngle;       // 5 (degrees)
uniform float uThickness;   // 6 (unused)
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
  float g = 0.5 + 0.5 * sin(p.x * 6.2831 + t);
  vec3 col = mix(uColorA, uColorB, g);
  col = mix(col, (uColorA+uColorB)*0.5, 1.0 - clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(col, 1.0);
}
