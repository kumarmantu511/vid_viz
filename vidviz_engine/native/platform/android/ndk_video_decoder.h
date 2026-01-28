#pragma once

#include <cstdint>
#include <string>
#include <vector>

struct AMediaCodec;
struct AMediaExtractor;
struct AMediaFormat;

namespace vidviz {
namespace android {

class NdkVideoDecoder {
public:
    NdkVideoDecoder();
    ~NdkVideoDecoder();

    NdkVideoDecoder(const NdkVideoDecoder&) = delete;
    NdkVideoDecoder& operator=(const NdkVideoDecoder&) = delete;

    bool open(const std::string& path);
    void close();

    bool isOpen() const { return m_open; }

    bool decodeRgbaAtUs(int64_t timeUs, std::vector<uint8_t>& outRgba, int32_t& outW, int32_t& outH);

private:
    bool selectVideoTrack();
    bool configureDecoder();

    bool feedInput();
    bool drainOutput(int64_t targetUs, std::vector<uint8_t>& outRgba);

    void resetForSeek(int64_t timeUs);

    void updateLayoutFromBufferSize(size_t bufferSize);

    bool convertYuvToRgba(const uint8_t* data, size_t size, std::vector<uint8_t>& outRgba);
    bool convertI420ToRgba(const uint8_t* yuv, std::vector<uint8_t>& outRgba) const;
    bool convertNV12ToRgba(const uint8_t* yuv, std::vector<uint8_t>& outRgba) const;

    static uint8_t clamp8(int v);

private:
    bool m_open = false;

    std::string m_path;
    AMediaExtractor* m_extractor = nullptr;
    AMediaCodec* m_decoder = nullptr;
    AMediaFormat* m_trackFormat = nullptr;

    int32_t m_trackIndex = -1;
    int32_t m_width = 0;
    int32_t m_height = 0;

    int32_t m_stride = 0;
    int32_t m_sliceHeight = 0;
    int32_t m_colorFormat = 0;

    bool m_inputEos = false;
    bool m_outputEos = false;

    int64_t m_lastTargetUs = -1;
    bool m_hasValidDecodeState = false;
};

} // namespace android
} // namespace vidviz
