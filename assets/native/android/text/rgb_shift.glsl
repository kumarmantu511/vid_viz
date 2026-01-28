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
  vec2 uv = frag / res; // 0..1

  float t = uTime * uSpeed;
  float off = 0.005 * uIntensity * (0.5 + 0.5*sin(t*3.0));
  float ang = radians(uAngle);
  vec2 dir = vec2(cos(ang), sin(ang));

  float r = clamp(uv.x + dot(dir, vec2(off, off)), 0.0, 1.0);
  float g = clamp(uv.x, 0.0, 1.0);
  float b = clamp(uv.x - dot(dir, vec2(off, off)), 0.0, 1.0);

  vec3 grad = mix(uColorA, uColorB, uv.x);
  vec3 col = vec3(grad.r * r, grad.g * g, grad.b * b);
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
