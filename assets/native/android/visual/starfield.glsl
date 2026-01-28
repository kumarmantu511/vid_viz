#version 300 es
precision highp float;
// ============================================================================
// STARFIELD SHADER - Optimized for Flutter/Impeller
// ============================================================================
// Based on: The Art of Code - Starfield Tutorial
// Optimized: Removed heavy raymarching, using layered 2D stars
// ============================================================================

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

out vec4 fragColor;

#define NUM_LAYERS 4.0

mat2 Rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

float Star(vec2 uv, float flare) {
    float d = length(uv);
    float m = .02 / d;
    
    float rays = max(0., 1. - abs(uv.x * uv.y * 1000.));
    m += rays * flare;
    uv *= Rot(3.1415 / 4.);
    rays = max(0., 1. - abs(uv.x * uv.y * 1000.));
    m += rays * .3 * flare;
    
    m *= smoothstep(1., .2, d);
    return m;
}

float Hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec3 StarLayer(vec2 uv, float audio) {
    vec3 col = vec3(0);
    
    vec2 gv = fract(uv) - .5;
    vec2 id = floor(uv);
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(x, y);
            
            float n = Hash21(id + offset);
            float size = fract(n * 345.32);
            
            // Audio reactive size boost
            size *= (1.0 + audio * 0.5);
            
            float star = Star(gv - offset - vec2(n, fract(n * 34.)) + .5, smoothstep(.8, .9, size));
            vec3 color = sin(vec3(.2, .3, .9) * fract(n * 2345.2) * 123.2) * .5 + .5;
            color = color * vec3(1., .5, 1. + size);
            col += star * size * color;
        }
    }
    return col;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = (fragCoord - .5 * uResolution.xy) / uResolution.y;
    
    // Time with speed control
    float t = uTime * clamp(uSpeed, 0.2, 2.0) * .1;
    
    // Audio energy
    float lows = (uFreq0 + uFreq1) * 0.5;
    float mids = (uFreq2 + uFreq3 + uFreq4) / 3.0;
    float audio = clamp(lows * 0.6 + mids * 0.4, 0.0, 1.0);
    
    vec3 col = vec3(0);
    
    // Layered starfield with parallax
    for (float i = 0.; i < 1.; i += 1. / NUM_LAYERS) {
        float depth = fract(i + t);
        float scale = mix(20., .5, depth);
        float fade = depth * smoothstep(1., .9, depth);
        
        // Audio reactive rotation
        vec2 rotUv = uv * Rot(audio * 0.1);
        col += StarLayer(rotUv * scale + i * 453.2, audio) * fade;
    }
    
    // Color tint from uColor/uColor2
    vec3 tint = mix(uColor, uColor2, uv.y * 0.5 + 0.5);
    tint = normalize(tint + 0.001);
    col *= mix(vec3(1.0), tint, 0.3);
    
    // Audio brightness boost
    col *= (1.0 + audio * 0.5);
    
    // Mix with texture
    vec2 texUV = fragCoord / uResolution;
    vec3 tex = texture(uTexture, texUV).rgb;
    vec3 finalColor = mix(tex, col, clamp(uIntensity, 0.0, 1.0));
    
    fragColor = vec4(finalColor, 1.0);
}
