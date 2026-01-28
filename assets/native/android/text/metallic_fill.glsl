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

float band(vec2 p){
  // layered cosine bands to mimic brushed metal
  float f = 0.0;
  f += cos(p.x*20.0) * 0.6;
  f += cos(p.x*40.0) * 0.3;
  f += cos(p.x*80.0) * 0.1;
  return f*0.5 + 0.5;
}

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res; // 0..1
  vec2 p = uv - 0.5;
  float ang = radians(uAngle);
  p = rotate(p, ang);

  float t = uTime * uSpeed;
  // scrolling to avoid static look
  p.x += 0.1 * t;

  float b = band(p);
  vec3 base = mix(uColorA, uColorB, b);

  // fake specular highlight
  float spec = pow(max(0.0, sin((p.x+p.y)*6.2831 + t)), 8.0);
  vec3 col = base + uIntensity * 0.6 * spec;
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
