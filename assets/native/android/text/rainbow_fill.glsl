#version 300 es
precision highp float;
uniform vec2 uResolution;   // 0,1
uniform float uTime;        // 2
uniform float uIntensity;   // 3
uniform float uSpeed;       // 4
uniform float uAngle;       // 5 (degrees)
uniform float uThickness;   // 6
uniform vec3 uColorA;       // 7,8,9 (unused)
uniform vec3 uColorB;       // 10,11,12 (unused)

out vec4 fragColor;

vec2 rotate(vec2 p, float a){
  float c = cos(a), s = sin(a);
  return mat2(c,-s,s,c) * p;
}

vec3 hsv2rgb(vec3 c){
  vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0/3.0, 1.0/3.0))*6.0 - 3.0);
  vec3 rgb = clamp(p - 1.0, 0.0, 1.0);
  return c.z * mix(vec3(1.0), rgb, c.y);
}

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res; // 0..1
  vec2 p = uv - 0.5;
  float ang = radians(uAngle);
  p = rotate(p, ang);

  float t = uTime * uSpeed;
  float stripe = p.x * (8.0 + 16.0 * uThickness) + t;
  float hue = fract(stripe);
  float sat = 0.8 + 0.2 * uIntensity;
  float val = 0.85 + 0.15 * sin(t*2.0);
  vec3 col = hsv2rgb(vec3(hue, sat, val));

  fragColor = vec4(col, 1.0);
}
