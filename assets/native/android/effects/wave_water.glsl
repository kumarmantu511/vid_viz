#version 300 es
precision highp float;
// Ajarus-based simple water warp adapted for Flutter RuntimeEffect
#version 460 core
uniform vec2 uResolution;
uniform float uTime;
uniform sampler2D uTexture;
uniform float uIntensity; // 0..1

out vec4 fragColor;

const float PI = 3.1415926535897932;

// Parameters
const float emboss = 0.50;
const float frequency = 6.0;
const int steps = 8;
const float speed = 0.2;
const float speed_x = 0.3;
const float speed_y = 0.3;
const float delta = 60.0;
const float gain = 700.0;
const float reflectionCutOff = 0.012;
const float reflectionIntensity = 200000.0;

// Yardımcı fonksiyon: Math işlemlerini sadeleştirdik
float colFn(vec2 coord, float time)
{
    float delta_theta = 2.0 * PI / 7.0; // float(7) yerine direkt 7.0
    float acc = 0.0;

    // Döngü içinde sürekli hesaplanan sabitleri dışarı aldık
    float t_speed = time * speed;
    float t_speed_x = time * speed_x;
    float t_speed_y = time * speed_y;

    for (int i = 0; i < steps; i++)
    {
        float theta = delta_theta * float(i);
        float ct = cos(theta);
        float st = sin(theta);

        // Vektör işlemleri optimize edildi
        // adjc.x = coord.x + ct * t_speed + t_speed_x;
        // adjc.y = coord.y - st * t_speed - t_speed_y;

        float ax = coord.x + ct * t_speed + t_speed_x;
        float ay = coord.y - st * t_speed - t_speed_y;

        // (ax * ct - ay * st) işlemi bir rotasyon matrisidir
        acc += cos((ax * ct - ay * st) * frequency) * 2.4;
    }
    return cos(acc);
}

void main(){
    vec2 frag = FlutterFragCoord().xy;
    vec2 p = frag / uResolution.xy; // 0..1

    // 1. OPTİMİZASYON: Efekt kapalıysa veya çok düşükse işlemciyi yorma (Pil Tasarrufu)
    if (uIntensity < 0.001) {
        fragColor = vec4(texture(uTexture, p).rgb, 1.0);
        return;
    }

    float time = uTime * 1.3;

    // Ana renk dalgası
    float cc1 = colFn(p, time);

    // Gradient (Eğim) Hesabı için Finite Differences
    vec2 off = vec2(1.0 / uResolution.x, 1.0 / uResolution.y) * delta;

    // X derivative (Tekrar p ataması yapmadan direkt hesap)
    float cc2_x = colFn(p + vec2(off.x, 0.0), time);
    float dx = emboss * (cc1 - cc2_x) / delta;

    // Y derivative
    float cc2_y = colFn(p + vec2(0.0, off.y), time);
    float dy = emboss * (cc1 - cc2_y) / delta;

    // Koordinat kaydırma
    vec2 c1 = p + vec2(dx * 2.0, -dy * 2.0);
    c1 = clamp(c1, 0.0, 1.0);

    // Reflection (Parlaklık) efekti
    float alpha = 1.0 + (dx * dy) * gain;

    // If bloklarını daha temiz matematiksel ifadelere çevirdik
    // step(a, b) -> eğer b >= a ise 1.0, değilse 0.0 döner.
    // Bu sayede GPU "if" içinde dallanma yapmaz.
    float ddx = dx - reflectionCutOff;
    float ddy = dy - reflectionCutOff;

    if (ddx > 0.0 && ddy > 0.0) {
        alpha = pow(alpha, ddx * ddy * reflectionIntensity);
    }

    // Alpha değerini sınırla
    alpha = clamp(alpha, 0.0, 2.0);

    // Renkleri karıştır
    vec3 base = texture(uTexture, p).rgb;
    vec3 warped = texture(uTexture, c1).rgb * alpha;

    vec3 finalColor = mix(base, warped, clamp(uIntensity, 0.0, 1.0));
    fragColor = vec4(finalColor, 1.0);
}