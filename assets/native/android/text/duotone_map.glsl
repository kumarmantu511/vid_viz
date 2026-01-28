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

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res;

  float t = uTime * uSpeed;
  float ang = radians(uAngle);
  vec2 dir = vec2(cos(ang), sin(ang));
  float ramp = clamp(0.5 + 0.5*dot(uv - 0.5, dir) + 0.2*sin((uv.x+uv.y)*6.283 + t)*uIntensity, 0.0, 1.0);
  vec3 col = mix(uColorA, uColorB, ramp);
  fragColor = vec4(col, 1.0);
}
