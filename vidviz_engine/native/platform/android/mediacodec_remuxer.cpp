#include "mediacodec_remuxer.h"
#include "mediacodec_utils.h"
#include "common/log.h"

#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaMuxer.h>
#include <media/NdkMediaFormat.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>
#include <vector>

namespace vidviz {
namespace android {

bool MediaCodecRemuxer::remuxAudioTracks(const std::string& videoPath, 
                                       const std::vector<AudioTrackConfig>& audioTracks, 
                                       std::string& outErrorMsg) {
    if (audioTracks.empty()) return true;
    outErrorMsg.clear();

    if (videoPath.empty()) {
        outErrorMsg = "remux: outputPath is empty";
        return false;
    }

    std::vector<AudioTrackConfig> tracks = audioTracks;
    std::sort(tracks.begin(), tracks.end(), [](const AudioTrackConfig& a, const AudioTrackConfig& b) {
        return a.startTime < b.startTime;
    });

    std::vector<AudioTrackConfig> selected;
    selected.reserve(tracks.size());
    int64_t lastEndUs = -1;
    bool skippedOverlap = false;

    // Örtüşen sesleri temizle
    for (const auto& t : tracks) {
        if (t.audioPath.empty()) continue;
        if (t.duration <= 0) continue;
        const int64_t startUs = (t.startTime > 0) ? (t.startTime * 1000) : 0;
        const int64_t endUs = startUs + (t.duration * 1000);
        if (lastEndUs >= 0 && startUs < lastEndUs) {
            skippedOverlap = true;
            continue;
        }
        selected.push_back(t);
        lastEndUs = endUs;
    }

    if (selected.empty()) {
        outErrorMsg = skippedOverlap
                        ? "remux: all audio segments overlapped; skipped"
                        : "remux: no valid audio segments";
        LOGE("%s; keeping video-only output", outErrorMsg.c_str());
        return true;
    }

    std::string tmpTemplate = videoPath + ".with_audio.XXXXXX";
    std::vector<char> tmpBuf(tmpTemplate.begin(), tmpTemplate.end());
    tmpBuf.push_back('\0');

    int outFd = mkstemp(tmpBuf.data());
    if (outFd < 0) {
        outErrorMsg = "remux: mkstemp failed";
        return false;
    }

    std::string tmpOut(tmpBuf.data());

    AMediaMuxer* muxer = AMediaMuxer_new(outFd, AMEDIAMUXER_OUTPUT_FORMAT_MPEG_4);
    if (!muxer) {
        outErrorMsg = "remux: failed to create muxer";
        close(outFd);
        return false;
    }

    auto openExtractor = [](const std::string& path) -> AMediaExtractor* {
        int fd = open(path.c_str(), O_RDONLY);
        if (fd < 0) return nullptr;

        off_t size = lseek(fd, 0, SEEK_END);
        lseek(fd, 0, SEEK_SET);

        AMediaExtractor* ex = AMediaExtractor_new();
        if (!ex) {
            close(fd);
            return nullptr;
        }

        media_status_t st = AMediaExtractor_setDataSourceFd(
                ex,
                fd,
                0,
                (size > 0) ? size : LONG_MAX
        );

        close(fd);

        if (st != AMEDIA_OK) {
            AMediaExtractor_delete(ex);
            return nullptr;
        }
        return ex;
    };

    AMediaExtractor* videoEx = openExtractor(videoPath);
    if (!videoEx) {
        outErrorMsg = "remux: openExtractor(video) failed";
        AMediaMuxer_delete(muxer);
        close(outFd);
        return false;
    }

    int vTrack = -1;
    const size_t vTracks = AMediaExtractor_getTrackCount(videoEx);
    for (size_t i = 0; i < vTracks; i++) {
        AMediaFormat* fmt = AMediaExtractor_getTrackFormat(videoEx, i);
        if (!fmt) continue;
        const char* mime = nullptr;
        if (AMediaFormat_getString(fmt, AMEDIAFORMAT_KEY_MIME, &mime) && mime) {
            if (strncmp(mime, "video/", 6) == 0) {
                vTrack = static_cast<int>(i);
                AMediaFormat_delete(fmt);
                break;
            }
        }
        AMediaFormat_delete(fmt);
    }

    if (vTrack < 0) {
        outErrorMsg = "remux: no video track in encoded output";
        AMediaExtractor_delete(videoEx);
        AMediaMuxer_delete(muxer);
        close(outFd);
        return false;
    }

    AMediaExtractor* firstAudioEx = openExtractor(selected.front().audioPath);
    if (!firstAudioEx) {
        outErrorMsg = "remux: openExtractor(first audio) failed";
        AMediaExtractor_delete(videoEx);
        AMediaMuxer_delete(muxer);
        close(outFd);
        return false;
    }

    int aTrack = -1;
    const size_t aTracks = AMediaExtractor_getTrackCount(firstAudioEx);
    for (size_t i = 0; i < aTracks; i++) {
        AMediaFormat* fmt = AMediaExtractor_getTrackFormat(firstAudioEx, i);
        if (!fmt) continue;
        const char* mime = nullptr;
        if (AMediaFormat_getString(fmt, AMEDIAFORMAT_KEY_MIME, &mime) && mime) {
            if (strncmp(mime, "audio/", 6) == 0) {
                aTrack = static_cast<int>(i);
                AMediaFormat_delete(fmt);
                break;
            }
        }
        AMediaFormat_delete(fmt);
    }

    if (aTrack < 0) {
        outErrorMsg = "remux: no audio track in first audio asset";
        AMediaExtractor_delete(videoEx);
        AMediaExtractor_delete(firstAudioEx);
        AMediaMuxer_delete(muxer);
        close(outFd);
        return false;
    }

    AMediaFormat* vFmt = AMediaExtractor_getTrackFormat(videoEx, vTrack);
    AMediaFormat* aFmt = AMediaExtractor_getTrackFormat(firstAudioEx, aTrack);
    if (!vFmt || !aFmt) {
        outErrorMsg = "remux: failed to read track format";
        if (vFmt) AMediaFormat_delete(vFmt);
        if (aFmt) AMediaFormat_delete(aFmt);
        AMediaExtractor_delete(videoEx);
        AMediaExtractor_delete(firstAudioEx);
        AMediaMuxer_delete(muxer);
        close(outFd);
        return false;
    }

    const char* aMime = nullptr;
    if (!AMediaFormat_getString(aFmt, AMEDIAFORMAT_KEY_MIME, &aMime) || !aMime) {
        outErrorMsg = "remux: audio mime missing";
        LOGE("%s; keeping video-only output", outErrorMsg.c_str());
        AMediaFormat_delete(vFmt);
        AMediaFormat_delete(aFmt);
        AMediaExtractor_delete(videoEx);
        AMediaExtractor_delete(firstAudioEx);
        AMediaMuxer_delete(muxer);
        close(outFd);
        std::remove(tmpOut.c_str());
        return true;
    }

    const std::string aMimeStr = utils::toLowerAscii(aMime);
    const bool audioSupported = (aMimeStr.find("mp4a") != std::string::npos) || (aMimeStr.find("aac") != std::string::npos);
    const bool audioTrialAllowed = (aMimeStr == "audio/ffmpeg") || (aMimeStr.find("audio/ffmpeg") != std::string::npos);
    if (!audioSupported && !audioTrialAllowed) {
        outErrorMsg = std::string("remux: unsupported audio mime for mp4 muxer: ") + aMimeStr;
        LOGE("%s; keeping video-only output", outErrorMsg.c_str());
        AMediaFormat_delete(vFmt);
        AMediaFormat_delete(aFmt);
        AMediaExtractor_delete(videoEx);
        AMediaExtractor_delete(firstAudioEx);
        AMediaMuxer_delete(muxer);
        close(outFd);
        std::remove(tmpOut.c_str());
        return true;
    }

    if (!audioSupported && audioTrialAllowed) {
        LOGW("remux: audio mime trial-allowed for mp4 muxer: %s", aMimeStr.c_str());
    }

    if (!audioSupported && audioTrialAllowed) {
        AMediaFormat_setString(aFmt, AMEDIAFORMAT_KEY_MIME, "audio/mp4a-latm");
    }

    const int muxVideoTrack = AMediaMuxer_addTrack(muxer, vFmt);
    const int muxAudioTrack = AMediaMuxer_addTrack(muxer, aFmt);
    AMediaFormat_delete(vFmt);
    AMediaFormat_delete(aFmt);
    
    if (muxVideoTrack < 0 || muxAudioTrack < 0) {
        outErrorMsg = "remux: AMediaMuxer_addTrack failed";
        LOGE("%s; keeping video-only output", outErrorMsg.c_str());
        AMediaExtractor_delete(videoEx);
        AMediaExtractor_delete(firstAudioEx);
        AMediaMuxer_delete(muxer);
        close(outFd);
        std::remove(tmpOut.c_str());
        return true;
    }

    AMediaMuxer_start(muxer);

    // Buffer boyutu 4MB
    constexpr size_t kBufSize = 4 * 1024 * 1024;
    std::vector<uint8_t> buffer(kBufSize);
    uint8_t* buf = buffer.data();

    auto getTrackDurationUs = [](AMediaExtractor* ex, int trackIndex) -> int64_t {
        if (!ex || trackIndex < 0) return -1;
        AMediaFormat* fmt = AMediaExtractor_getTrackFormat(ex, trackIndex);
        if (!fmt) return -1;
        int64_t durUs = -1;
        (void)AMediaFormat_getInt64(fmt, AMEDIAFORMAT_KEY_DURATION, &durUs);
        AMediaFormat_delete(fmt);
        return durUs;
    };

    auto writeExtractor = [](AMediaExtractor* ex,
                                int selTrack,
                                AMediaMuxer* mx,
                                int muxTrack,
                                uint8_t* b,
                                size_t cap,
                                int64_t seekUs,
                                int64_t endUs,
                                bool rewritePts,
                                int64_t ptsAddUs,
                                bool* wroteAny) {
        AMediaExtractor_selectTrack(ex, selTrack);
        if (seekUs > 0) {
            AMediaExtractor_seekTo(ex, seekUs, AMEDIAEXTRACTOR_SEEK_CLOSEST_SYNC);
            for (int i = 0; i < 200; i++) {
                const int64_t pts0 = AMediaExtractor_getSampleTime(ex);
                if (pts0 < 0) break;
                if (pts0 >= seekUs) break;
                if (!AMediaExtractor_advance(ex)) break;
            }
        }
        AMediaCodecBufferInfo info;
        int64_t firstPtsUs = -1;
        while (true) {
            const ssize_t sampleSize = AMediaExtractor_readSampleData(ex, b, cap);
            if (sampleSize < 0) break;
            
            if (static_cast<size_t>(sampleSize) > cap) {
                LOGE("Sample size larger than buffer! Data might be truncated.");
            }

            const int64_t pts = AMediaExtractor_getSampleTime(ex);
            if (pts < 0) break;
            if (seekUs > 0 && pts < seekUs) {
                if (!AMediaExtractor_advance(ex)) break;
                continue;
            }
            if (endUs > 0 && pts >= endUs) break;
            if (firstPtsUs < 0) firstPtsUs = pts;

            info.offset = 0;
            info.size = static_cast<int32_t>(sampleSize);
            info.flags = AMediaExtractor_getSampleFlags(ex);

            int64_t outPts = pts;
            if (rewritePts) {
                outPts = (pts - firstPtsUs) + ptsAddUs;
            }
            info.presentationTimeUs = outPts;

            AMediaMuxer_writeSampleData(mx, muxTrack, b, &info);
            if (wroteAny) {
                *wroteAny = true;
            }
            if (!AMediaExtractor_advance(ex)) break;
        }
        AMediaExtractor_unselectTrack(ex, selTrack);
    };

    // Video yaz
    writeExtractor(videoEx, vTrack, muxer, muxVideoTrack, buf, kBufSize, 0, 0, false, 0, nullptr);

    bool wroteAnyAudio = false;
    int audioExtractorOpenFailures = 0;
    int audioNoTrackCount = 0;

    // Ses segmentlerini yaz
    for (const auto& seg : selected) {
        AMediaExtractor* audioEx = openExtractor(seg.audioPath);
        if (!audioEx) {
            audioExtractorOpenFailures++;
            continue;
        }

        int segATrack = -1;
        const size_t segTracks = AMediaExtractor_getTrackCount(audioEx);
        for (size_t i = 0; i < segTracks; i++) {
            AMediaFormat* fmt = AMediaExtractor_getTrackFormat(audioEx, i);
            if (!fmt) continue;
            const char* mime = nullptr;
            if (AMediaFormat_getString(fmt, AMEDIAFORMAT_KEY_MIME, &mime) && mime) {
                if (strncmp(mime, "audio/", 6) == 0) {
                    segATrack = static_cast<int>(i);
                    AMediaFormat_delete(fmt);
                    break;
                }
            }
            AMediaFormat_delete(fmt);
        }

        if (segATrack >= 0) {
            const int64_t outStartUs = (seg.startTime > 0) ? (seg.startTime * 1000) : 0;
            int64_t inStartUs = (seg.cutFrom > 0) ? (seg.cutFrom * 1000) : 0;
            int64_t inEndUs = inStartUs + (seg.duration * 1000);

            const int64_t durUs = getTrackDurationUs(audioEx, segATrack);
            if (durUs > 0) {
                if (inStartUs < 0) inStartUs = 0;
                if (inStartUs > durUs) inStartUs = durUs;
                if (inEndUs < 0) inEndUs = 0;
                if (inEndUs > durUs) inEndUs = durUs;
            }

            if (inEndUs > inStartUs) {
                bool wroteThis = false;
                writeExtractor(audioEx, segATrack, muxer, muxAudioTrack, buf, kBufSize, inStartUs, inEndUs, true, outStartUs, &wroteThis);
                wroteAnyAudio = wroteAnyAudio || wroteThis;
            }
        } else {
            audioNoTrackCount++;
        }

        AMediaExtractor_delete(audioEx);
    }

    AMediaExtractor_delete(videoEx);
    AMediaExtractor_delete(firstAudioEx);
    AMediaMuxer_stop(muxer);
    AMediaMuxer_delete(muxer);
    close(outFd);

    if (!wroteAnyAudio) {
        outErrorMsg = "remux: wrote 0 audio samples (openFail=" + std::to_string(audioExtractorOpenFailures) + 
                      ", noTrack=" + std::to_string(audioNoTrackCount) + ")";
        LOGE("%s; keeping video-only output", outErrorMsg.c_str());
        std::remove(tmpOut.c_str());
        return true;
    }

    std::remove(videoPath.c_str());
    if (std::rename(tmpOut.c_str(), videoPath.c_str()) != 0) {
        LOGE("remux: rename failed (errno=%d)", errno);
        outErrorMsg = "remux: rename failed (errno=" + std::to_string(errno) + ")";
        return false;
    }

    return true;
}

} // namespace android
} // namespace vidviz
