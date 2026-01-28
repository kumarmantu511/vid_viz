#include "ndk_video_decoder.h"

#include "common/log.h"

#include <algorithm>
#include <cerrno>
#include <climits>
#include <cstring>

#include <fcntl.h>
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>
#include <unistd.h>

namespace vidviz {
namespace android {

namespace {
    constexpr int64_t kDequeueTimeoutUs = 1000; // 1ms
constexpr int64_t kDrainBudgetIterations = 200;
}

NdkVideoDecoder::NdkVideoDecoder() = default;

NdkVideoDecoder::~NdkVideoDecoder() {
    close();
}

bool NdkVideoDecoder::open(const std::string& path) {
    close();
    if (path.empty()) return false;

    m_path = path;

    int fd = ::open(path.c_str(), O_RDONLY);
    if (fd < 0) {
        LOGE("NdkVideoDecoder: open failed (errno=%d)", errno);
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

    if (!configureDecoder()) {
        close();
        return false;
    }

    m_open = true;
    return true;
}

void NdkVideoDecoder::close() {
    m_open = false;

    if (m_decoder) {
        AMediaCodec_stop(m_decoder);
        AMediaCodec_delete(m_decoder);
        m_decoder = nullptr;
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
    m_stride = 0;
    m_sliceHeight = 0;
    m_colorFormat = 0;
    m_inputEos = false;
    m_outputEos = false;
    m_lastTargetUs = -1;
    m_hasValidDecodeState = false;
}

bool NdkVideoDecoder::selectVideoTrack() {
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

    if (m_trackIndex < 0 || !m_trackFormat) {
        return false;
    }

    AMediaExtractor_selectTrack(m_extractor, m_trackIndex);

    int32_t w = 0;
    int32_t h = 0;
    AMediaFormat_getInt32(m_trackFormat, AMEDIAFORMAT_KEY_WIDTH, &w);
    AMediaFormat_getInt32(m_trackFormat, AMEDIAFORMAT_KEY_HEIGHT, &h);
    m_width = w;
    m_height = h;

    return (m_width > 0 && m_height > 0);
}

bool NdkVideoDecoder::configureDecoder() {
    if (!m_trackFormat) return false;

    const char* mime = nullptr;
    if (!AMediaFormat_getString(m_trackFormat, AMEDIAFORMAT_KEY_MIME, &mime) || !mime) {
        return false;
    }

    m_decoder = AMediaCodec_createDecoderByType(mime);
    if (!m_decoder) {
        return false;
    }

    const media_status_t st = AMediaCodec_configure(m_decoder, m_trackFormat, nullptr, nullptr, 0);
    if (st != AMEDIA_OK) {
        return false;
    }

    if (AMediaCodec_start(m_decoder) != AMEDIA_OK) {
        return false;
    }

    m_inputEos = false;
    m_outputEos = false;

    return true;
}

void NdkVideoDecoder::resetForSeek(int64_t timeUs) {
    if (!m_extractor || !m_decoder) return;

    AMediaExtractor_seekTo(m_extractor, timeUs, AMEDIAEXTRACTOR_SEEK_CLOSEST_SYNC);
    AMediaCodec_flush(m_decoder);
    m_inputEos = false;
    m_outputEos = false;

    // Layout values after flush may change; they will be refreshed on format-changed.
    m_stride = 0;
    m_sliceHeight = 0;
    m_colorFormat = 0;
}

void NdkVideoDecoder::updateLayoutFromBufferSize(size_t bufferSize) {
    if (m_width <= 0 || m_height <= 0) return;
    if (bufferSize == 0) return;

    const int32_t stride = (m_stride > 0) ? m_stride : m_width;
    if (stride <= 0) return;

    // For YUV420 (planar or semi-planar), total bytes ~= stride * sliceHeight * 3/2.
    // Derive sliceHeight from bufferSize and stride when the platform doesn't expose it.
    const size_t yBytesApprox = (bufferSize * 2u) / 3u;
    if (yBytesApprox == 0) return;

    const int32_t inferred = static_cast<int32_t>(yBytesApprox / static_cast<size_t>(stride));
    if (inferred <= 0) return;

    // Clamp: never smaller than visible height.
    m_sliceHeight = std::max(m_height, inferred);
}

bool NdkVideoDecoder::feedInput() {
    if (!m_decoder || !m_extractor || m_inputEos) return true;

    const ssize_t inputIndex = AMediaCodec_dequeueInputBuffer(m_decoder, kDequeueTimeoutUs);
    if (inputIndex < 0) {
        return true;
    }

    size_t bufSize = 0;
    uint8_t* buf = AMediaCodec_getInputBuffer(m_decoder, inputIndex, &bufSize);
    if (!buf || bufSize == 0) {
        AMediaCodec_queueInputBuffer(m_decoder, inputIndex, 0, 0, 0, 0);
        return true;
    }

    const ssize_t sampleSize = AMediaExtractor_readSampleData(m_extractor, buf, bufSize);
    if (sampleSize < 0) {
        AMediaCodec_queueInputBuffer(
            m_decoder,
            inputIndex,
            0,
            0,
            0,
            AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM
        );
        m_inputEos = true;
        return true;
    }

    const int64_t pts = AMediaExtractor_getSampleTime(m_extractor);
    const uint32_t flags = AMediaExtractor_getSampleFlags(m_extractor);
    const media_status_t st = AMediaCodec_queueInputBuffer(
        m_decoder,
        inputIndex,
        0,
        static_cast<size_t>(sampleSize),
        pts,
        flags
    );

    if (st != AMEDIA_OK) {
        return false;
    }

    AMediaExtractor_advance(m_extractor);
    return true;
}

bool NdkVideoDecoder::drainOutput(int64_t targetUs, std::vector<uint8_t>& outRgba) {
    if (!m_decoder) return false;

    AMediaCodecBufferInfo info;
    for (int64_t i = 0; i < kDrainBudgetIterations && !m_outputEos; i++) {
        const ssize_t outIndex = AMediaCodec_dequeueOutputBuffer(m_decoder, &info, kDequeueTimeoutUs);

        if (outIndex == AMEDIACODEC_INFO_TRY_AGAIN_LATER) {
            return false;
        }

        if (outIndex == AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED) {
            AMediaFormat* ofmt = AMediaCodec_getOutputFormat(m_decoder);
            if (ofmt) {
                int32_t v = 0;
                if (AMediaFormat_getInt32(ofmt, AMEDIAFORMAT_KEY_STRIDE, &v)) m_stride = v;
                #if defined(__ANDROID_API__) && (__ANDROID_API__ >= 28)
                if (AMediaFormat_getInt32(ofmt, AMEDIAFORMAT_KEY_SLICE_HEIGHT, &v)) m_sliceHeight = v;
                #endif
                if (AMediaFormat_getInt32(ofmt, AMEDIAFORMAT_KEY_COLOR_FORMAT, &v)) m_colorFormat = v;
                AMediaFormat_delete(ofmt);
            }
            continue;
        }

        if (outIndex < 0) {
            continue;
        }

        if (info.flags & AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM) {
            m_outputEos = true;
        }

        size_t outSize = 0;
        uint8_t* outBuf = AMediaCodec_getOutputBuffer(m_decoder, outIndex, &outSize);

        const bool ptsOk = (info.presentationTimeUs >= targetUs);
        bool copied = false;
        if (outBuf && info.size > 0 && ptsOk) {
            const size_t usedBytes = static_cast<size_t>(info.offset) + static_cast<size_t>(info.size);
            updateLayoutFromBufferSize(usedBytes);
            const uint8_t* data = outBuf + info.offset;
            copied = convertYuvToRgba(data, static_cast<size_t>(info.size), outRgba);
        }

        AMediaCodec_releaseOutputBuffer(m_decoder, outIndex, false);

        if (ptsOk) {
            return copied;
        }
    }

    return false;
}

bool NdkVideoDecoder::decodeRgbaAtUs(int64_t timeUs, std::vector<uint8_t>& outRgba, int32_t& outW, int32_t& outH) {
    if (!m_open) {
        if (!open(m_path)) return false;
    }

    outW = m_width;
    outH = m_height;

    if (m_width <= 0 || m_height <= 0) {
        return false;
    }

    // If time moves forward monotonically (typical export), keep decoder running sequentially.
    // If caller seeks backwards (or first call), reset to a sync sample near target.
    if (!m_hasValidDecodeState || m_lastTargetUs < 0 || timeUs < m_lastTargetUs) {
        resetForSeek(timeUs);
        m_hasValidDecodeState = true;
    }

    const size_t needed = static_cast<size_t>(m_width) * static_cast<size_t>(m_height) * 4u;
    if (outRgba.size() != needed) {
        outRgba.resize(needed);
    }

    for (int i = 0; i < 2000 && !m_outputEos; i++) {
        if (!feedInput()) return false;
        if (drainOutput(timeUs, outRgba)) {
            m_lastTargetUs = timeUs;
            return true;
        }
    }

    return false;
}

uint8_t NdkVideoDecoder::clamp8(int v) {
    if (v < 0) return 0;
    if (v > 255) return 255;
    return static_cast<uint8_t>(v);
}

bool NdkVideoDecoder::convertI420ToRgba(const uint8_t* yuv, std::vector<uint8_t>& outRgba) const {
    const int32_t w = m_width;
    const int32_t h = m_height;
    const int32_t stride = (m_stride > 0) ? m_stride : w;
    const int32_t sh = (m_sliceHeight > 0) ? m_sliceHeight : h;

    const int32_t chromaStride = (stride + 1) / 2;
    const int32_t chromaH = (sh + 1) / 2;

    const uint8_t* yPlane = yuv;
    const uint8_t* uPlane = yPlane + stride * sh;
    const uint8_t* vPlane = uPlane + chromaStride * chromaH;

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            const int Y = yPlane[y * stride + x];
            const int U = uPlane[(y / 2) * chromaStride + (x / 2)];
            const int V = vPlane[(y / 2) * chromaStride + (x / 2)];

            const int C = Y - 16;
            const int D = U - 128;
            const int E = V - 128;

            const int R = (298 * C + 409 * E + 128) >> 8;
            const int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
            const int B = (298 * C + 516 * D + 128) >> 8;

            const size_t idx = (static_cast<size_t>(y) * static_cast<size_t>(w) + static_cast<size_t>(x)) * 4u;
            outRgba[idx + 0] = clamp8(R);
            outRgba[idx + 1] = clamp8(G);
            outRgba[idx + 2] = clamp8(B);
            outRgba[idx + 3] = 255;
        }
    }

    return true;
}

bool NdkVideoDecoder::convertNV12ToRgba(const uint8_t* yuv, std::vector<uint8_t>& outRgba) const {
    const int32_t w = m_width;
    const int32_t h = m_height;
    const int32_t stride = (m_stride > 0) ? m_stride : w;
    const int32_t sh = (m_sliceHeight > 0) ? m_sliceHeight : h;

    const uint8_t* yPlane = yuv;
    const uint8_t* uvPlane = yPlane + stride * sh;

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            const int Y = yPlane[y * stride + x];
            const int uvIndex = (y / 2) * stride + (x / 2) * 2;
            const int U = uvPlane[uvIndex + 0];
            const int V = uvPlane[uvIndex + 1];

            const int C = Y - 16;
            const int D = U - 128;
            const int E = V - 128;

            const int R = (298 * C + 409 * E + 128) >> 8;
            const int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
            const int B = (298 * C + 516 * D + 128) >> 8;

            const size_t idx = (static_cast<size_t>(y) * static_cast<size_t>(w) + static_cast<size_t>(x)) * 4u;
            outRgba[idx + 0] = clamp8(R);
            outRgba[idx + 1] = clamp8(G);
            outRgba[idx + 2] = clamp8(B);
            outRgba[idx + 3] = 255;
        }
    }

    return true;
}

bool NdkVideoDecoder::convertYuvToRgba(const uint8_t* data, size_t size, std::vector<uint8_t>& outRgba) {
    (void)size;

    const int32_t color = m_colorFormat;

    // Common Android decoder outputs:
    // 19 = COLOR_FormatYUV420Planar (I420)
    // 21 = COLOR_FormatYUV420SemiPlanar (NV12/NV21-like; we treat as NV12)
    if (color == 19) {
        return convertI420ToRgba(data, outRgba);
    }
    if (color == 21 || color == 0) {
        return convertNV12ToRgba(data, outRgba);
    }

    // Fallback: try NV12
    return convertNV12ToRgba(data, outRgba);
}

} // namespace android
} // namespace vidviz
