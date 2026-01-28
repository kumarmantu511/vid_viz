#version 300 es
precision highp float;
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

uniform float uGlow;
uniform float uBarFill;
uniform sampler2D iChannel0;
out vec4 fragColor;

vec3 iResolution;
float iTime;

float _vidvizSample8(float x) {
    x = clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float f0 = (i0 < 0.5) ? uFreq0 : (i0 < 1.5) ? uFreq1 : (i0 < 2.5) ? uFreq2 : (i0 < 3.5) ? uFreq3 :
    (i0 < 4.5) ? uFreq4 : (i0 < 5.5) ? uFreq5 : (i0 < 6.5) ? uFreq6 : uFreq7;
    float f1 = (i1 < 0.5) ? uFreq0 : (i1 < 1.5) ? uFreq1 : (i1 < 2.5) ? uFreq2 : (i1 < 3.5) ? uFreq3 :
    (i1 < 4.5) ? uFreq4 : (i1 < 5.5) ? uFreq5 : (i1 < 6.5) ? uFreq6 : uFreq7;
    return mix(f0, f1, t);
}

vec4 _vidvizTexture(sampler2D s, vec2 uv) {
    float v = _vidvizSample8(uv.x);
    return vec4(v, v, v, 1.0);
}

#define texture(s, uv) _vidvizTexture(s, uv)

const float
XFill    = .4,
BarWidth = .0225,
YOffset  = .33;

vec3 bouncingBars(vec2 p, out float alpha) {
    float
    antiAlias   = (sqrt(2.) / iResolution.y) * 1.5,
    aspectScale = XFill * iResolution.x / iResolution.y;

    vec3 color = vec3(0);
    alpha = 0.0;

    // Zoom out (daha küçük görünür)
    p *= 0.55; // Değeri artırarak daha fazla zoom out yapabilirsiniz

    // Pozisyonu alta kaydır
    p.y += -0.85; // Bu değeri artırarak daha aşağı alabilirsiniz

    p /= aspectScale;
    p.y += YOffset / aspectScale;

    // Y eksenini ters çevir
    p.y = -p.y;

    vec2 normalizedPos = (1. + p) * 0.5;

    float barCount = max(uBars, 1.0);
    float barStep = 1.0 / barCount;
    float fill = clamp(uBarFill > 0.0 ? uBarFill : 0.8, 0.05, 1.0);
    float barWidth = barStep * fill;

    float barIndex = round(normalizedPos.x / barStep) * barStep;

    if (barIndex >= 0. && barIndex <= 1.) {

        vec2 localPos = vec2(
        normalizedPos.x - barIndex,
        abs(normalizedPos.y - 0.5)
        );

        float amplitude = texture(iChannel0, vec2(barIndex, .25)).x;
        amplitude = amplitude * sqrt(barIndex + .2) * 2.5 / aspectScale - .25;
        amplitude *= clamp(uIntensity, 0.5, 2.0);

        localPos.y -= amplitude * 0.3;

        if (normalizedPos.y < 0.5) return color;

        float distanceToBar =
        aspectScale * ((localPos.y > 0. ? length(localPos) : abs(localPos.x)) - barWidth * 0.4);

        float barMaskAA = smoothstep(antiAlias, -antiAlias, distanceToBar);

        color = mix(
        color,
        (1. + sin(abs(p.y) - iTime + 2. * p.x + vec3(0, 1, 2))) * (0.05 + sign(p.y)),
        smoothstep(antiAlias, -antiAlias, distanceToBar)
        );

        vec3 tint = mix(uColor, uColor2, clamp(normalizedPos.y, 0.0, 1.0));
        color *= tint;

        float glow = clamp(uGlow, 0.0, 1.0);
        float glowShaped = pow(glow, 0.6);
        float inner = 0.0;
        if (glowShaped > 0.001 && barMaskAA > 0.001) {
            // Keep units consistent: distanceToBar is evaluated in the same space as antiAlias.
            float w = antiAlias * mix(1.0, 14.0, glowShaped);
            float dIn = max(-distanceToBar, 0.0);
            inner = exp(-dIn / max(w, 1e-6));
        }
        color *= (1.0 + glowShaped * 1.4 * inner);

        alpha = barMaskAA;
    }

    return color;
}

void mainImage(out vec4 O, vec2 C) {
    vec2 p = (C + C - iResolution.xy) / iResolution.y;
    float alpha;
    vec3 col = bouncingBars(p, alpha);
    O = vec4(col * alpha, alpha);
}

void main() {
    iResolution = vec3(uResolution, 1.0);
    iTime = uTime * uSpeed;
    mainImage(fragColor, FlutterFragCoord().xy);
}