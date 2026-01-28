/**
 * VidViz Engine - MediaCodec Encoder Implementation (Android)
 *
 * POC implementation - minSdk 24 uyumlu, fallback mode destekli
 */

#include "mediacodec_encoder.h"
#include "mediacodec_utils.h"
#include "common/log.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>

namespace vidviz {
namespace android {

// Anonymous namespace removed - logic moved to mediacodec_utils.cpp


MediaCodecEncoder::MediaCodecEncoder() {
    LOGI("MediaCodecEncoder created");
}

MediaCodecEncoder::~MediaCodecEncoder() {
    shutdown();
    LOGI("MediaCodecEncoder destroyed");
}

bool MediaCodecEncoder::initialize() {
    LOGI("MediaCodecEncoder initialized");
    return true;
}

void MediaCodecEncoder::shutdown() {
    if (m_started) {
        if (!m_cancelled) {
            finish();
        } else {
            if (m_codec) {
                AMediaCodec_stop(m_codec);
            }
            if (m_muxer && m_muxerStarted) {
                AMediaMuxer_stop(m_muxer);
            }
            m_started = false;
        }
    }

    if (m_inputSurface) {
        ANativeWindow_release(m_inputSurface);
        m_inputSurface = nullptr;
    }

    if (m_codec) {
        AMediaCodec_delete(m_codec);
        m_codec = nullptr;
    }

    if (m_muxer) {
        AMediaMuxer_delete(m_muxer);
        m_muxer = nullptr;
    }
    m_muxerStarted = false;

    if (m_outputFd >= 0) {
        close(m_outputFd);
        m_outputFd = -1;
    }

    m_codecError = false;

    LOGI("MediaCodecEncoder shutdown");
}

bool MediaCodecEncoder::configure(int32_t width,int32_t height,int32_t fps,int32_t quality,const std::string& outputPath) {
    if (m_codec || m_muxer || m_outputFd >= 0 || m_started) {
        shutdown();
    }

    m_width = width;
    m_height = height;
    m_fps = fps;
    m_outputPath = outputPath;
    m_mime = "video/avc";
    m_colorFormat = 21;

    m_cancelled = false;
    m_codecError = false;
    m_audioTracks.clear();
    m_muxerStarted = false;

    if (!utils::endsWithMp4(m_outputPath)) {
        m_lastErrorMsg = "Only mp4 output is supported (outputPath must end with .mp4)";
        LOGE("%s", m_lastErrorMsg.c_str());
        return false;
    }

    m_codec = createEncoder();
    if (!m_codec) {
        LOGE("Failed to create encoder");
        return false;
    }

    m_bitrate = utils::computeBitrate(m_width, m_height, m_fps, quality, m_mime);

    if (!configureCodec(m_codec)) {
        LOGE("Failed to configure encoder");
        return false;
    }

    LOGI("Encoder configured: %dx%d @ %dfps, bitrate: %d",
         m_width, m_height, m_fps, m_bitrate);

    return true;
}

bool MediaCodecEncoder::start() {
    if (!m_codec) {
        LOGE("Codec not configured");
        return false;
    }

    m_codecError = false;

    // Create Surface input (avoid direct symbol usage for NDK compatibility)
    using CreateInputSurfaceFn = media_status_t (*)(AMediaCodec*, ANativeWindow**);
    static CreateInputSurfaceFn createInputSurfaceFn = nullptr;
    static bool createInputSurfaceResolved = false;
    if (!createInputSurfaceResolved) {
        createInputSurfaceResolved = true;
        void* handle = dlopen("libmediandk.so", RTLD_NOW);
        if (handle) {
            createInputSurfaceFn = reinterpret_cast<CreateInputSurfaceFn>(
                dlsym(handle, "AMediaCodec_createInputSurface")
            );
        }
    }

    if (!createInputSurfaceFn) {
        LOGE("Surface input not available (AMediaCodec_createInputSurface missing)");
        return false;
    }

    if (m_inputSurface) {
        ANativeWindow_release(m_inputSurface);
        m_inputSurface = nullptr;
    }

    ANativeWindow* createdSurface = nullptr;
    media_status_t cs = createInputSurfaceFn(m_codec, &createdSurface);
    if (cs != AMEDIA_OK || !createdSurface) {
        LOGE("Failed to create input surface");
        return false;
    }
    m_inputSurface = createdSurface;

    media_status_t status = AMediaCodec_start(m_codec);
    if (status != AMEDIA_OK) {
        LOGE("Failed to start encoder: %d", status);
        return false;
    }

    if (!startMuxer()) {
        LOGE("Failed to start muxer");
        return false;
    }

    m_started = true;
    m_cancelled = false;
    m_frameCount = 0;
    m_sentEos = false;
    m_sawEosOutput = false;
    m_muxerStarted = false;

    LOGI("Encoder started");
    return true;
}

bool MediaCodecEncoder::drain() {
    if (!m_started) return false;
    if (m_codecError) return false;
    drainInternal(false);
    m_frameCount++;
    return true;
}

    bool MediaCodecEncoder::finish() {
        if (!m_started) return true;

        LOGI("Finishing encoder...");

        // FIX: sabit 50 loop yerine zaman bazlı bekleme
        const auto startTime = std::chrono::steady_clock::now();
        const int64_t timeoutMs = 5000;

        while (!m_sawEosOutput && !m_codecError && !m_cancelled) {
            drainInternal(true);
            usleep(1000); // 1ms
            const auto nowTime = std::chrono::steady_clock::now();
            const int64_t elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(nowTime - startTime).count();
            if (elapsedMs > timeoutMs) {
                LOGW("EOS timeout reached");
                break;
            }
        }

        if (m_codec) {
            AMediaCodec_stop(m_codec);
        }

        if (m_muxer && m_muxerStarted) {
            AMediaMuxer_stop(m_muxer);
        }

        m_started = false;

        if (!m_cancelled) {
             // Remuxing işlemi
             if (!MediaCodecRemuxer::remuxAudioTracks(m_outputPath, m_audioTracks, m_lastErrorMsg)) {
                 return false;
             }
        }

        LOGI("Encoder finished. Frames=%d", m_frameCount);
        return true;
    }

void MediaCodecEncoder::cancel() {
    m_cancelled = true;
    shutdown();
    LOGI("Encoder cancelled");
}

bool MediaCodecEncoder::addAudioTrack(const std::string& audioPath,TimeMs startTime,TimeMs duration,TimeMs cutFrom,float volume) {
    if (audioPath.empty()) {
        return false;
    }
    AudioTrackConfig t;
    t.audioPath = audioPath;
    t.startTime = startTime;
    t.duration = duration;
    t.cutFrom = cutFrom;
    t.volume = volume;
    m_audioTracks.push_back(std::move(t));
    return true;
}

void MediaCodecEncoder::setAudioMix(const std::vector<std::pair<std::string, float>>& tracks) {
    (void)tracks;
}

NativeSurface MediaCodecEncoder::getInputSurface() {
    NativeSurface surface;
    surface.handle = m_inputSurface;
    surface.width = m_width;
    surface.height = m_height;
    return surface;
}

bool MediaCodecEncoder::drainEncoder() {
    if (!m_started) return false;
    drainInternal(false);
    return true;
}

    // remuxAudioTracksIfNeeded removed - migrated to MediaCodecRemuxer::remuxAudioTracks

AMediaCodec* MediaCodecEncoder::createEncoder() {
    const int64_t px = static_cast<int64_t>(m_width) * static_cast<int64_t>(m_height);
    const bool preferHevc = (px >= 8'000'000) && (m_fps >= 50);

    if (preferHevc) {
        AMediaCodec* codec = AMediaCodec_createEncoderByType("video/hevc");
        if (codec) {
            m_mime = "video/hevc";
            LOGI("Using HEVC encoder");
            return codec;
        }
    }

    AMediaCodec* codec = AMediaCodec_createEncoderByType("video/avc");
    if (codec) {
        m_mime = "video/avc";
        LOGI("Using H.264 encoder");
        return codec;
    }

    codec = AMediaCodec_createEncoderByType("video/hevc");
    if (codec) {
        m_mime = "video/hevc";
        LOGI("Using HEVC encoder");
        return codec;
    }

    LOGE("No suitable encoder found");
    return nullptr;
}

    bool MediaCodecEncoder::configureCodec(AMediaCodec* codec) {
        constexpr int32_t kColorFormatSurface = 0x7F000789;

        // Profiller
        constexpr int32_t AVCProfileHigh = 8;

        // Seviyeler
        constexpr int32_t AVCLevel41 = 0x1000;

        constexpr int32_t BitrateModeVBR = 1;
        constexpr int32_t BitrateModeCBR = 2;

        AMediaFormat* format = AMediaFormat_new();

        AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, m_mime.c_str());
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, m_width);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, m_height);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_BIT_RATE, m_bitrate);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_FRAME_RATE, m_fps);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_I_FRAME_INTERVAL, 1);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT, kColorFormatSurface);

        const long long totalPixels = (long long)m_width * m_height;
        const bool isUhd = (totalPixels > 2073600);

        // --- AKILLI LEVEL SEÇİMİ (İLK DENEME) ---
        // UHD cihazlarda profile/level zorlamak bazı encoder'larda configure -12 üretebiliyor.
        // Bu yüzden sadece 1080p ve altında set ediyoruz.
        if (m_mime == "video/avc" && !isUhd) {
            AMediaFormat_setInt32(format, "profile", AVCProfileHigh);
            LOGI("Configuring for HD/FHD (Level 4.1)");
            AMediaFormat_setInt32(format, "level", AVCLevel41);
        } else if (m_mime == "video/avc" && isUhd) {
            LOGI("Configuring for 4K/UHD (no forced profile/level)");
        }

        if (m_mime == "video/avc") {
            const int32_t bitrateMode = (isUhd && m_fps >= 50) ? BitrateModeCBR : BitrateModeVBR;
            AMediaFormat_setInt32(format, "bitrate-mode", bitrateMode);
            AMediaFormat_setInt32(format, "priority", 0);
        }

        media_status_t status = AMediaCodec_configure(
                codec, format, nullptr, nullptr, AMEDIACODEC_CONFIGURE_FLAG_ENCODE
        );

        if (status != AMEDIA_OK) {
            LOGW("Codec configuration failed (status=%d). Retrying with minimal settings...", status);

            AMediaFormat_delete(format);
            format = AMediaFormat_new();

            AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, m_mime.c_str());
            AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, m_width);
            AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, m_height);
            AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_BIT_RATE, m_bitrate);
            AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_FRAME_RATE, m_fps);
            AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_I_FRAME_INTERVAL, 1);
            AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT, kColorFormatSurface);

            status = AMediaCodec_configure(
                    codec, format, nullptr, nullptr, AMEDIACODEC_CONFIGURE_FLAG_ENCODE
            );
        }

        AMediaFormat_delete(format);

        if (status == AMEDIA_OK) {
            m_colorFormat = kColorFormatSurface;
            LOGI("Codec configured successfully");
            return true;
        }

        LOGE("Codec configure failed: status=%d", status);
        return false;
    }

bool MediaCodecEncoder::startMuxer() {
    m_videoTrackIndex = -1;
    m_muxerStarted = false;
    if (m_outputFd >= 0) {
        close(m_outputFd);
        m_outputFd = -1;
    }

    m_outputFd = open(m_outputPath.c_str(), O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (m_outputFd < 0) {
        LOGE("Failed to open output file: %s", m_outputPath.c_str());
        return false;
    }

    m_muxer = AMediaMuxer_new(m_outputFd, AMEDIAMUXER_OUTPUT_FORMAT_MPEG_4);

    if (!m_muxer) {
        LOGE("Failed to create muxer");
        close(m_outputFd);
        m_outputFd = -1;
        return false;
    }

    return true;
}

    void MediaCodecEncoder::drainInternal(bool endOfStream) {
        if (!m_codec) return;
        if (m_codecError) return;

        if (endOfStream && !m_sentEos) {
            using SignalEosFn = media_status_t (*)(AMediaCodec*);
            static SignalEosFn signalEosFn = nullptr;
            static bool signalEosResolved = false;
            if (!signalEosResolved) {
                signalEosResolved = true;
                void* handle = dlopen("libmediandk.so", RTLD_NOW);
                if (handle) {
                    signalEosFn = reinterpret_cast<SignalEosFn>(
                            dlsym(handle, "AMediaCodec_signalEndOfInputStream")
                    );
                }
            }

            if (signalEosFn) {
                signalEosFn(m_codec);
            }
            m_sentEos = true;
        }

        AMediaCodecBufferInfo info;

        while (true) {
            // FIX: busy loop yerine kısa timeout
            const int64_t timeoutUs = endOfStream ? 10'000 : 1'000;
            ssize_t index = AMediaCodec_dequeueOutputBuffer(m_codec, &info, timeoutUs);

            if (index == AMEDIACODEC_INFO_TRY_AGAIN_LATER) {
                break;
            }

            if (index == AMEDIACODEC_INFO_OUTPUT_BUFFERS_CHANGED) {
                continue;
            }

            if (index == AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED) {
                // FIX: muxer sadece 1 kere başlatılır
                if (!m_muxerStarted && m_muxer) {
                    AMediaFormat* format = AMediaCodec_getOutputFormat(m_codec);
                    if (format) {
                        m_videoTrackIndex = AMediaMuxer_addTrack(m_muxer, format);
                        AMediaFormat_delete(format);

                        if (m_videoTrackIndex >= 0) {
                            if (AMediaMuxer_start(m_muxer) == AMEDIA_OK) {
                                m_muxerStarted = true;
                                LOGI("Muxer started. Track=%d", m_videoTrackIndex);
                            } else {
                                LOGE("Muxer start failed");
                            }
                        }
                    }
                }
                continue;
            }

            if (index < 0) {
                m_codecError = true;
                m_lastErrorMsg = "Encoder dequeueOutputBuffer failed";
                LOGE("%s (index=%zd)", m_lastErrorMsg.c_str(), index);
                break;
            }

            size_t outSize = 0;
            uint8_t* data = AMediaCodec_getOutputBuffer(m_codec, index, &outSize);

            if ((info.flags & AMEDIACODEC_BUFFER_FLAG_CODEC_CONFIG) != 0) {
                info.size = 0;
            }

            if (data && info.size > 0 && m_muxerStarted && m_videoTrackIndex >= 0) {
                info.offset = 0; // FIX: muxer offset bekler
                AMediaMuxer_writeSampleData(
                        m_muxer,
                        m_videoTrackIndex,
                        data,
                        &info
                );
            }

            AMediaCodec_releaseOutputBuffer(m_codec, index, false);

            if (info.flags & AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM) {
                m_sawEosOutput = true;
                break;
            }
        }
    }

} // namespace android
} // namespace vidviz
