#include "gl_external_oes_renderer.h"

#include "common/log.h"

#include <android/hardware_buffer.h>

namespace vidviz {
namespace android {

GlExternalOesRenderer::GlExternalOesRenderer() = default;

GlExternalOesRenderer::~GlExternalOesRenderer() {
    shutdown(EGL_NO_DISPLAY);
}

bool GlExternalOesRenderer::ensureEglExt() {
    if (m_getNativeClientBufferANDROID && m_createImageKHR && m_destroyImageKHR && m_imageTargetTexture2DOES) {
        return true;
    }

    m_getNativeClientBufferANDROID = reinterpret_cast<PFNEGLGETNATIVECLIENTBUFFERANDROIDPROC>(
        eglGetProcAddress("eglGetNativeClientBufferANDROID"));
    m_createImageKHR = reinterpret_cast<PFNEGLCREATEIMAGEKHRPROC>(eglGetProcAddress("eglCreateImageKHR"));
    m_destroyImageKHR = reinterpret_cast<PFNEGLDESTROYIMAGEKHRPROC>(eglGetProcAddress("eglDestroyImageKHR"));
    m_imageTargetTexture2DOES = reinterpret_cast<PFNGLEGLIMAGETARGETTEXTURE2DOESPROC>(
        eglGetProcAddress("glEGLImageTargetTexture2DOES"));

    return (m_getNativeClientBufferANDROID && m_createImageKHR && m_destroyImageKHR && m_imageTargetTexture2DOES);
}

GLuint GlExternalOesRenderer::compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);

    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glDeleteShader(s);
        return 0;
    }
    return s;
}

bool GlExternalOesRenderer::link(GLuint vs, GLuint fs) {
    m_program = glCreateProgram();
    glAttachShader(m_program, vs);
    glAttachShader(m_program, fs);
    glLinkProgram(m_program);

    GLint ok = 0;
    glGetProgramiv(m_program, GL_LINK_STATUS, &ok);
    if (!ok) {
        glDeleteProgram(m_program);
        m_program = 0;
        return false;
    }

    m_posLoc = glGetAttribLocation(m_program, "aPos");
    m_uvLoc = glGetAttribLocation(m_program, "aUV");
    m_texLoc = glGetUniformLocation(m_program, "uTex");
    return true;
}

bool GlExternalOesRenderer::initialize() {
    if (m_program) return true;
    if (!ensureEglExt()) return false;

    static const char* kVS =
        "#version 300 es\n"
        "in vec2 aPos;\n"
        "in vec2 aUV;\n"
        "out vec2 vUV;\n"
        "void main(){\n"
        "  vUV=aUV;\n"
        "  gl_Position=vec4(aPos,0.0,1.0);\n"
        "}\n";

    // samplerExternalOES is required for GL_TEXTURE_EXTERNAL_OES.
    static const char* kFS =
        "#version 300 es\n"
        "#extension GL_OES_EGL_image_external_essl3 : require\n"
        "precision highp float;\n"
        "in vec2 vUV;\n"
        "out vec4 fragColor;\n"
        "uniform samplerExternalOES uTex;\n"
        "void main(){\n"
        "  fragColor = texture(uTex, vUV);\n"
        "}\n";

    GLuint vs = compile(GL_VERTEX_SHADER, kVS);
    GLuint fs = compile(GL_FRAGMENT_SHADER, kFS);
    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return false;
    }

    const bool ok = link(vs, fs);
    glDeleteShader(vs);
    glDeleteShader(fs);
    if (!ok) return false;

    glGenBuffers(1, &m_vbo);

    glGenTextures(1, &m_oesTex);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, m_oesTex);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);

    return (m_vbo != 0 && m_oesTex != 0);
}

void GlExternalOesRenderer::destroyEglImage(EGLDisplay display) {
    if (m_image != EGL_NO_IMAGE_KHR) {
        if (m_destroyImageKHR) {
            m_destroyImageKHR(display, m_image);
        }
        m_image = EGL_NO_IMAGE_KHR;
    }
}

void GlExternalOesRenderer::shutdown(EGLDisplay display) {
    if (display != EGL_NO_DISPLAY) {
        destroyEglImage(display);
    }
    if (m_oesTex) {
        glDeleteTextures(1, &m_oesTex);
        m_oesTex = 0;
    }
    if (m_vbo) {
        glDeleteBuffers(1, &m_vbo);
        m_vbo = 0;
    }
    if (m_program) {
        glDeleteProgram(m_program);
        m_program = 0;
    }
    m_posLoc = -1;
    m_uvLoc = -1;
    m_texLoc = -1;

    m_image = EGL_NO_IMAGE_KHR;
}

GLuint GlExternalOesRenderer::bindHardwareBuffer(AHardwareBuffer* buffer, EGLDisplay display) {
    if (!buffer) return 0;
    if (!initialize()) return 0;
    if (!ensureEglExt()) return 0;

    destroyEglImage(display);

    EGLClientBuffer clientBuffer = m_getNativeClientBufferANDROID(buffer);
    if (!clientBuffer) return 0;

    const EGLint attrs[] = {EGL_IMAGE_PRESERVED_KHR, EGL_TRUE, EGL_NONE};
    m_image = m_createImageKHR(display, EGL_NO_CONTEXT, EGL_NATIVE_BUFFER_ANDROID, clientBuffer, attrs);
    if (m_image == EGL_NO_IMAGE_KHR) return 0;

    glBindTexture(GL_TEXTURE_EXTERNAL_OES, m_oesTex);
    m_imageTargetTexture2DOES(GL_TEXTURE_EXTERNAL_OES, (GLeglImageOES)m_image);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);

    return m_oesTex;
}

void GlExternalOesRenderer::draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint oesTex) {
    draw(dstW, dstH, srcW, srcH, oesTex, 0);
}

void GlExternalOesRenderer::draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint oesTex, int32_t cropMode) {
    if (!oesTex) return;
    if (!initialize()) return;
    if (dstW <= 0 || dstH <= 0 || srcW <= 0 || srcH <= 0) return;

    const float dstAspect = static_cast<float>(dstW) / static_cast<float>(dstH);
    const float srcAspect = static_cast<float>(srcW) / static_cast<float>(srcH);

    float sx = 1.0f;
    float sy = 1.0f;

    float u0 = 0.0f, u1 = 1.0f;
    float vTop = 0.0f, vBottom = 1.0f; // OES path uses inverted V

    if (cropMode == 2) {
        // stretch: full screen, full texture
        sx = 1.0f;
        sy = 1.0f;
    } else if (cropMode == 1) {
        // fill: cover screen, crop center in UV
        sx = 1.0f;
        sy = 1.0f;
        if (srcAspect > dstAspect) {
            const float keep = dstAspect / srcAspect;
            const float m = (1.0f - keep) * 0.5f;
            u0 = m;
            u1 = 1.0f - m;
        } else {
            const float keep = srcAspect / dstAspect;
            const float m = (1.0f - keep) * 0.5f;
            vTop = m;
            vBottom = 1.0f - m;
        }
    } else {
        // fit: letterbox/pillarbox, scale quad
        if (srcAspect > dstAspect) {
            sy = dstAspect / srcAspect;
        } else {
            sx = srcAspect / dstAspect;
        }
    }

    const float verts[] = {
        -sx, -sy, u0, vBottom,
         sx, -sy, u1, vBottom,
        -sx,  sy, u0, vTop,
         sx,  sy, u1, vTop,
    };

    glViewport(0, 0, dstW, dstH);
    glUseProgram(m_program);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, oesTex);
    glUniform1i(m_texLoc, 0);

    glBindBuffer(GL_ARRAY_BUFFER, m_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    glEnableVertexAttribArray(static_cast<GLuint>(m_posLoc));
    glVertexAttribPointer(static_cast<GLuint>(m_posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);

    glEnableVertexAttribArray(static_cast<GLuint>(m_uvLoc));
    glVertexAttribPointer(static_cast<GLuint>(m_uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glDisableVertexAttribArray(static_cast<GLuint>(m_posLoc));
    glDisableVertexAttribArray(static_cast<GLuint>(m_uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);
}

} // namespace android
} // namespace vidviz
