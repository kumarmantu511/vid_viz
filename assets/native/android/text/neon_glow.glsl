#version 300 es
precision highp float;
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
  float band = 0.5 + 0.5 * sin(p.x * (12.0 + 20.0 * uThickness) + t*2.0);
  vec3 base = mix(uColorA, uColorB, band);

  float pulse = 0.7 + 0.3 * sin(t*3.0);
  float glow = smoothstep(0.2, 1.0, band) * (0.6 + 0.4 * sin(t + p.y*8.0));

  vec3 col = base * (1.0 + uIntensity * 0.8) * mix(1.0, 1.3, glow) * pulse;
  fragColor = vec4(min(col, vec3(1.0)), 1.0);
}
