#version 460 core

#include <flutter/runtime_effect.glsl>

// Plasma Wave Grid - Shadertoy port
// - Animated plasma grid with circles
// - Audio (uFreq0..uFreq7) modulates wave amplitude and line brightness

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;
uniform sampler2D uTexture;
uniform float uAspect;

out vec4 fragColor;

const float overallSpeed = 0.2;
const float gridSmoothWidth = 0.015;
const float axisWidth = 0.05;
const float majorLineWidth = 0.025;
const float minorLineWidth = 0.0125;
const float majorLineFrequency = 5.0;
const float minorLineFrequency = 1.0;
const vec4 gridColor = vec4(0.5);
const float scaleFactor = 5.0;
const vec4 baseLineColor = vec4(0.25, 0.5, 1.0, 1.0);
const float minLineWidth = 0.02;
const float maxLineWidth = 0.5;
const float lineAmplitudeBase = 1.0;
const float lineFrequency = 0.2;
const float warpFrequency = 0.5;
const float warpAmplitudeBase = 1.0;
const float offsetFrequency = 0.5;
const float minOffsetSpread = 0.6;
const float maxOffsetSpread = 2.0;
const int linesPerGroup = 16;

#define drawCircle(pos, radius, coord) smoothstep(radius + gridSmoothWidth, radius, length((coord) - (pos)))
#define drawSmoothLine(pos, halfWidth, t) smoothstep(halfWidth, 0.0, abs((pos) - (t)))
#define drawCrispLine(pos, halfWidth, t) smoothstep((halfWidth) + gridSmoothWidth, (halfWidth), abs((pos) - (t)))
#define drawPeriodicLine(freq, width, t) drawCrispLine((freq) / 2.0, (width), abs(mod((t), (freq)) - (freq) / 2.0))

float drawGridLines(float axis) {
  return   drawCrispLine(0.0, axisWidth, axis)
         + drawPeriodicLine(majorLineFrequency, majorLineWidth, axis)
         + drawPeriodicLine(minorLineFrequency, minorLineWidth, axis);
}

float drawGrid(vec2 space) {
  return min(1.0, drawGridLines(space.x) + drawGridLines(space.y));
}

// Cheap pseudo-random
float random(float t) {
  return (cos(t) + cos(t * 1.3 + 1.3) + cos(t * 1.4 + 1.4)) / 3.0;
}

float getPlasmaY(float x, float horizontalFade, float offset, float time, float lineAmp) {
  return random(x * lineFrequency + time) * horizontalFade * lineAmp + offset;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 res = uResolution;
  vec2 uv = frag / res;

  // Audio summary
  float low = 0.5 * (uFreq0 + uFreq1);
  float mid = (uFreq2 + uFreq3 + uFreq4) / 3.0;
  float high = (uFreq5 + uFreq6 + uFreq7) / 3.0;
  float audio = clamp(0.5 * low + 0.3 * mid + 0.2 * high, 0.0, 1.0);

  float t = uTime * overallSpeed * uSpeed;

  vec2 space = (frag - res / 2.0) / res.x * 2.0 * scaleFactor;

  float horizontalFade = 1.0 - (cos(uv.x * 6.28318) * 0.5 + 0.5);
  float verticalFade = 1.0 - (cos(uv.y * 6.28318) * 0.5 + 0.5);

  // Audio affects turbulence and warp amount
  float warpAmp = warpAmplitudeBase * (0.5 + audio);

  space.y += random(space.x * warpFrequency + t * 0.2) * warpAmp * (0.5 + horizontalFade);
  space.x += random(space.y * warpFrequency + t * 0.2 + 2.0) * warpAmp * horizontalFade;

  vec4 lines = vec4(0.0);

  float lineAmp = lineAmplitudeBase * (0.7 + 0.8 * audio);

  for (int l = 0; l < linesPerGroup; l++) {
    float normalizedLineIndex = float(l) / float(linesPerGroup);
    float offsetTime = t * 1.33;
    float offsetPosition = float(l) + space.x * offsetFrequency;
    float rand = random(offsetPosition + offsetTime) * 0.5 + 0.5;
    float halfWidth = mix(minLineWidth, maxLineWidth, rand * horizontalFade) / 2.0;
    float offsetSpread = mix(minOffsetSpread, maxOffsetSpread, horizontalFade);
    float offset = random(offsetPosition + offsetTime * (1.0 + normalizedLineIndex)) * offsetSpread;
    float linePos = getPlasmaY(space.x, horizontalFade, offset, t, lineAmp);
    float line = drawSmoothLine(linePos, halfWidth, space.y) / 2.0
               + drawCrispLine(linePos, halfWidth * 0.15, space.y);

    float circleX = mod(float(l) + t, 25.0) - 12.0;
    vec2 circlePos = vec2(circleX, getPlasmaY(circleX, horizontalFade, offset, t, lineAmp));
    float circle = drawCircle(circlePos, 0.01, space) * 4.0;

    line = line + circle;
    vec4 lc = baseLineColor;
    lc.rgb *= 0.8 + rand * 0.6 + audio * 0.6;
    lines += line * lc * rand;
  }

  // Background gradient tinted with uColor/uColor2
  vec4 bg = mix(vec4(baseLineColor.rgb * 0.5, 1.0),
                vec4(baseLineColor.rgb - vec3(0.2, 0.2, 0.7), 1.0),
                uv.x);
  bg.rgb *= verticalFade;

  vec3 grad = mix(uColor, uColor2, uv.y);
  bg.rgb = mix(bg.rgb, normalize(grad + 1e-3), 0.25);

  vec3 col = bg.rgb + lines.rgb;

  // Slight extra brightness from audio
  col *= 0.9 + 0.8 * audio;

  // Mix with stage
  vec3 stage = texture(uTexture, frag / res).rgb;
  vec3 finalMix = mix(stage, col, clamp(uIntensity, 0.0, 1.0));
  fragColor = vec4(finalMix, 1.0);
}
