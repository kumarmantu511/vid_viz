#pragma once

#include "platform/renderer_interface.h"

#include <android/native_window.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <string>
#include <unordered_map>
#include <vector>

#include "platform/android/gl_external_oes_renderer.h"
#include "platform/android/gl_framebuffer.h"
#include "platform/android/gl_quad_renderer.h"
#include "platform/android/ndk_video_decoder.h"
#include "platform/android/ndk_video_decoder_gpu.h"

namespace vidviz {

class ShaderManager;

namespace android {

class GlesSurfaceRenderer final : public RendererInterface {
public:
    GlesSurfaceRenderer();
    ~GlesSurfaceRenderer() override;

    bool initialize() override;
    void shutdown() override;
    void setOutputSize(int32_t width, int32_t height) override;
    void setVideoSettings(const VideoSettings& settings) override;
    void beginFrame() override;
    GPUTexture endFrame() override;
    void clear(float r, float g, float b, float a) override;

    void renderMedia(const Asset& asset, TimeMs localTime) override;
    void renderText(const Asset& asset, TimeMs localTime) override;
    void renderShader(const Asset& asset, vidviz::ShaderManager* shaderManager, TimeMs localTime) override;
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

    const std::string& getVideoDecodePath() const { return m_videoDecodePath; }
    const std::string& getVideoDecodeError() const { return m_videoDecodeError; }

    bool getLastSetEncoderSurfaceOk() const { return m_lastSetEncoderSurfaceOk; }
    int64_t getPresentOkCount() const { return m_presentOkCount; }
    int64_t getPresentFailCount() const { return m_presentFailCount; }
    uint32_t getLastEglError() const { return m_lastEglError; }
    const std::string& getLastPresentError() const { return m_lastPresentError; }

    const std::string& getLastShaderId() const { return m_lastShaderId; }
    const std::string& getLastShaderCompileError() const { return m_lastShaderCompileError; }

private:
    struct GlShaderProgram {
        GLuint program = 0;
        GLint posLoc = -1;
        GLint uvLoc = -1;
        GLint uTexLoc = -1;
        GLint uTextureLoc = -1;
        std::unordered_map<std::string, GLint> uniformLocs;
    };

    struct GlTextEffectProgram {
        GLuint program = 0;
        GLint posLoc = -1;
        GLint uvLoc = -1;
        GLint uMaskLoc = -1;
        GLint uAlphaLoc = -1;
        GLuint vbo = 0;
    };

    struct TextTextureInfo {
        GLuint texId = 0;
        int32_t width = 0;
        int32_t height = 0;
        float inkCenterDxPx = 0.0f;
        float inkCenterDyPx = 0.0f;
    };

    bool ensureEgl();
    void destroyEglSurface();
    void cleanupEgl();

    ANativeWindow* m_window = nullptr;

    EGLDisplay m_display = EGL_NO_DISPLAY;
    EGLContext m_context = EGL_NO_CONTEXT;
    EGLSurface m_surface = EGL_NO_SURFACE;
    EGLConfig m_config = nullptr;

    int32_t m_width = 1920;
    int32_t m_height = 1080;

    // Optional UI preview metrics (Flutter) for parity.
    // Used to convert UI logical-pixel params to export pixel space.
    float m_uiPlayerWidth = 0.0f;
    float m_uiPlayerHeight = 0.0f;
    float m_uiDevicePixelRatio = 0.0f;

    // Global video settings (from Flutter UI)
    int32_t m_cropMode = 0; // 0=fit, 1=fill, 2=stretch
    int32_t m_rotation = 0; // 0/90/180/270
    bool m_flipHorizontal = false;
    bool m_flipVertical = false;
    float m_bgR = 0.0f;
    float m_bgG = 0.0f;
    float m_bgB = 0.0f;

    NdkVideoDecoder m_videoDecoder;
    std::string m_currentVideoPath;
    std::string m_videoDecodePath;
    std::string m_videoDecodeError;
    std::vector<uint8_t> m_rgbaBuffer;
    int32_t m_srcW = 0;
    int32_t m_srcH = 0;
    GLuint m_rgbaTex = 0;
    bool m_hasFrame = false;

    GlQuadRenderer m_quad;

    // Textured quad rendering into current FBO (for images and overlays)
    GLuint m_texQuadProgram = 0;
    GLint m_texQuadPosLoc = -1;
    GLint m_texQuadUvLoc = -1;
    GLint m_texQuadTexLoc = -1;
    GLint m_texQuadAlphaLoc = -1;
    GLint m_texQuadSizeLoc = -1;
    GLint m_texQuadRadiusLoc = -1;
    GLint m_texQuadUvRectLoc = -1;
    GLuint m_texQuadVbo = 0;

    // External OES textured quad rendering (for overlay videos)
    GLuint m_oesQuadProgram = 0;
    GLint m_oesQuadPosLoc = -1;
    GLint m_oesQuadUvLoc = -1;
    GLint m_oesQuadTexLoc = -1;
    GLint m_oesQuadAlphaLoc = -1;
    GLint m_oesQuadSizeLoc = -1;
    GLint m_oesQuadRadiusLoc = -1;
    GLint m_oesQuadUvRectLoc = -1;
    GLuint m_oesQuadVbo = 0;

    GlFramebuffer m_sceneFbo;
    GlFramebuffer m_pingFbo;

    GlFramebuffer* m_currentFbo = nullptr;
    GlFramebuffer* m_altFbo = nullptr;

    std::unordered_map<std::string, GlShaderProgram> m_shaderPrograms;
    GLuint m_shaderPassVbo = 0;

    // Keep raw shader sources from job so renderText can build alpha-mask wrappers.
    std::unordered_map<std::string, std::string> m_shaderSources;

    // Text rendering caches
    std::unordered_map<std::string, TextTextureInfo> m_textTextures;
    std::unordered_map<std::string, GlTextEffectProgram> m_textEffectPrograms;

    std::unordered_map<std::string, GLuint> m_loadedTextures;
    std::unordered_map<std::string, GPUTexture> m_loadedTextureInfo;

    NdkVideoDecoderGpu m_videoDecoderGpu;
    GlExternalOesRenderer m_oes;
    GLuint m_oesTex = 0;
    bool m_hasOesFrame = false;
    struct AHardwareBuffer* m_lastHwBuffer = nullptr;

    // Overlay video path (media overlay)
    NdkVideoDecoderGpu m_overlayVideoDecoderGpu;
    GlExternalOesRenderer m_overlayOes;
    GLuint m_overlayOesTex = 0;
    struct AHardwareBuffer* m_overlayLastHwBuffer = nullptr;
    std::string m_currentOverlayVideoPath;

    using PresentationTimeFn = EGLBoolean (*)(EGLDisplay, EGLSurface, EGLnsecsANDROID);
    PresentationTimeFn m_presentationTimeFn = nullptr;

    bool m_lastSetEncoderSurfaceOk = false;
    int64_t m_presentOkCount = 0;
    int64_t m_presentFailCount = 0;
    uint32_t m_lastEglError = 0;
    std::string m_lastPresentError;

    std::string m_lastShaderId;
    std::string m_lastShaderCompileError;
};

} // namespace android
} // namespace vidviz
