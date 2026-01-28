#pragma once

#include <condition_variable>
#include <cstdint>
#include <media/NdkImageReader.h>
#include <mutex>
#include <string>

struct AMediaCodec;
struct AMediaExtractor;
struct AMediaFormat;
struct AImageReader;
struct AImage;
struct AHardwareBuffer;
struct ANativeWindow;

namespace vidviz {
namespace android {

class NdkVideoDecoderGpu {
public:
    NdkVideoDecoderGpu();
    ~NdkVideoDecoderGpu();

    NdkVideoDecoderGpu(const NdkVideoDecoderGpu&) = delete;
    NdkVideoDecoderGpu& operator=(const NdkVideoDecoderGpu&) = delete;

    bool open(const std::string& path);
    void close();

    bool isOpen() const { return m_open; }

    // Returns a retained AHardwareBuffer (caller must AHardwareBuffer_release)
    bool decodeHardwareBufferAtUs(int64_t timeUs, AHardwareBuffer** outBuffer, int32_t& outW, int32_t& outH);

    void getCropRect(int32_t& left, int32_t& top, int32_t& right, int32_t& bottom) const;

private:
    bool selectVideoTrack();
    bool configureDecoderWithImageReader();

    void resetForSeek(int64_t timeUs);

    static void imageCallback(void* context, AImageReader* reader);

    bool feedInput();
    // Return values: 0=Fail/TryAgain, 1=Success(Drained), 2=Future(Keep)
    int drainUntilTarget(int64_t targetUs, AImageReader* reader);

    bool acquireLatestBuffer(AHardwareBuffer** outBuffer, int32_t& outW, int32_t& outH);

private:
    bool m_open = false;

    std::string m_path;
    AMediaExtractor* m_extractor = nullptr;
    AMediaCodec* m_decoder = nullptr;
    AMediaFormat* m_trackFormat = nullptr;

    int32_t m_trackIndex = -1;
    int32_t m_width = 0;
    int32_t m_height = 0;

    bool m_hasCrop = false;
    int32_t m_cropLeft = 0;
    int32_t m_cropTop = 0;
    int32_t m_cropRight = -1;
    int32_t m_cropBottom = -1;

    AImageReader* m_reader = nullptr;
    ANativeWindow* m_readerWindow = nullptr;

    AImageReader_ImageListener m_imageListener{};
    std::mutex m_imageMutex;
    std::condition_variable m_imageCv;
    uint64_t m_imageSignal = 0;
    bool m_hasImageListener = false;

    bool m_inputEos = false;
    bool m_outputEos = false;

    ssize_t m_pendingOutputIndex = -1;
    int64_t m_pendingOutputPtsUs = 0;
    uint32_t m_pendingOutputFlags = 0;

    bool m_isLowMemoryDevice = false;
    int32_t m_consecutiveNoFrameCount = 0;

    int64_t m_lastTargetUs = -1;
    bool m_hasValidDecodeState = false;
};

} // namespace android
} // namespace vidviz
