#version 300 es
precision highp float;
uniform vec2 uResolution;     // width, height
uniform float uTime;           // seconds
uniform float uIntensity;      // 0..1
uniform float uSpeed;          // 0.5..2.0
uniform vec3 uColor;           // base color
uniform float uBars;           // reserved
uniform float uFreq0;          // 8-band FFT
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;          // gradient color
uniform sampler2D uTexture;    // stage texture

out vec4 fragColor;

vec3 palette1(float t) {
  vec3 a = vec3(0.5, 0.5, 0.5);
  vec3 b = vec3(0.5, 0.5, 0.5);
  vec3 c = vec3(1.0, 1.1, 1.0);
  vec3 d = vec3(0.228, 0.416, 0.552);
  return a + b * cos(7.28318 * (c * t + d));
}

vec3 palette2(float t, float u) {
  float mu = u / 1.0;
  vec3 a = vec3(0.538 - mu, 0.358, 1.358 + mu);
  vec3 b = vec3(0.188 + mu, 0.098, 0.302);
  vec3 c = vec3(3.138 - mu, 1.428, 0.138);
  vec3 d = vec3(0.1, 0.6, 0.918);
  return a + b * cos(7.28318 * (c * t + d));
}

mat2 rotate(float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return mat2(c, -s, s, c);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag * 2.0 - uResolution.xy) / uResolution.y;
  vec2 uv0 = uv;
  vec3 finalColor = vec3(0.0);

  float time = uTime * uSpeed;

  // 3-band audio build
  float bass = 0.7 * uFreq0 + 0.3 * uFreq1;
  float mid  = (uFreq2 + uFreq3 + uFreq4) / 3.0;
  float high = (uFreq5 + uFreq6 + uFreq7) / 3.0;
  float audioLevel = clamp(bass + mid + high, 0.0, 1.0);

  float colorVariance = sin(time * 3.14159 / 4.0);
  float direction = sin(time * 3.14159 / 4.0);
  float rotationAngle = direction * smoothstep(0.0, 1.0, bass) * 1.1;

  float baseBrightness = 0.15;
  float boostBrightness = 5.0 + 1.0 * high;

  for (float i = 0.0; i < 4.0; i += 1.0) {
    uv = fract(uv * (1.2 + direction / 8.0)) - 0.5;
    uv = rotate(rotationAngle) * uv;

    float d = length(uv) * 1.3;

    vec3 col = palette2(length(uv0) + time + direction, colorVariance);

    d = sin(d * 8.0 + time + bass / 10.0);
    d = abs(d);
    d = exp((-12.0 + (bass / 0.5)) * d);

    float brightness = baseBrightness + boostBrightness * audioLevel;
    finalColor += col * d * brightness;
  }

  float gy = clamp(frag.y / max(uResolution.y, 1.0), 0.0, 1.0);
  vec3 grad = mix(uColor, uColor2, gy);
  vec3 effect = finalColor * mix(vec3(1.0), normalize(grad + 1e-3), 0.25);

  vec3 tex = texture(uTexture, frag / uResolution).rgb;
  vec3 finalMix = mix(tex, effect, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalMix, 1.0);
}
