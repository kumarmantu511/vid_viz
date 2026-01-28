/**
 * VidViz Engine - Encoder Interface
 * 
 * Platform abstraction for video encoding.
 * Android: MediaCodec, iOS: AVFoundation
 * 
 * GPU texture → Hardware encoder → MP4 file
 * CPU kopyası YOK (GPU-First)
 */

#pragma once

#include "common/types.h"

namespace vidviz {

/**
 * Abstract encoder interface
 * 
 * Encoder: "Sonucu" kaydeder (MediaCodec/AVFoundation)
 */
class EncoderInterface {
public:
    virtual ~EncoderInterface() = default;

    /// Initialize encoder
    virtual bool initialize() = 0;

    /// Shutdown encoder
    virtual void shutdown() = 0;

    /// Configure encoder
    /// @param width Output width
    /// @param height Output height
    /// @param fps Frame rate
    /// @param quality 0=low, 1=medium, 2=high
    /// @param outputPath Output file path
    virtual bool configure(
        int32_t width,
        int32_t height,
        int32_t fps,
        int32_t quality,
        const std::string& outputPath
    ) = 0;

    /// Start encoding
    virtual bool start() = 0;

    virtual bool drain() = 0;

    /// Finish encoding and write file
    virtual bool finish() = 0;

    /// Cancel encoding
    virtual void cancel() = 0;

    /// Get encoded frame count
    virtual int32_t getFrameCount() const = 0;

    virtual std::string getLastErrorMessage() const { return std::string(); }

    // ==========================================================================
    // Audio Support
    // ==========================================================================

    /// Add audio track
    virtual bool addAudioTrack(
        const std::string& audioPath,
        TimeMs startTime,
        TimeMs duration,
        TimeMs cutFrom,
        float volume
    ) = 0;

    /// Set audio mix configuration
    virtual void setAudioMix(const std::vector<std::pair<std::string, float>>& tracks) = 0;

    // ==========================================================================
    // Platform Specific
    // ==========================================================================

    /// Get input surface for GPU rendering (Android: Surface, iOS: CVPixelBuffer)
    virtual NativeSurface getInputSurface() = 0;
};

} // namespace vidviz
