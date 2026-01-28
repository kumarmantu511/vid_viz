#version 300 es
precision highp float;
uniform vec2 uResolution;   // 0,1
uniform float uTime;        // 2
uniform float uIntensity;   // 3
uniform float uSpeed;       // 4
uniform float uAngle;       // 5
uniform float uThickness;   // 6
uniform vec3 uColorA;       // 7,8,9
uniform vec3 uColorB;       // 10,11,12

out vec4 fragColor;

float hash(vec2 p){
  p = fract(p*vec2(123.34, 345.45));
  p += dot(p, p+34.45);
  return fract(p.x*p.y);
}

float noise(vec2 p){
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash(i);
  float b = hash(i+vec2(1.0,0.0));
  float c = hash(i+vec2(0.0,1.0));
  float d = hash(i+vec2(1.0,1.0));
  vec2 u = f*f*(3.0-2.0*f);
  return mix(a,b,u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
}

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res;

  float t = uTime * uSpeed;
  float ang = radians(uAngle);
  vec2 dir = vec2(cos(ang), sin(ang));
  float n = noise(uv*vec2(6.0 + 8.0*uThickness) + dir*t);
  vec3 base = mix(uColorA, uColorB, uv.x);
  vec3 col = mix(base, base*1.4, n*uIntensity);
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
