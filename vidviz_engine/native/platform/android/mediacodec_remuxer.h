#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace vidviz {
namespace android {

// Audio track yapılandırması
struct AudioTrackConfig {
    std::string audioPath;
    int64_t startTime = 0; // ms
    int64_t duration = 0;  // ms
    int64_t cutFrom = 0;   // ms
    float volume = 1.0f;
};

// Remuxer işlemleri için statik sınıf/namespace
class MediaCodecRemuxer {
public:
    /**
     * Video dosyasına ses kanallarını ekler (Remuxing).
     * 
     * @param videoPath İşlenecek ham video dosyasının yolu
     * @param audioTracks Eklenecek ses dosyaları ve ayarları
     * @param outErrorMsg Hata durumunda mesaj döndürür
     * @return Başarılı ise true
     */
    static bool remuxAudioTracks(const std::string& videoPath, 
                               const std::vector<AudioTrackConfig>& audioTracks, 
                               std::string& outErrorMsg);
};

} // namespace android
} // namespace vidviz
