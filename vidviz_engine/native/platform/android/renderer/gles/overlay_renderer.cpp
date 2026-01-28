#include "platform/android/renderer/gles/overlay_renderer.h"

#include "common/minijson.h"

#include <algorithm>
#include <cmath> // std::min, std::max için gerekli

namespace vidviz {
    namespace android {
        namespace gles {

            bool parseMediaOverlayParams(const std::string& dataJson, MediaOverlayParams& out) {
                out = MediaOverlayParams{};
                if (dataJson.empty()) return false;

                const auto parsed = minijson::parse(dataJson);
                if (!parsed.ok()) return false;
                const auto* root = parsed.value.asObject();
                if (!root) return false;

                std::string overlayType;
                minijson::getString(*root, "overlayType", &overlayType);
                if (overlayType != "media") return false;

                out.isOverlay = true;
                minijson::getString(*root, "mediaType", &out.mediaType);

                double d = 0.0;
                if (minijson::getDouble(*root, "x", &d)) out.x = static_cast<float>(d);
                if (minijson::getDouble(*root, "y", &d)) out.y = static_cast<float>(d);
                if (minijson::getDouble(*root, "scale", &d)) out.scale = static_cast<float>(d);
                if (minijson::getDouble(*root, "opacity", &d)) out.opacity = static_cast<float>(d);
                if (minijson::getDouble(*root, "rotation", &d)) out.rotation = static_cast<float>(d);
                if (minijson::getDouble(*root, "borderRadius", &d)) out.borderRadius = static_cast<float>(d);

                minijson::getString(*root, "cropMode", &out.cropMode);
                if (out.cropMode.empty()) {
                    out.cropMode = "none";
                }
                if (minijson::getDouble(*root, "cropZoom", &d)) out.cropZoom = static_cast<float>(d);
                if (minijson::getDouble(*root, "cropPanX", &d)) out.cropPanX = static_cast<float>(d);
                if (minijson::getDouble(*root, "cropPanY", &d)) out.cropPanY = static_cast<float>(d);

                minijson::getString(*root, "frameMode", &out.frameMode);
                if (out.frameMode.empty()) {
                    out.frameMode = "square";
                }
                minijson::getString(*root, "fitMode", &out.fitMode);
                if (out.fitMode.empty()) {
                    out.fitMode = "cover";
                }

                minijson::getString(*root, "animationType", &out.animationType);
                int64_t i64 = 0;
                if (minijson::getInt64(*root, "animationDuration", &i64)) {
                    out.animationDurationMs = static_cast<int32_t>(i64);
                }

                return true;
            }

            void computeMediaOverlayQuad(
                    int32_t outW,
                    int32_t outH,
                    float scale,
                    float borderRadius,
                    float& outBasePx,
                    float& outQuadPx,
                    float& outRadiusPx
            ) {
                // 1. Temel boyut hesapla (Ekranın kısa kenarının %25'i)
                const float minSide = static_cast<float>(std::min(outW, outH));
                float base = minSide * 0.25f;
                const float minBase = minSide * 0.10f;
                const float maxBase = minSide * 0.40f;
                if (base < minBase) base = minBase;
                if (base > maxBase) base = maxBase;

                // 2. Scale uygulanmış nihai pixel boyutu
                const float quadPx = base * scale;

                // 3. Maksimum yarıçap (Resim boyutunun yarısı = Tam Daire)
                const float maxRadiusPx = 0.5f * quadPx;

                // 4. Slider değerini (0-100) normalize et (0.0 - 1.0 arası)
                // Flutter'dan gelen değer 0 ile 100 arasındadır.
                float brRatio = borderRadius / 100.0f;

                // Güvenlik sınırları
                if (brRatio < 0.0f) brRatio = 0.0f;
                if (brRatio > 1.0f) brRatio = 1.0f;

                // 5. Final yarıçapı hesapla: Oran * Maksimum Yarıçap
                // Eğer brRatio 1.0 ise (Slider 100), sonuç maxRadiusPx (Tam Daire) olur.
                const float radiusPx = brRatio * maxRadiusPx;

                outBasePx = base;
                outQuadPx = quadPx;
                outRadiusPx = radiusPx;
            }

        } // namespace gles
    } // namespace android
} // namespace vidviz