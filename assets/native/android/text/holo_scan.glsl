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
  // hologram scan: moving bright line + chroma tint
  float line = exp(-pow((uv.y - fract(t))*30.0, 2.0)) * uIntensity;
  vec3 base = mix(uColorA, uColorB, uv.x);
  vec3 col = base + vec3(0.1, 0.2, 0.3) * line;
  col += 0.08 * vec3(sin(uv.y*200.0 + t), sin(uv.y*160.0 + t*1.2), sin(uv.y*120.0 + t*1.4)) * uIntensity;
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
