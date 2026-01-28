#include "gl_quad_renderer.h"

#include "common/log.h"

#include <cmath>

namespace vidviz {
namespace android {

GlQuadRenderer::GlQuadRenderer() = default;

GlQuadRenderer::~GlQuadRenderer() {
    shutdown();
}

GLuint GlQuadRenderer::compile(GLenum type, const char* src) {
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

bool GlQuadRenderer::link(GLuint vs, GLuint fs) {
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

bool GlQuadRenderer::initialize() {
    if (m_program) return true;

    static const char* kVS =
        "#version 300 es\n"
        "in vec2 aPos;\n"
        "in vec2 aUV;\n"
        "out vec2 vUV;\n"
        "void main(){\n"
        "  vUV=aUV;\n"
        "  gl_Position=vec4(aPos,0.0,1.0);\n"
        "}\n";

    static const char* kFS =
        "#version 300 es\n"
        "precision highp float;\n"
        "in vec2 vUV;\n"
        "out vec4 fragColor;\n"
        "uniform sampler2D uTex;\n"
        "void main(){\n"
        "  fragColor=texture(uTex,vUV);\n"
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
    return m_vbo != 0;
}

void GlQuadRenderer::shutdown() {
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
}

void GlQuadRenderer::draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint rgbaTex) {
    draw(dstW, dstH, srcW, srcH, rgbaTex, 0, false, false);
}

void GlQuadRenderer::draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint rgbaTex, int32_t rotation, bool flipH, bool flipV) {
    if (!rgbaTex) return;
    if (!initialize()) return;
    if (dstW <= 0 || dstH <= 0 || srcW <= 0 || srcH <= 0) return;

    const float dstAspect = static_cast<float>(dstW) / static_cast<float>(dstH);
    const float srcAspect = static_cast<float>(srcW) / static_cast<float>(srcH);

    float sx = 1.0f;
    float sy = 1.0f;
    if (srcAspect > dstAspect) {
        sy = dstAspect / srcAspect;
    } else {
        sx = srcAspect / dstAspect;
    }

    auto transformUv = [flipH, flipV, rotation](float u, float v, float& outU, float& outV) {
        float tu = u;
        float tv = v;
        if (flipH) tu = 1.0f - tu;
        if (flipV) tv = 1.0f - tv;

        const int r = ((rotation % 360) + 360) % 360;
        switch (r) {
            case 90: {
                const float nu = tv;
                const float nv = 1.0f - tu;
                tu = nu;
                tv = nv;
                break;
            }
            case 180:
                tu = 1.0f - tu;
                tv = 1.0f - tv;
                break;
            case 270: {
                const float nu = 1.0f - tv;
                const float nv = tu;
                tu = nu;
                tv = nv;
                break;
            }
            default:
                break;
        }
        outU = tu;
        outV = tv;
    };

    float uBL = 0.0f, vBL = 0.0f;
    float uBR = 1.0f, vBR = 0.0f;
    float uTL = 0.0f, vTL = 1.0f;
    float uTR = 1.0f, vTR = 1.0f;

    float tU, tV;
    transformUv(0.0f, 0.0f, tU, tV); uBL = tU; vBL = tV;
    transformUv(1.0f, 0.0f, tU, tV); uBR = tU; vBR = tV;
    transformUv(0.0f, 1.0f, tU, tV); uTL = tU; vTL = tV;
    transformUv(1.0f, 1.0f, tU, tV); uTR = tU; vTR = tV;

    const float verts[] = {
        -sx, -sy, uBL, vBL,
         sx, -sy, uBR, vBR,
        -sx,  sy, uTL, vTL,
         sx,  sy, uTR, vTR
    };

    glViewport(0, 0, dstW, dstH);
    glUseProgram(m_program);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, rgbaTex);
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
    glBindTexture(GL_TEXTURE_2D, 0);
}

} // namespace android
} // namespace vidviz
