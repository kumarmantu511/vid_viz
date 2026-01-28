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
  float amp = 0.03 * uIntensity;
  float freq = 8.0 + 10.0*uThickness;
  vec2 wob = vec2(sin((uv.y*freq + t)*1.2), cos((uv.x*freq - t)*0.9)) * amp;
  vec2 uvd = uv + wob + dir * amp * sin((uv.x+uv.y)*freq*0.5 + t);
  vec3 col = mix(uColorA, uColorB, clamp(uvd.x, 0.0, 1.0));
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
