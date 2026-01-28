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

void main(){
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  float time = uTime * uSpeed;

  float env = clamp(0.6*(uFreq0+uFreq1) + 0.4*(uFreq5+uFreq6+uFreq7)/3.0, 0.0, 1.0);
  float px = 1.5 + 2.0 * env; // pixel offset
  vec2 dir = vec2(sin(time*0.7), cos(time*0.5));
  vec2 off = dir * (px / max(uResolution, vec2(1.0)));

  float r = texture(uTexture, uv + off).r;
  float g = texture(uTexture, uv).g;
  float b = texture(uTexture, uv - off).b;
  vec3 tex = vec3(r,g,b);

  vec3 grad = mix(uColor, uColor2, uv.y);
  vec3 effect = mix(tex, grad, 0.15 + 0.25*env);
  vec3 finalMix = mix(texture(uTexture, uv).rgb, effect, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalMix, 1.0);
}
