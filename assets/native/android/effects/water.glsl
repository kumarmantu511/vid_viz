#version 300 es
precision highp float;
/*
This shader is ported from the original Apple shader presented at WWDC 2024.
For more details, see the session here: https://developer.apple.com/videos/play/wwdc2024/10151/
Credit to Apple for the original implementation.
*/
uniform vec2 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;

// Shader parameters (dynamic)
uniform float uIntensity;   // 0.0 - 1.0
uniform float uSpeed;       // 0.5 - 2.0
uniform float uFrequency;   // 1.0 - 5.0
uniform float uAmplitude;   // 0.0 - 1.0

const float decay = 0.5; // Decay rate of the ripple
const vec2 origin = vec2(0.5, 0.5); // Center of the ripple

out vec4 fragColor;

void main()
{
    vec2 fragCoord = FlutterFragCoord().xy;

    // Normalize the coordinates
    vec2 uv = fragCoord / iResolution.xy;

    // Vektör farkını bir kere hesapla
    vec2 posFromCenter = uv - origin;

    // Calculate the distance from the center
    float distance = length(posFromCenter);

    // Calculate the delay based on the distance
    // (Bölme işlemi yerine çarpma kullanılabilir ama okunabilirlik için bıraktık)
    float delay = distance / uSpeed;

    // Adjust the time for the delay and clamp to 0
    float time = max(0.0, iTime - delay);

    // --- OPTİMİZASYON BÖLGESİ ---

    // 1. Saf Dalga Formu (Amplitude olmadan):
    // exp ve sin işlemlerini bir kere yapıp değişkende tutuyoruz.
    float waveBase = sin(uFrequency * time) * exp(-decay * time);

    // 2. Ripple Miktarı:
    // Sadece pozisyon kaydırması için amplitude ile çarpıyoruz.
    float ampFactor = uAmplitude * 0.05;
    float rippleAmount = ampFactor * waveBase;

    // 3. Normalize Optimizasyonu:
    // 'normalize(posFromCenter)' çağırmak yerine, zaten bildiğimiz 'distance'a bölüyoruz.
    // 'normalize' fonksiyonu içinde tekrar karekök alırdı, bunu engelledik.
    // 0'a bölme hatasını engellemek için max(distance, 0.0001) kullanıyoruz.
    vec2 n = posFromCenter / max(distance, 0.0001);

    // Calculate the new position
    vec2 newPosition = uv + rippleAmount * n;

    // Sample the texture
    vec3 color = texture(iChannel0, newPosition).rgb;

    // 4. Işıklandırma (Lighting) Optimizasyonu:
    // Eski kod: color += ... * (rippleAmount / ampFactor) yapıyordu.
    // Matematiksel olarak (A * wave) / A = wave demektir.
    // Bölme işleminden tamamen kurtulduk, direkt 'waveBase' kullanıyoruz.
    color += uIntensity * 0.1 * waveBase;

    // Set the fragment color
    fragColor = vec4(color, 1.0);
}