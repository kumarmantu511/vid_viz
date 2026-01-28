#pragma once

#include <cstdint>

#include <EGL/egl.h>
#include <EGL/eglext.h>

#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>

struct AHardwareBuffer;

namespace vidviz {
namespace android {

class GlExternalOesRenderer {
public:
    GlExternalOesRenderer();
    ~GlExternalOesRenderer();

    GlExternalOesRenderer(const GlExternalOesRenderer&) = delete;
    GlExternalOesRenderer& operator=(const GlExternalOesRenderer&) = delete;

    bool initialize();
    void shutdown(EGLDisplay display);

    // Imports AHardwareBuffer into EGLImage and binds it to an OES texture.
    // Returns the OES texture id (owned by renderer).
    GLuint bindHardwareBuffer(AHardwareBuffer* buffer, EGLDisplay display);

    void draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint oesTex);
    void draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint oesTex, int32_t cropMode);

private:
    bool ensureEglExt();
    GLuint compile(GLenum type, const char* src);
    bool link(GLuint vs, GLuint fs);
    void destroyEglImage(EGLDisplay display);

private:
    PFNEGLGETNATIVECLIENTBUFFERANDROIDPROC m_getNativeClientBufferANDROID = nullptr;
    PFNEGLCREATEIMAGEKHRPROC m_createImageKHR = nullptr;
    PFNEGLDESTROYIMAGEKHRPROC m_destroyImageKHR = nullptr;
    PFNGLEGLIMAGETARGETTEXTURE2DOESPROC m_imageTargetTexture2DOES = nullptr;

    GLuint m_program = 0;
    GLint m_posLoc = -1;
    GLint m_uvLoc = -1;
    GLint m_texLoc = -1;

    GLuint m_vbo = 0;
    GLuint m_oesTex = 0;

    EGLImageKHR m_image = EGL_NO_IMAGE_KHR;
};

} // namespace android
} // namespace vidviz
