/**
 * VidViz Engine - Metal Renderer (iOS)
 * 
 * iOS'a özel Metal kurulumu.
 * MetalTextureCache kullan.
 * MTLStorageModePrivate kullan.
 */

#pragma once

#include "platform/renderer_interface.h"

#include <unordered_map>
#include <cstdint>
#include <vector>

#ifdef __OBJC__
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>
#endif

 #include "platform/ios/ios_encoder_surface.h"
 #include "platform/ios/metal_export_session.h"

namespace vidviz {
namespace ios {

namespace text {
class TextRendererIOS;
class TextRendererIOSImpl;
} // namespace text

/**
 * Metal Renderer for iOS
 * 
 * PERFORMANS KURALLARI:
 * - MetalTextureCache kullan
 * - MTLStorageModePrivate kullan
 * - MTLCommandBuffer.addCompletedHandler kullan
 */
class MetalRenderer : public RendererInterface {
public:
    MetalRenderer();
    ~MetalRenderer() override;

    // RendererInterface implementation
    bool initialize() override;
    void shutdown() override;
    void setOutputSize(int32_t width, int32_t height) override;
    void setVideoSettings(const VideoSettings& settings) override;
    void beginFrame() override;
    GPUTexture endFrame() override;
    void clear(float r, float g, float b, float a) override;
    void renderMedia(const Asset& asset, TimeMs localTime) override;
    void renderText(const Asset& asset, TimeMs localTime) override;
    void renderShader(const Asset& asset, ShaderManager* shaderManager, TimeMs localTime) override;
    void renderVisualizer(const Asset& asset, const std::vector<FFTData>& fftData, TimeMs localTime) override;
    bool compileShader(const std::string& shaderId, const std::string& vertexSource, const std::string& fragmentSource) override;
    void bindShader(const std::string& shaderId) override;
    void setUniform(const std::string& name, float value) override;
    void setUniform(const std::string& name, float x, float y) override;
    void setUniform(const std::string& name, float x, float y, float z) override;
    void setUniform(const std::string& name, float x, float y, float z, float w) override;
    void setUniform(const std::string& name, int value) override;
    void setTexture(const std::string& name, const GPUTexture& texture, int unit) override;
    GPUTexture loadTexture(const std::string& path) override;
    void unloadTexture(GPUTexture& texture) override;
    NativeSurface getEncoderSurface() override;
    bool setEncoderSurface(const NativeSurface& surface) override;
    bool presentFrame(int64_t ptsUs) override;

#ifdef __OBJC__
    // iOS specific
    void setMetalLayer(CAMetalLayer* layer);
#endif

    void setMetalLayer(void* metalLayer);

private:
    friend class vidviz::ios::text::TextRendererIOS;
    friend class vidviz::ios::text::TextRendererIOSImpl;

    struct CounterTextTextureInfo {
        void* tex = nullptr; // id<MTLTexture>
        int32_t width = 0;
        int32_t height = 0;
    };

    // Metal handles (stored as void* for C++ compatibility)
    void* m_device = nullptr;          // id<MTLDevice>
    void* m_commandQueue = nullptr;    // id<MTLCommandQueue>
    void* m_metalLayer = nullptr;      // CAMetalLayer*
    void* m_textureCache = nullptr;    // CVMetalTextureCacheRef
    
    // Current frame
    void* m_currentDrawable = nullptr; // id<CAMetalDrawable>
    void* m_commandBuffer = nullptr;   // id<MTLCommandBuffer>
    void* m_renderEncoder = nullptr;   // id<MTLRenderCommandEncoder>
    
    // Output size
    int32_t m_width = 1920;
    int32_t m_height = 1080;

    // Video settings (export/preview parity)
    int32_t m_cropMode = 0; // 0=fit, 1=fill, 2=stretch
    float m_rotationDeg = 0.0f;
    bool m_flipH = false;
    bool m_flipV = false;
    float m_bgR = 0.0f;
    float m_bgG = 0.0f;
    float m_bgB = 0.0f;
    float m_bgA = 1.0f;

    // Optional UI preview metrics (Flutter) for parity.
    // Used to convert UI logical-pixel params to export pixel space.
    float m_uiPlayerWidth = 0.0f;
    float m_uiPlayerHeight = 0.0f;
    float m_uiDevicePixelRatio = 0.0f;

    // Export (encoder) path
    bool m_hasEncoderSurface = false;
    IosEncoderSurface* m_encoderSurface = nullptr;
    MetalExportSession m_exportSession;

    void* m_videoPipeline = nullptr;      // id<MTLRenderPipelineState>
    void* m_videoSampler = nullptr;       // id<MTLSamplerState>
    void* m_overlayPipeline = nullptr;    // id<MTLRenderPipelineState>
    void* m_effectPipeline = nullptr;     // id<MTLRenderPipelineState>
    void* m_counterTextPipeline = nullptr; // id<MTLRenderPipelineState>
    std::unordered_map<std::string, CounterTextTextureInfo> m_counterTextTextures;

    // Post-process (shader) path for export: render scene to offscreen, apply shader passes,
    // then blit into encoder's target texture.
    void* m_ppTexA = nullptr;             // id<MTLTexture>
    void* m_ppTexB = nullptr;             // id<MTLTexture>
    bool m_ppUseAAsSrc = true;

    std::string m_videoPath;
    void* m_videoAsset = nullptr;         // AVAsset*
    void* m_videoReader = nullptr;        // AVAssetReader*
    void* m_videoOutput = nullptr;        // AVAssetReaderTrackOutput*
    void* m_videoLastSample = nullptr;    // CMSampleBufferRef
    int64_t m_videoLastPtsUs = -1;
    float m_videoPreferredRotationDeg = 0.0f;

    std::string m_overlayVideoPath;
    void* m_overlayVideoAsset = nullptr;
    void* m_overlayVideoReader = nullptr;
    void* m_overlayVideoOutput = nullptr;
    void* m_overlayVideoLastSample = nullptr;
    int64_t m_overlayVideoLastPtsUs = -1;
    float m_overlayVideoPreferredRotationDeg = 0.0f;

    std::string m_imagePath;
    void* m_imageTexture = nullptr;       // id<MTLTexture>

    std::unordered_map<std::string, void*> m_loadedTextures; // path -> id<MTLTexture>
    
    // Helper methods
    bool createDevice();
    bool createCommandQueue();
    bool createTextureCache();
    bool ensureVideoPipeline();
    bool ensureOverlayPipeline();
    bool ensureEffectPipeline();
    void resetVideoDecoder();
    void resetOverlayVideoDecoder();
    void cleanup();

    bool ensurePostProcessTextures();
    void* currentPostProcessSrcTexture() const;
    void* currentPostProcessDstTexture() const;
    void swapPostProcessTextures();

    std::unordered_map<std::string, void*> m_shaderPipelines; // id<MTLRenderPipelineState>
    std::unordered_map<std::string, std::unordered_map<std::string, uint32_t>> m_shaderUniformOffsets;
    std::unordered_map<std::string, uint32_t> m_shaderUniformBufferSizes;
    std::unordered_map<std::string, std::unordered_map<std::string, uint32_t>> m_shaderTextureIndices;

    std::string m_boundShaderId;
    std::vector<uint8_t> m_uniformStaging;
    std::unordered_map<int, void*> m_boundTextures;

    void* m_visualizerPipeline = nullptr; // id<MTLRenderPipelineState>

    vidviz::ios::text::TextRendererIOS* m_textRenderer = nullptr;
};

} // namespace ios
} // namespace vidviz
