#version 300 es
precision highp float;
uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

// shadertoy compat
#define iResolution uResolution
#define iTime uTime
#define iChannel0 uTexture

// basit deterministik noise (cheap)
float rnd(vec2 v) {
    return fract(sin(dot(v, vec2(12.9898,78.233))) * 43758.5453123);
}

// clamp helpers
float sat(float x){ return clamp(x, 0.0, 1.0); }
vec2 sat(vec2 v){ return clamp(v, 0.0, 1.0); }

// basit spektral ağırlık fonksiyonu
vec3 spectrum_weights(float t) {
    // t in [0,1] -> wider red left, green center, blue right
    float r = sat(1.0 - smoothstep(0.0, 0.6, t));
    float b = sat(smoothstep(0.4, 1.0, t));
    float g = sat(1.0 - abs(t - 0.5) * 2.0); // peak at center
    vec3 w = vec3(r, g, b);
    // gamma correct and normalize
    w = pow(w, vec3(1.0/2.2));
    float s = max(0.0001, w.r + w.g + w.b);
    return w / s;
}

void mainImage(out vec4 outCol, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    // base sample for later blend (one read)
    vec3 base = texture(iChannel0, uv).rgb;

    // direction of aberration: horizontal by default, slight vertical jitter
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 dir = vec2(1.0, 0.18) * (1.0 / aspect);

    // dynamic magnitude driven by intensity and a slow time variance
    float timePhase = sin(iTime * 0.8) * 0.5 + 0.5; // 0..1
    float mag = 0.02 * sat(uIntensity) * (0.3 + 0.7 * timePhase); // max ~0.02

    // cheap per-pixel jitter to avoid banding, but small magnitude
    float pixelJitter = (rnd(floor(uv * iResolution.xy * 0.5)) - 0.5) * 0.002;

    const int NUM_SAMPLES = 7;
    vec3 accum = vec3(0.0);
    vec3 wsum = vec3(0.0);

    // sample across t from 0..1
    for (int i = 0; i < NUM_SAMPLES; ++i) {
        float t = float(i) / float(NUM_SAMPLES - 1); // 0..1
        // offset pattern: center sample (t~0.5) near zero offset, edges shift outwards
        float edgeFactor = (t - 0.5) * 2.0; // -1..1
        // smooth curve to concentrate samples near center
        float curve = sign(edgeFactor) * pow(abs(edgeFactor), 1.2);

        vec2 sampleUV = uv + dir * (mag * curve + pixelJitter);

        // clamp to valid uv to avoid wrap
        sampleUV = sat(sampleUV);

        vec3 sWeights = spectrum_weights(t);
        vec3 sColor = texture(iChannel0, sampleUV).rgb;

        accum += sColor * sWeights;
        wsum += sWeights;
    }

    // normalize by weight sum
    vec3 result = accum / max(vec3(1e-5), wsum);

    // output alpha handled at caller; here return rgb color
    outCol = vec4(result, 1.0);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec4 outCol;
    mainImage(outCol, fragCoord);

    // original base for soft mixing
    vec3 base = texture(uTexture, fragCoord / uResolution).rgb;

    // mix final: when uIntensity==0 -> base; when 1 -> full aberration
    float blend = sat(uIntensity);
    vec3 finalColor = mix(base, outCol.rgb, blend);

    fragColor = vec4(finalColor, 1.0);
}
