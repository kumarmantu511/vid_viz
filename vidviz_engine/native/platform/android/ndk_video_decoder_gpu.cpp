#include "ndk_video_decoder_gpu.h"

#include "common/log.h"

#include <algorithm>
#include <cerrno>
#include <climits>
#include <cstring>

#include <chrono>
#include <thread>

#include <android/hardware_buffer.h>
#include <android/native_window.h>
#include <fcntl.h>
#include <media/NdkImage.h>
#include <media/NdkImageReader.h>
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>
#include <sys/sysinfo.h>
#include <unistd.h>

namespace vidviz {
namespace android {

namespace {
constexpr int64_t kDequeueInputTimeoutUs = 5'000;
constexpr int64_t kDequeueOutputTimeoutUs = 5'000;
constexpr uint64_t kLowMemoryThresholdBytes = 4ull * 1024ull * 1024ull * 1024ull;

bool isLowMemoryDeviceCached() {
    static int s_cached = -1;
    if (s_cached >= 0) return s_cached != 0;

    struct sysinfo info {};
    if (sysinfo(&info) != 0) {
        s_cached = 0;
        return false;
    }

    const uint64_t totalBytes = static_cast<uint64_t>(info.totalram) * static_cast<uint64_t>(info.mem_unit);
    s_cached = (totalBytes > 0 && totalBytes <= kLowMemoryThresholdBytes) ? 1 : 0;
    return s_cached != 0;
}
}

NdkVideoDecoderGpu::NdkVideoDecoderGpu() = default;

NdkVideoDecoderGpu::~NdkVideoDecoderGpu() {
    close();
}

bool NdkVideoDecoderGpu::open(const std::string& path) {
    close();
    if (path.empty()) return false;

    m_path = path;

    int fd = ::open(path.c_str(), O_RDONLY);
    if (fd < 0) {
        LOGE("NdkVideoDecoderGpu: open failed (errno=%d)", errno);
        return false;
    }

    m_extractor = AMediaExtractor_new();
    if (!m_extractor) {
        ::close(fd);
        return false;
    }

    const media_status_t st = AMediaExtractor_setDataSourceFd(m_extractor, fd, 0, LONG_MAX);
    ::close(fd);
    if (st != AMEDIA_OK) {
        close();
        return false;
    }

    if (!selectVideoTrack()) {
        close();
        return false;
    }

    m_isLowMemoryDevice = isLowMemoryDeviceCached();

    if (m_isLowMemoryDevice) {
        const int64_t px = static_cast<int64_t>(m_width) * static_cast<int64_t>(m_height);
        if (px >= 8'000'000) {
            LOGW("NdkVideoDecoderGpu: refusing high-res decode on low-memory device (%dx%d)", m_width, m_height);
            close();
            return false;
        }
    }

    if (!configureDecoderWithImageReader()) {
        close();
        return false;
    }

    m_open = true;
    m_consecutiveNoFrameCount = 0;
    return true;
}

void NdkVideoDecoderGpu::close() {
    m_open = false;

    if (m_decoder) {
        AMediaCodec_stop(m_decoder);
        AMediaCodec_delete(m_decoder);
        m_decoder = nullptr;
    }

    if (m_readerWindow) {
        ANativeWindow_release(m_readerWindow);
        m_readerWindow = nullptr;
    }

    if (m_reader) {
        AImageReader_ImageListener emptyListener{};
        AImageReader_setImageListener(m_reader, &emptyListener);
        AImageReader_delete(m_reader);
        m_reader = nullptr;
    }

    if (m_trackFormat) {
        AMediaFormat_delete(m_trackFormat);
        m_trackFormat = nullptr;
    }

    if (m_extractor) {
        AMediaExtractor_delete(m_extractor);
        m_extractor = nullptr;
    }

    m_trackIndex = -1;
    m_width = 0;
    m_height = 0;
    m_hasCrop = false;
    m_cropLeft = 0;
    m_cropTop = 0;
    m_cropRight = -1;
    m_cropBottom = -1;
    m_inputEos = false;
    m_outputEos = false;
    m_pendingOutputIndex = -1;
    m_pendingOutputPtsUs = 0;
    m_pendingOutputFlags = 0;
    {
        std::lock_guard<std::mutex> lock(m_imageMutex);
        m_imageSignal = 0;
    }
    m_hasImageListener = false;
    m_consecutiveNoFrameCount = 0;
    m_lastTargetUs = -1;
    m_hasValidDecodeState = false;
}

bool NdkVideoDecoderGpu::selectVideoTrack() {
    if (!m_extractor) return false;

    const size_t trackCount = AMediaExtractor_getTrackCount(m_extractor);
    for (size_t i = 0; i < trackCount; i++) {
        AMediaFormat* fmt = AMediaExtractor_getTrackFormat(m_extractor, i);
        if (!fmt) continue;

        const char* mime = nullptr;
        const bool hasMime = AMediaFormat_getString(fmt, AMEDIAFORMAT_KEY_MIME, &mime);
        if (hasMime && mime && strncmp(mime, "video/", 6) == 0) {
            m_trackIndex = static_cast<int32_t>(i);
            m_trackFormat = fmt;
            break;
        }

        AMediaFormat_delete(fmt);
    }

    if (m_trackIndex < 0 || !m_trackFormat) return false;

    AMediaExtractor_selectTrack(m_extractor, m_trackIndex);

    int32_t w = 0;
    int32_t h = 0;
    AMediaFormat_getInt32(m_trackFormat, AMEDIAFORMAT_KEY_WIDTH, &w);
    AMediaFormat_getInt32(m_trackFormat, AMEDIAFORMAT_KEY_HEIGHT, &h);
    m_width = w;
    m_height = h;
    return (m_width > 0 && m_height > 0);
}

bool NdkVideoDecoderGpu::configureDecoderWithImageReader() {
    if (!m_trackFormat || m_width <= 0 || m_height <= 0) return false;

    const char* mime = nullptr;
    if (!AMediaFormat_getString(m_trackFormat, AMEDIAFORMAT_KEY_MIME, &mime) || !mime) return false;

    // ImageReader provides an ANativeWindow that MediaCodec can decode into.
    // Ensure the underlying AHardwareBuffer is GPU-sampleable for EGLImage/OES path.
    const uint64_t usage = AHARDWAREBUFFER_USAGE_GPU_SAMPLED_IMAGE | AHARDWAREBUFFER_USAGE_GPU_COLOR_OUTPUT;
    if (AImageReader_newWithUsage(m_width, m_height, AIMAGE_FORMAT_PRIVATE, usage, 3, &m_reader) != AMEDIA_OK || !m_reader) {
        return false;
    }

    {
        std::lock_guard<std::mutex> lock(m_imageMutex);
        m_imageSignal = 0;
    }
    m_hasImageListener = false;
    m_imageListener.context = this;
    m_imageListener.onImageAvailable = &NdkVideoDecoderGpu::imageCallback;
    if (AImageReader_setImageListener(m_reader, &m_imageListener) == AMEDIA_OK) {
        m_hasImageListener = true;
    } else {
        LOGW("NdkVideoDecoderGpu: AImageReader_setImageListener failed; falling back to polling wait");
    }

    if (AImageReader_getWindow(m_reader, &m_readerWindow) != AMEDIA_OK || !m_readerWindow) {
        return false;
    }
    ANativeWindow_acquire(m_readerWindow);

    m_decoder = AMediaCodec_createDecoderByType(mime);
    if (!m_decoder) return false;

    if (AMediaCodec_configure(m_decoder, m_trackFormat, m_readerWindow, nullptr, 0) != AMEDIA_OK) {
        return false;
    }

    if (AMediaCodec_start(m_decoder) != AMEDIA_OK) {
        return false;
    }

    m_inputEos = false;
    m_outputEos = false;
    return true;
}

void NdkVideoDecoderGpu::resetForSeek(int64_t timeUs) {
    if (!m_extractor || !m_decoder) return;
    AMediaExtractor_seekTo(m_extractor, timeUs, AMEDIAEXTRACTOR_SEEK_CLOSEST_SYNC);
    AMediaCodec_flush(m_decoder);
    m_inputEos = false;
    m_outputEos = false;

    m_hasCrop = false;
    m_cropLeft = 0;
    m_cropTop = 0;
    m_cropRight = -1;
    m_cropBottom = -1;

    m_consecutiveNoFrameCount = 0;
}

void NdkVideoDecoderGpu::imageCallback(void* context, AImageReader* /*reader*/) {
    auto* self = reinterpret_cast<NdkVideoDecoderGpu*>(context);
    if (!self) return;

    {
        std::lock_guard<std::mutex> lock(self->m_imageMutex);
        self->m_imageSignal++;
    }
    self->m_imageCv.notify_all();
}

void NdkVideoDecoderGpu::getCropRect(int32_t& left, int32_t& top, int32_t& right, int32_t& bottom) const {
    if (!m_hasCrop || m_width <= 0 || m_height <= 0 || m_cropRight < 0 || m_cropBottom < 0) {
        left = 0;
        top = 0;
        right = std::max(0, m_width - 1);
        bottom = std::max(0, m_height - 1);
        return;
    }
    left = m_cropLeft;
    top = m_cropTop;
    right = m_cropRight;
    bottom = m_cropBottom;
}

bool NdkVideoDecoderGpu::feedInput() {
    if (!m_decoder || !m_extractor || m_inputEos) return true;

    const ssize_t inputIndex = AMediaCodec_dequeueInputBuffer(m_decoder, kDequeueInputTimeoutUs);
    if (inputIndex < 0) return true;

    size_t bufSize = 0;
    uint8_t* buf = AMediaCodec_getInputBuffer(m_decoder, inputIndex, &bufSize);
    if (!buf || bufSize == 0) {
        AMediaCodec_queueInputBuffer(m_decoder, inputIndex, 0, 0, 0, 0);
        return true;
    }

    const ssize_t sampleSize = AMediaExtractor_readSampleData(m_extractor, buf, bufSize);
    if (sampleSize < 0) {
        AMediaCodec_queueInputBuffer(m_decoder, inputIndex, 0, 0, 0, AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM);
        m_inputEos = true;
        return true;
    }

    const int64_t pts = AMediaExtractor_getSampleTime(m_extractor);
    const uint32_t flags = AMediaExtractor_getSampleFlags(m_extractor);

    if (AMediaCodec_queueInputBuffer(
            m_decoder,
            inputIndex,
            0,
            static_cast<size_t>(sampleSize),
            pts,
            flags) != AMEDIA_OK) {
        LOGE("queueInputBuffer failed for pts: %lld", (long long)pts);
        return false;
    }

    static int s_feedLogCount = 0;
    if (s_feedLogCount < 10 || (s_feedLogCount % 300) == 0) {
        LOGD("Queued input pts: %lld | flags: %u", (long long)pts, flags);
    }
    s_feedLogCount++;
    AMediaExtractor_advance(m_extractor);
    return true;
}

// Return: 0=Fail/Retry, 1=Drained(NewFrame), 2=Future(UsePrevious)
int NdkVideoDecoderGpu::drainUntilTarget(int64_t targetUs, AImageReader* reader) {
    if (!m_decoder || !reader) return 0;

    // Drain bütçesi (loop count)
    for (int i = 0; i < 10 && !m_outputEos; i++) {
        ssize_t outIndex = m_pendingOutputIndex;
        AMediaCodecBufferInfo info {};
        info.presentationTimeUs = m_pendingOutputPtsUs;
        info.flags = m_pendingOutputFlags;

        // Eğer elimizde bekleyen (pending) bir buffer yoksa, Codec'ten iste.
        if (outIndex < 0) {
            outIndex = AMediaCodec_dequeueOutputBuffer(m_decoder, &info, kDequeueOutputTimeoutUs);
            
            if (outIndex == AMEDIACODEC_INFO_TRY_AGAIN_LATER) {
                return 0; // Retry
            }
            // ... (Info change ve error handling aynı) ...
            if (outIndex == AMEDIACODEC_INFO_OUTPUT_BUFFERS_CHANGED) continue;
            if (outIndex == AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED) {
                LOGI("GPU Decoder Output Format Changed");
                AMediaFormat* ofmt = AMediaCodec_getOutputFormat(m_decoder);
                if (ofmt) {
                    int32_t v = 0;
                    if (AMediaFormat_getInt32(ofmt, "crop-left", &v)) { m_cropLeft = v; m_hasCrop = true; }
                    if (AMediaFormat_getInt32(ofmt, "crop-top", &v)) { m_cropTop = v; m_hasCrop = true; }
                    if (AMediaFormat_getInt32(ofmt, "crop-right", &v)) { m_cropRight = v; m_hasCrop = true; }
                    if (AMediaFormat_getInt32(ofmt, "crop-bottom", &v)) { m_cropBottom = v; m_hasCrop = true; }
                    AMediaFormat_delete(ofmt);
                }
                continue; // Format değişikliğinden sonra tekrar dequeue dene
            }
            if (outIndex < 0) {
                LOGW("GPU Dequeue Error: %zd", outIndex);
                continue;
            }
            // Başarılı dequeue
            if (info.flags & AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM) {
                LOGI("GPU Decoder EOS Reached at %lld", (long long)info.presentationTimeUs);
                m_outputEos = true;
            }
        }

        // Elimizde bir buffer var (outIndex). Zaman kontrolü yap.
        const int64_t diff = info.presentationTimeUs - targetUs;

        // 1. Çok Eski Frame (Drift/Seek leftovers): >100ms geride
        if (diff < -100000) {
            LOGW("Dropping old frame: %lld (Target: %lld)", (long long)info.presentationTimeUs, (long long)targetUs);
            AMediaCodec_releaseOutputBuffer(m_decoder, outIndex, false); // Render etme (drop)
            m_pendingOutputIndex = -1; // Tükettik
            continue; // Yeni frame ara
        }

        // 2. Gelecek Frame (Future): >40ms ilerde (30fps için 1 frame payı + tolerans)
        // Render 60fps, Video 30fps ise: T=16ms'de frame 33ms gelebilir. 17ms fark.
        // T=32ms'de frame 66ms gelebilir. 34ms fark.
        // Toleransı 40ms yaparsak; 33ms frame'i T=0'da (Diff=33) kabul ederiz. T=16'da (Diff=17) kabul ederiz.
        // Ama eğer Diff > 45ms ise bekletelim.
        if (diff > 45000) {
            // Gelecekteki bir frame. Henüz gösterme. Codec'te tutmaya devam etmeyip "pending" yapıyoruz.
            // Çünkü queueInputBuffer yapmaya devam etmemiz gerekebilir (pipeline doluluğu için).
            // Ancak pending tutarsak loop'tan çıkmalıyız.
            // LOGV("Future frame pending: %lld (Target: %lld, Diff: %lld)", (long long)info.presentationTimeUs, (long long)targetUs, (long long)diff);
            
            m_pendingOutputIndex = outIndex;
            m_pendingOutputPtsUs = info.presentationTimeUs;
            m_pendingOutputFlags = info.flags;
            return 2; // STATUS: FUTURE (Reuse previous)
        }

        // 3. Uygun Frame (Target'a yakın veya az ilerde)
        // LOGD("Draining frame: %lld (Target: %lld)", (long long)info.presentationTimeUs, (long long)targetUs);
        AMediaCodec_releaseOutputBuffer(m_decoder, outIndex, true); // Render et -> ImageReader
        m_pendingOutputIndex = -1; // Tükettik
        return 1; // STATUS: DRAINED (New Frame)
    }

    return 0; // Timeout / No frame ready
}

bool NdkVideoDecoderGpu::acquireLatestBuffer(AHardwareBuffer** outBuffer, int32_t& outW, int32_t& outH) {
    if (!m_reader || !outBuffer) return false;

    *outBuffer = nullptr;

    AImage* image = nullptr;
    if (AImageReader_acquireLatestImage(m_reader, &image) != AMEDIA_OK || !image) {
        return false;
    }

    AHardwareBuffer* hb = nullptr;
    if (AImage_getHardwareBuffer(image, &hb) != AMEDIA_OK || !hb) {
        AImage_delete(image);
        return false;
    }

    // Retain buffer for caller; AImage_delete will drop its reference.
    AHardwareBuffer_acquire(hb);

    outW = m_width;
    outH = m_height;

    AImage_delete(image);

    *outBuffer = hb;
    return true;
}

bool NdkVideoDecoderGpu::decodeHardwareBufferAtUs(int64_t timeUs, AHardwareBuffer** outBuffer, int32_t& outW, int32_t& outH) {
    if (!m_open) if (!open(m_path)) return false;

    outW = m_width;
    outH = m_height;
    if (m_width <= 0 || m_height <= 0) return false;

    if (outBuffer) {
        *outBuffer = nullptr;
    }

    if (!m_hasValidDecodeState || timeUs < m_lastTargetUs - 100000) {
        resetForSeek(timeUs);
        m_pendingOutputIndex = -1; // Reset pending
        m_pendingOutputPtsUs = 0;
        m_pendingOutputFlags = 0;
        m_hasValidDecodeState = true;
    }

    const auto start = std::chrono::steady_clock::now();
    const auto decodeDeadline = start + std::chrono::milliseconds(m_isLowMemoryDevice ? 80 : 120);
    const auto imageDeadline = start + std::chrono::milliseconds(m_isLowMemoryDevice ? 120 : 200);

    while (std::chrono::steady_clock::now() < decodeDeadline) {
        if (!feedInput()) {
            LOGW("feedInput failed");
            return false;
        }

        const int status = drainUntilTarget(timeUs, m_reader);

        if (status == 1) {
            m_lastTargetUs = timeUs;

            if (acquireLatestBuffer(outBuffer, outW, outH)) {
                m_consecutiveNoFrameCount = 0;
                return true;
            }

            if (m_hasImageListener) {
                uint64_t signalBefore = 0;
                {
                    std::lock_guard<std::mutex> lock(m_imageMutex);
                    signalBefore = m_imageSignal;
                }

                while (std::chrono::steady_clock::now() < imageDeadline) {
                    {
                        std::unique_lock<std::mutex> lock(m_imageMutex);
                        m_imageCv.wait_until(lock, imageDeadline, [&] { return m_imageSignal != signalBefore; });
                        signalBefore = m_imageSignal;
                    }

                    if (acquireLatestBuffer(outBuffer, outW, outH)) {
                        m_consecutiveNoFrameCount = 0;
                        return true;
                    }
                }
            } else {
                while (std::chrono::steady_clock::now() < imageDeadline) {
                    if (acquireLatestBuffer(outBuffer, outW, outH)) {
                        m_consecutiveNoFrameCount = 0;
                        return true;
                    }
                    std::this_thread::sleep_for(std::chrono::milliseconds(1));
                }
            }

            m_consecutiveNoFrameCount++;
            if (m_consecutiveNoFrameCount > 60 && !m_outputEos) {
                LOGW("NdkVideoDecoderGpu: no frames available for a while (targetUs=%lld)", (long long)timeUs);
                return false;
            }
            return true;
        }

        if (status == 2) {
            m_lastTargetUs = timeUs;
            m_consecutiveNoFrameCount++;
            if (m_consecutiveNoFrameCount > 120 && !m_outputEos) {
                LOGW("NdkVideoDecoderGpu: stuck on future frame pending (targetUs=%lld pendingPts=%lld)", (long long)timeUs, (long long)m_pendingOutputPtsUs);
                return false;
            }
            return true;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    m_consecutiveNoFrameCount++;
    if (m_consecutiveNoFrameCount > 120 && !m_outputEos) {
        LOGW("NdkVideoDecoderGpu: decode deadline exceeded repeatedly (targetUs=%lld)", (long long)timeUs);
        return false;
    }
    return true;
}

} // namespace android
} // namespace vidviz
