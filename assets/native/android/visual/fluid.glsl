#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;
uniform float uFreq0; uniform float uFreq1; uniform float uFreq2; uniform float uFreq3;
uniform float uFreq4; uniform float uFreq5; uniform float uFreq6; uniform float uFreq7;
uniform vec3 uColor2;
uniform sampler2D uTexture;

out vec4 fragColor;

vec2 fluid(vec2 uv, float t){
  float turbulence = 4.0;
  for (float i = 1.0; i < 8.0; i += 1.0)
  {
    uv.x += cos(uv.y * i + t) / turbulence;
    uv.y += sin(uv.x * i) / turbulence;
    uv = uv.yx;
  }
  return uv;
}

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  vec2 p = (frag / max(uResolution.y, 1.0)) * 10.0;

  float env = clamp((uFreq2+uFreq3+uFreq4)/3.0, 0.0, 1.0);
  float t = uTime * (0.6 + 0.8*uSpeed);

  vec2 f = fluid(p, t);
  float r = abs(sin(f.x)) + 0.5;
  float g = abs(sin(f.x + 2.0 + t*0.2)) - 0.2;
  float b = abs(sin(f.x + 4.0));
  vec3 col = clamp(vec3(r,g,b), 0.0, 1.0);

  vec3 grad = mix(uColor, uColor2, 0.5 + 0.5*sin(f.y*0.2));
  vec3 effect = mix(col, grad, 0.3 + 0.4*env);

  vec3 tex = texture(uTexture, uv).rgb;
  vec3 finalMix = mix(tex, effect, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalMix, 1.0);
}
