/**
 * VidViz Engine - Renderer Interface
 * 
 * Platform abstraction for GPU rendering.
 * Android: Vulkan, iOS: Metal
 * 
 * Core kodları bu interface üzerinden render yapar,
 * Vulkan/Metal detaylarını bilmez.
 */

#pragma once

#include "common/types.h"
#include <vector>

namespace vidviz {

class ShaderManager;

/**
 * Abstract renderer interface
 * 
 * Platform (Vulkan/Metal): "Nereye çizileceğini" hazırlar
 */
class RendererInterface {
public:
    virtual ~RendererInterface() = default;

    /// Initialize renderer
    virtual bool initialize() = 0;

    /// Shutdown renderer
    virtual void shutdown() = 0;

    /// Set output size
    virtual void setOutputSize(int32_t width, int32_t height) = 0;

    /// Set global video transform settings (crop/rotation/flip/bg).
    /// Default: no-op for renderers that don't support it.
    virtual void setVideoSettings(const VideoSettings& settings) {
        (void)settings;
    }

    /// Begin frame rendering
    virtual void beginFrame() = 0;

    /// End frame rendering, returns GPU texture for encoding
    virtual GPUTexture endFrame() = 0;

    /// Clear with color
    virtual void clear(float r, float g, float b, float a) = 0;

    // ==========================================================================
    // Layer Rendering
    // ==========================================================================

    /// Render video/image media
    virtual void renderMedia(const Asset& asset, TimeMs localTime) = 0;

    /// Render text overlay
    virtual void renderText(const Asset& asset, TimeMs localTime) = 0;

    /// Render GLSL shader effect
    virtual void renderShader(
        const Asset& asset,
        ShaderManager* shaderManager,
        TimeMs localTime
    ) = 0;

    /// Render audio visualizer
    virtual void renderVisualizer(
        const Asset& asset,
        const std::vector<FFTData>& fftData,
        TimeMs localTime
    ) = 0;

    // ==========================================================================
    // Shader Support
    // ==========================================================================

    /// Compile shader from GLSL source
    /// Android: GLSL → SPIR-V
    /// iOS: SPIR-V → Metal (via SPIRV-Cross)
    virtual bool compileShader(
        const std::string& shaderId,
        const std::string& vertexSource,
        const std::string& fragmentSource
    ) = 0;

    /// Bind shader for rendering
    virtual void bindShader(const std::string& shaderId) = 0;

    /// Set shader uniform
    virtual void setUniform(const std::string& name, float value) = 0;
    virtual void setUniform(const std::string& name, float x, float y) = 0;
    virtual void setUniform(const std::string& name, float x, float y, float z) = 0;
    virtual void setUniform(const std::string& name, float x, float y, float z, float w) = 0;
    virtual void setUniform(const std::string& name, int value) = 0;

    /// Set texture uniform
    virtual void setTexture(const std::string& name, const GPUTexture& texture, int unit) = 0;

    // ==========================================================================
    // Resource Management
    // ==========================================================================

    /// Load texture from file
    virtual GPUTexture loadTexture(const std::string& path) = 0;

    /// Unload texture
    virtual void unloadTexture(GPUTexture& texture) = 0;

    /// Get native surface for encoder (GPU direct path)
    virtual NativeSurface getEncoderSurface() = 0;
    virtual bool setEncoderSurface(const NativeSurface& surface) {
        (void)surface;
        return false;
    }
    virtual bool presentFrame(int64_t ptsUs) {
        (void)ptsUs;
        return false;
    }
};

} // namespace vidviz
