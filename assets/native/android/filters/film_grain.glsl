#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

float hash(vec2 p){
  // Simple hash noise
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

void main(){
  vec2 uv = FlutterFragCoord().xy / uResolution.xy;
  vec3 base = texture(uTexture, uv).rgb;

  // Animate noise with time; quantize time to avoid swimming too fast
  float t = floor(uTime * 24.0);
  float n = hash(uv * uResolution + vec2(t, t*1.37));
  n = n * 2.0 - 1.0; // [-1,1]

  // Grain amount
  float grain = mix(0.0, 0.20, clamp(uIntensity, 0.0, 1.0));
  vec3 effect = clamp(base + n * grain, 0.0, 1.0);

  vec3 finalColor = mix(base, effect, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalColor, 1.0);
}
