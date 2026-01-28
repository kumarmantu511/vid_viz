/**
 * VidViz Engine - MediaCodec Encoder (Android)
 * 
 * Android H/W video encoding.
 * MediaCodec + Surface input → H.264/HEVC output
 * GPU direct path - CPU kopyası YOK!
 */

#pragma once

#include "mediacodec_remuxer.h"

#include "platform/encoder_interface.h"
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaMuxer.h>
#include <android/native_window.h>

namespace vidviz {
namespace android {

/**
 * MediaCodec Encoder for Android
 * 
 * PERFORMANS KURALLARI:
 * - Surface input kullan (GPU direct)
 * - AHardwareBuffer tercih et
 * - Encode thread ayrı çalışsın
 */
class MediaCodecEncoder : public EncoderInterface {
public:
    MediaCodecEncoder();
    ~MediaCodecEncoder() override;

    // EncoderInterface implementation
    bool initialize() override;
    void shutdown() override;
    bool configure(int32_t width, int32_t height, int32_t fps, int32_t quality, const std::string& outputPath) override;
    bool start() override;
    bool drain() override;
    bool finish() override;
    void cancel() override;
    int32_t getFrameCount() const override { return m_frameCount; }
    std::string getLastErrorMessage() const override { return m_lastErrorMsg; }
    bool addAudioTrack(const std::string& audioPath, TimeMs startTime, TimeMs duration, TimeMs cutFrom, float volume) override;
    void setAudioMix(const std::vector<std::pair<std::string, float>>& tracks) override;
    NativeSurface getInputSurface() override;

    bool drainEncoder();

private:
    // MediaCodec components
    AMediaCodec* m_codec = nullptr;
    AMediaMuxer* m_muxer = nullptr;
    ANativeWindow* m_inputSurface = nullptr;
    int m_outputFd = -1;
    
    // Configuration
    int32_t m_width = 1920;
    int32_t m_height = 1080;
    int32_t m_fps = 30;
    int32_t m_bitrate = 10000000; // 10 Mbps
    std::string m_mime = "video/avc";
    int32_t m_colorFormat = 21;
    std::string m_outputPath;
    
    // State
    bool m_started = false;
    bool m_cancelled = false;
    int32_t m_frameCount = 0;
    int32_t m_videoTrackIndex = -1;
    bool m_sentEos = false;
    bool m_sawEosOutput = false;
    bool m_muxerStarted = false;

    bool m_codecError = false;

    std::string m_lastErrorMsg;

    std::vector<AudioTrackConfig> m_audioTracks;
    
    // Helper methods
    AMediaCodec* createEncoder();
    bool configureCodec(AMediaCodec* codec);
    bool startMuxer();
    void drainInternal(bool endOfStream);

    bool remuxAudioTracksIfNeeded();
};

} // namespace android
} // namespace vidviz
