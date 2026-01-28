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

float hash(float n) { return fract(sin(n)*43758.5453); }

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = max(uResolution, vec2(1.0));
  vec2 uv = frag / res; // 0..1
  float t = uTime * uSpeed;

  // Horizontal bands with jitter
  float bands = 120.0 * (1.0 + uThickness);
  float row = floor(uv.y * bands);
  float jitter = (hash(row + floor(t*10.0)) - 0.5) * 0.1 * uIntensity;
  float offset = jitter;

  // Color phase per band
  float phase = hash(row * 13.3) * 6.2831 + t;
  float mixv = 0.5 + 0.5 * sin((uv.x + offset) * 12.0 + phase);
  vec3 base = mix(uColorA, uColorB, mixv);

  // Occasional white flicker
  float flick = step(0.98, hash(row + floor(t*7.0)));
  base = mix(base, vec3(1.0), flick * 0.2 * uIntensity);

  fragColor = vec4(base, 1.0);
}
