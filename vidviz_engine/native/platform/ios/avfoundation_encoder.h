/**
 * VidViz Engine - AVFoundation Encoder (iOS)
 * 
 * iOS H/W video encoding.
 * AVAssetWriter + CVPixelBufferPool → H.264/HEVC output
 */

#pragma once

#include "platform/encoder_interface.h"
 #include "platform/ios/ios_encoder_surface.h"

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <string>
#include <vector>

namespace vidviz {
namespace ios {

/**
 * AVFoundation Encoder for iOS
 * 
 * PERFORMANS KURALLARI:
 * - CVPixelBufferPool kullan
 * - AVAssetWriterInputPixelBufferAdaptor kullan
 * - MTLCommandBuffer.addCompletedHandler ile async
 */
class AVFoundationEncoder : public EncoderInterface {
public:
    AVFoundationEncoder();
    ~AVFoundationEncoder() override;

    // EncoderInterface implementation
    bool initialize() override;
    void shutdown() override;
    bool configure(int32_t width, int32_t height, int32_t fps, int32_t quality, const std::string& outputPath) override;
    bool start() override;
    bool drain() override;
    bool finish() override;
    void cancel() override;
    int32_t getFrameCount() const override { return m_frameCount; }
    std::string getLastErrorMessage() const override;
    bool addAudioTrack(const std::string& audioPath, TimeMs startTime, TimeMs duration, TimeMs cutFrom, float volume) override;
    void setAudioMix(const std::vector<std::pair<std::string, float>>& tracks) override;
    NativeSurface getInputSurface() override;

    void onFrameScheduled();
    void onFrameAppended();
    void onFrameAppendFailed(const std::string& error);

private:
    struct AudioTrack {
        std::string audioPath;
        TimeMs startTime = 0;
        TimeMs duration = 0;
        TimeMs cutFrom = 0;
        float volume = 1.0f;
    };

    // AVFoundation handles (stored as void* for C++ header compatibility)
    void* m_assetWriter = nullptr;        // AVAssetWriter*
    void* m_videoInput = nullptr;         // AVAssetWriterInput*
    void* m_pixelBufferAdaptor = nullptr; // AVAssetWriterInputPixelBufferAdaptor*
    void* m_pixelBufferPool = nullptr;    // CVPixelBufferPoolRef

    void* m_audioInput = nullptr;         // AVAssetWriterInput*
    void* m_audioReader = nullptr;        // AVAssetReader*
    void* m_audioOutput = nullptr;        // AVAssetReaderTrackOutput*
    void* m_audioQueue = nullptr;         // dispatch_queue_t

    void* m_videoAppendQueue = nullptr;   // dispatch_queue_t

    // Configuration
    int32_t m_width = 1920;
    int32_t m_height = 1080;
    int32_t m_fps = 30;
    int32_t m_bitrate = 10000000;
    std::string m_outputPath;
    
    // State
    bool m_started = false;
    int32_t m_frameCount = 0;
    int64_t m_presentationTimeValue = 0;

    std::atomic<int32_t> m_pendingFrames{0};
    std::atomic<int32_t> m_pendingAudio{0};
    mutable std::mutex m_pendingMutex;
    mutable std::condition_variable m_pendingCv;
    std::string m_lastError;

    std::vector<AudioTrack> m_audioTracks;

    IosEncoderSurface m_surface;
    
    // Helper methods
    bool createAssetWriter();
    bool createVideoInput();
    bool createPixelBufferPool();
    void cleanup();
};

} // namespace ios
} // namespace vidviz
