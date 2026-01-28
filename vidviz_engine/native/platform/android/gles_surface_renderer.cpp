#include "gles_surface_renderer.h"

#include "common/log.h"
 #include "effects/shader_manager.h"
 #include "platform/android/renderer/gles/shader_source_utils.h"
 #include "platform/android/renderer/gles/text_rasterizer.h"
 #include "platform/android/renderer/gles/overlay_renderer.h"
 #include "platform/android/renderer/gles/visualizer_renderer.h"

#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>

#include <android/hardware_buffer.h>
#include <android/bitmap.h>
#include <android/log.h>
#include <jni.h>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstring>
#include <cstdint>
#include <limits>
 #include <utility>

#include "common/minijson.h"

namespace vidviz {
namespace android {

extern JavaVM* g_vidvizJvm;
JavaVM* getJavaVmFallback();

namespace {

static int32_t getCachedGlMaxTextureSize() {
    static int32_t s_cached = 0;
    if (s_cached > 0) return s_cached;

    GLint v = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &v);
    if (v <= 0) v = 2048;
    s_cached = static_cast<int32_t>(v);
    return s_cached;
}

static void flipRgbaHorizontal(std::vector<uint8_t>& rgba, int32_t w, int32_t h) {
    if (w <= 1 || h <= 0) return;
    const size_t rowBytes = static_cast<size_t>(w) * 4u;
    for (int32_t y = 0; y < h; y++) {
        uint8_t* row = rgba.data() + static_cast<size_t>(y) * rowBytes;
        for (int32_t x = 0; x < w / 2; x++) {
            uint8_t* a = row + static_cast<size_t>(x) * 4u;
            uint8_t* b = row + static_cast<size_t>(w - 1 - x) * 4u;
            for (int k = 0; k < 4; k++) std::swap(a[k], b[k]);
        }
    }
}

static void pushTexturedQuadXform(
    GLuint program,
    GLint posLoc,
    GLint uvLoc,
    GLint texLoc,
    GLint alphaLoc,
    GLint sizeLoc,
    GLint radiusLoc,
    GLuint vbo,
    int32_t dstW,
    int32_t dstH,
    GLuint texId,
    float cxN,
    float cyN,
    float quadWpx,
    float quadHpx,
    float rotationDeg,
    float alpha,
    float radiusPx,
    float scaleX,
    float scaleY
) {
    if (!program || !vbo || !texId) return;
    if (dstW <= 0 || dstH <= 0) return;
    if (quadWpx <= 0.0f || quadHpx <= 0.0f) return;

    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;

    if (!std::isfinite(scaleX) || std::fabs(scaleX) < 0.0001f) scaleX = 1.0f;
    if (!std::isfinite(scaleY) || std::fabs(scaleY) < 0.0001f) scaleY = 1.0f;

    const float cxPx = cxN * static_cast<float>(dstW);
    const float cyPx = cyN * static_cast<float>(dstH);
    const float hxPx = 0.5f * quadWpx * scaleX;
    const float hyPx = 0.5f * quadHpx * scaleY;

    const float rad = rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rotPx = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float xPx) -> float {
        return (xPx / static_cast<float>(dstW)) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float yPx) -> float {
        return 1.0f - (yPx / static_cast<float>(dstH)) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rotPx(-hxPx, -hyPx, x0p, y0p);
    rotPx( hxPx, -hyPx, x1p, y1p);
    rotPx(-hxPx,  hyPx, x2p, y2p);
    rotPx( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    const float verts[] = {
        x0, y0, 0.0f, 0.0f,
        x1, y1, 1.0f, 0.0f,
        x2, y2, 0.0f, 1.0f,
        x3, y3, 1.0f, 1.0f,
    };

    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texId);
    if (texLoc >= 0) glUniform1i(texLoc, 0);
    if (alphaLoc >= 0) glUniform1f(alphaLoc, alpha);
    if (sizeLoc >= 0) glUniform2f(sizeLoc, std::fabs(quadWpx * scaleX), std::fabs(quadHpx * scaleY));
    if (radiusLoc >= 0) glUniform1f(radiusLoc, radiusPx);
    {
        const GLint uvRectLoc = glGetUniformLocation(program, "uUvRect");
        if (uvRectLoc >= 0) glUniform4f(uvRectLoc, 0.0f, 0.0f, 1.0f, 1.0f);
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(posLoc));
        glVertexAttribPointer(static_cast<GLuint>(posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(posLoc));
    if (uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

static void pushTexturedQuadXformUVRect(
    GLuint program,
    GLint posLoc,
    GLint uvLoc,
    GLint texLoc,
    GLint alphaLoc,
    GLint sizeLoc,
    GLint radiusLoc,
    GLint uvRectLoc,
    GLuint vbo,
    int32_t dstW,
    int32_t dstH,
    GLuint texId,
    float cxN,
    float cyN,
    float quadWpx,
    float quadHpx,
    float rotationDeg,
    float alpha,
    float radiusPx,
    float scaleX,
    float scaleY,
    float fitScaleX,
    float fitScaleY,
    float fitOffX,
    float fitOffY,
    float u0,
    float v0,
    float u1,
    float v1
) {
    if (!std::isfinite(u0)) u0 = 0.0f;
    if (!std::isfinite(v0)) v0 = 0.0f;
    if (!std::isfinite(u1)) u1 = 1.0f;
    if (!std::isfinite(v1)) v1 = 1.0f;
    u0 = std::max(0.0f, std::min(1.0f, u0));
    v0 = std::max(0.0f, std::min(1.0f, v0));
    u1 = std::max(0.0f, std::min(1.0f, u1));
    v1 = std::max(0.0f, std::min(1.0f, v1));

    if (!program || !vbo || !texId) return;
    if (dstW <= 0 || dstH <= 0) return;
    if (quadWpx <= 0.0f || quadHpx <= 0.0f) return;

    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;

    if (!std::isfinite(scaleX) || std::fabs(scaleX) < 0.0001f) scaleX = 1.0f;
    if (!std::isfinite(scaleY) || std::fabs(scaleY) < 0.0001f) scaleY = 1.0f;

    const float cxPx = cxN * static_cast<float>(dstW);
    const float cyPx = cyN * static_cast<float>(dstH);
    const float hxPx = 0.5f * quadWpx * scaleX;
    const float hyPx = 0.5f * quadHpx * scaleY;

    const float rad = rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rotPx = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float xPx) -> float {
        return (xPx / static_cast<float>(dstW)) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float yPx) -> float {
        return 1.0f - (yPx / static_cast<float>(dstH)) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rotPx(-hxPx, -hyPx, x0p, y0p);
    rotPx( hxPx, -hyPx, x1p, y1p);
    rotPx(-hxPx,  hyPx, x2p, y2p);
    rotPx( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    const float verts[] = {
        x0, y0, 0.0f, 0.0f,
        x1, y1, 1.0f, 0.0f,
        x2, y2, 0.0f, 1.0f,
        x3, y3, 1.0f, 1.0f,
    };

    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texId);
    if (texLoc >= 0) glUniform1i(texLoc, 0);
    if (alphaLoc >= 0) glUniform1f(alphaLoc, alpha);
    if (sizeLoc >= 0) glUniform2f(sizeLoc, std::fabs(quadWpx * scaleX), std::fabs(quadHpx * scaleY));
    if (radiusLoc >= 0) glUniform1f(radiusLoc, radiusPx);
    if (uvRectLoc >= 0) glUniform4f(uvRectLoc, u0, v0, u1, v1);
    {
        const GLint fitScaleLoc = glGetUniformLocation(program, "uFitScale");
        if (fitScaleLoc >= 0) glUniform2f(fitScaleLoc, fitScaleX, fitScaleY);
        const GLint fitOffLoc = glGetUniformLocation(program, "uFitOffset");
        if (fitOffLoc >= 0) glUniform2f(fitOffLoc, fitOffX, fitOffY);
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(posLoc));
        glVertexAttribPointer(static_cast<GLuint>(posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(posLoc));
    if (uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

static void pushOesQuadUVRect(
    GLuint program,
    GLint posLoc,
    GLint uvLoc,
    GLint texLoc,
    GLint alphaLoc,
    GLint sizeLoc,
    GLint radiusLoc,
    GLint uvRectLoc,
    GLuint vbo,
    int32_t dstW,
    int32_t dstH,
    GLuint oesTex,
    float cxN,
    float cyN,
    float quadWpx,
    float quadHpx,
    float rotationDeg,
    float alpha,
    float radiusPx,
    float fitScaleX,
    float fitScaleY,
    float fitOffX,
    float fitOffY,
    float u0,
    float v0,
    float u1,
    float v1
) {
    if (!std::isfinite(u0)) u0 = 0.0f;
    if (!std::isfinite(v0)) v0 = 0.0f;
    if (!std::isfinite(u1)) u1 = 1.0f;
    if (!std::isfinite(v1)) v1 = 1.0f;
    u0 = std::max(0.0f, std::min(1.0f, u0));
    v0 = std::max(0.0f, std::min(1.0f, v0));
    u1 = std::max(0.0f, std::min(1.0f, u1));
    v1 = std::max(0.0f, std::min(1.0f, v1));

    if (!program || !vbo || !oesTex) return;
    if (dstW <= 0 || dstH <= 0) return;
    if (quadWpx <= 0.0f || quadHpx <= 0.0f) return;

    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;

    const float cxPx = cxN * static_cast<float>(dstW);
    const float cyPx = cyN * static_cast<float>(dstH);
    const float hxPx = 0.5f * quadWpx;
    const float hyPx = 0.5f * quadHpx;

    const float rad = rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rot = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float xPx) -> float {
        return (xPx / static_cast<float>(dstW)) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float yPx) -> float {
        return 1.0f - (yPx / static_cast<float>(dstH)) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rot(-hxPx, -hyPx, x0p, y0p);
    rot( hxPx, -hyPx, x1p, y1p);
    rot(-hxPx,  hyPx, x2p, y2p);
    rot( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    const float verts[] = {
        x0, y0, 0.0f, 0.0f,
        x1, y1, 1.0f, 0.0f,
        x2, y2, 0.0f, 1.0f,
        x3, y3, 1.0f, 1.0f,
    };

    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, oesTex);
    if (texLoc >= 0) glUniform1i(texLoc, 0);
    if (alphaLoc >= 0) glUniform1f(alphaLoc, alpha);
    if (sizeLoc >= 0) glUniform2f(sizeLoc, quadWpx, quadHpx);
    if (radiusLoc >= 0) glUniform1f(radiusLoc, radiusPx);
    if (uvRectLoc >= 0) glUniform4f(uvRectLoc, u0, v0, u1, v1);
    {
        const GLint fitScaleLoc = glGetUniformLocation(program, "uFitScale");
        if (fitScaleLoc >= 0) glUniform2f(fitScaleLoc, fitScaleX, fitScaleY);
        const GLint fitOffLoc = glGetUniformLocation(program, "uFitOffset");
        if (fitOffLoc >= 0) glUniform2f(fitOffLoc, fitOffX, fitOffY);
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(posLoc));
        glVertexAttribPointer(static_cast<GLuint>(posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(posLoc));
    if (uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);
}

static void pushTexturedQuadXformUV(
    GLuint program,
    GLint posLoc,
    GLint uvLoc,
    GLint texLoc,
    GLint alphaLoc,
    GLint sizeLoc,
    GLint radiusLoc,
    GLint uvRectLoc,
    GLuint vbo,
    int32_t dstW,
    int32_t dstH,
    GLuint texId,
    float cxN,
    float cyN,
    float quadWpx,
    float quadHpx,
    float rotationDeg,
    float alpha,
    float radiusPx,
    float scaleX,
    float scaleY,
    float uMax,
    float vMax
) {
    if (!std::isfinite(uMax)) uMax = 1.0f;
    if (!std::isfinite(vMax)) vMax = 1.0f;
    if (uMax < 0.0f) uMax = 0.0f;
    if (uMax > 1.0f) uMax = 1.0f;
    if (vMax < 0.0f) vMax = 0.0f;
    if (vMax > 1.0f) vMax = 1.0f;

    if (!program || !vbo || !texId) return;
    if (dstW <= 0 || dstH <= 0) return;
    if (quadWpx <= 0.0f || quadHpx <= 0.0f) return;

    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;

    if (!std::isfinite(scaleX) || std::fabs(scaleX) < 0.0001f) scaleX = 1.0f;
    if (!std::isfinite(scaleY) || std::fabs(scaleY) < 0.0001f) scaleY = 1.0f;

    const float cxPx = cxN * static_cast<float>(dstW);
    const float cyPx = cyN * static_cast<float>(dstH);
    const float hxPx = 0.5f * quadWpx * scaleX;
    const float hyPx = 0.5f * quadHpx * scaleY;

    const float rad = rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rotPx = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float xPx) -> float {
        return (xPx / static_cast<float>(dstW)) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float yPx) -> float {
        return 1.0f - (yPx / static_cast<float>(dstH)) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rotPx(-hxPx, -hyPx, x0p, y0p);
    rotPx( hxPx, -hyPx, x1p, y1p);
    rotPx(-hxPx,  hyPx, x2p, y2p);
    rotPx( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    const float verts[] = {
        x0, y0, 0.0f, 0.0f,
        x1, y1, 1.0f, 0.0f,
        x2, y2, 0.0f, 1.0f,
        x3, y3, 1.0f, 1.0f,
    };

    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texId);
    if (texLoc >= 0) glUniform1i(texLoc, 0);
    if (alphaLoc >= 0) glUniform1f(alphaLoc, alpha);
    if (sizeLoc >= 0) glUniform2f(sizeLoc, std::fabs(quadWpx * scaleX), std::fabs(quadHpx * scaleY));
    if (radiusLoc >= 0) glUniform1f(radiusLoc, radiusPx);
    if (uvRectLoc >= 0) glUniform4f(uvRectLoc, 0.0f, 0.0f, uMax, vMax);
    {
        const GLint fitScaleLoc = glGetUniformLocation(program, "uFitScale");
        if (fitScaleLoc >= 0) glUniform2f(fitScaleLoc, 1.0f, 1.0f);
        const GLint fitOffLoc = glGetUniformLocation(program, "uFitOffset");
        if (fitOffLoc >= 0) glUniform2f(fitOffLoc, 0.0f, 0.0f);
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(posLoc));
        glVertexAttribPointer(static_cast<GLuint>(posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(posLoc));
    if (uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

static void flipRgbaVertical(std::vector<uint8_t>& rgba, int32_t w, int32_t h) {
    if (w <= 0 || h <= 1) return;
    const size_t rowBytes = static_cast<size_t>(w) * 4u;
    std::vector<uint8_t> tmp(rowBytes);
    for (int32_t y = 0; y < h / 2; y++) {
        uint8_t* top = rgba.data() + static_cast<size_t>(y) * rowBytes;
        uint8_t* bot = rgba.data() + static_cast<size_t>(h - 1 - y) * rowBytes;
        memcpy(tmp.data(), top, rowBytes);
        memcpy(top, bot, rowBytes);
        memcpy(bot, tmp.data(), rowBytes);
    }
}

struct TextAnimTransform {
    float dxPx = 0.0f;
    float dyPx = 0.0f;
    float scaleX = 1.0f;
    float scaleY = 1.0f;
    float rotationDeg = 0.0f;
};

static int quantizeStep(float v01, int steps) {
    if (!std::isfinite(v01)) v01 = 0.0f;
    if (v01 < 0.0f) v01 = 0.0f;
    if (v01 > 1.0f) v01 = 1.0f;
    if (steps < 1) steps = 1;
    const float s = std::round(v01 * static_cast<float>(steps));
    int i = static_cast<int>(s);
    if (i < 0) i = 0;
    if (i > steps) i = steps;
    return i;
}

static void applyTextDecorAnimQuantized(
    vidviz::android::gles::ParsedTextParams& p,
    float timeSec
) {
    float spd = p.animSpeed;
    if (!std::isfinite(spd)) spd = 1.0f;
    if (spd < 0.2f) spd = 0.2f;
    if (spd > 2.0f) spd = 2.0f;

    if (p.animType == "glow_pulse") {
        float r = p.glowRadius;
        if (!std::isfinite(r)) r = 0.0f;
        if (r < 0.0f) r = 0.0f;
        const float s01 = 0.5f * (1.0f + std::sin(timeSec * spd));
        const int step = quantizeStep(s01, 30);
        const float sq01 = static_cast<float>(step) / 30.0f;
        float rr = r * (0.5f + sq01);
        if (!std::isfinite(rr)) rr = 0.0f;
        if (rr < 0.0f) rr = 0.0f;
        if (rr > 40.0f) rr = 40.0f;
        p.glowRadius = rr;
    } else if (p.animType == "outline_pulse") {
        float bw = p.borderW;
        if (!std::isfinite(bw)) bw = 0.0f;
        if (bw < 0.0f) bw = 0.0f;
        const float s01 = 0.5f * (1.0f + std::sin(timeSec * spd));
        const int step = quantizeStep(s01, 30);
        const float sq01 = static_cast<float>(step) / 30.0f;
        float bbw = bw * (0.5f + sq01);
        if (!std::isfinite(bbw)) bbw = 0.0f;
        if (bbw < 0.0f) bbw = 0.0f;
        if (bbw > 20.0f) bbw = 20.0f;
        p.borderW = bbw;
    } else if (p.animType == "shadow_swing") {
        float A = p.animAmplitude;
        if (!std::isfinite(A)) A = 1.0f;
        if (A < 1.0f) A = 1.0f;
        if (A > 500.0f) A = 500.0f;

        const float kTwoPi = 6.283185307f;
        float ang = timeSec * spd;
        if (!std::isfinite(ang)) ang = 0.0f;
        ang = std::fmod(std::max(0.0f, ang), kTwoPi);
        const float phase01 = ang / kTwoPi;
        const int step = quantizeStep(phase01, 60);
        const float angQ = (static_cast<float>(step) / 60.0f) * kTwoPi;

        float sx = A * std::sin(angQ);
        float sy = A * std::cos(angQ);
        if (!std::isfinite(sx)) sx = 0.0f;
        if (!std::isfinite(sy)) sy = 0.0f;
        p.shadowX = sx;
        p.shadowY = sy;
    }
}

static float clampFinite(float v, float lo, float hi, float fallback) {
    if (!std::isfinite(v)) return fallback;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static float fract01(float x) {
    if (!std::isfinite(x)) return 0.0f;
    const float f = std::fmod(std::max(0.0f, x), 1.0f);
    return (f < 0.0f) ? 0.0f : f;
}

static TextAnimTransform computeTextAnimTransform(
    const vidviz::android::gles::ParsedTextParams& p,
    float timeSec,
    float texW,
    float texH
) {
    (void)texW;
    (void)texH;
    TextAnimTransform t;
    const std::string& a = p.animType;

    const float kPi = 3.1415926535f;

    float spd = clampFinite(p.animSpeed, 0.2f, 2.0f, 1.0f);
    float amp = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
    float ph = std::isfinite(p.animPhase) ? p.animPhase : 0.0f;

    if (a == "bounce") {
        t.dyPx += std::sin(timeSec * spd) * amp;
    } else if (a == "jitter") {
        t.dxPx += std::sin(timeSec * spd + ph) * amp * 0.5f;
        t.dyPx += std::cos(timeSec * (spd * 1.3f) + ph * 1.7f) * amp * 0.5f;
    }

    if (a == "marquee") {
        const float w = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        const float x = fract01(timeSec * spd) * w;
        t.dxPx += -x;
    } else if (a == "pulse") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        float k = 1.0f + 0.05f * aPx * std::sin(timeSec * spd + ph);
        k = clampFinite(k, 0.1f, 5.0f, 1.0f);
        t.scaleX *= k;
        t.scaleY *= k;
    } else if (a == "slide_lr") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dxPx += fract01(timeSec * spd) * aPx;
    } else if (a == "slide_rl") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dxPx += -fract01(timeSec * spd) * aPx;
    } else if (a == "shake_h") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dxPx += std::sin(timeSec * spd * 6.0f) * aPx * 0.5f;
    } else if (a == "shake_v") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 500.0f, 0.0f);
        t.dyPx += std::sin(timeSec * spd * 6.0f) * aPx * 0.5f;
    } else if (a == "rotate") {
        const float aDeg = clampFinite(p.animAmplitude, 0.0f, 720.0f, 0.0f);
        t.rotationDeg += aDeg * std::sin(timeSec * spd);
    } else if (a == "zoom_in") {
        const float p01 = fract01(timeSec * spd);
        const float k = 0.7f + 0.3f * p01;
        t.scaleX *= k;
        t.scaleY *= k;
    } else if (a == "slide_up") {
        float aPx = p.animAmplitude;
        if (!std::isfinite(aPx)) aPx = 40.0f;
        aPx = clampFinite(aPx, 0.0f, 500.0f, 40.0f);
        const float p01 = fract01(timeSec * spd);
        t.dyPx += (1.0f - p01) * aPx;
    } else if (a == "flip_x") {
        const float kx = std::cos(timeSec * spd * kPi);
        const float mag = clampFinite(std::fabs(kx), 0.1f, 1.0f, 1.0f);
        t.scaleX *= mag * ((kx >= 0.0f) ? 1.0f : -1.0f);
    } else if (a == "flip_y") {
        const float ky = std::cos(timeSec * spd * kPi);
        const float mag = clampFinite(std::fabs(ky), 0.1f, 1.0f, 1.0f);
        t.scaleY *= mag * ((ky >= 0.0f) ? 1.0f : -1.0f);
    } else if (a == "pop_in") {
        const float p01 = fract01(timeSec * spd);
        const float eased = 1.0f - std::pow(1.0f - p01, 3.0f);
        const float k = 0.6f + 0.4f * eased;
        t.scaleX *= k;
        t.scaleY *= k;
    } else if (a == "rubber_band") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 100.0f, 0.0f);
        const float f = clampFinite((aPx / 40.0f), 0.0f, 0.4f, 0.0f);
        const float s = std::sin(timeSec * spd * 4.0f + ph);
        float kx = 1.0f + f * s;
        float ky = 1.0f - f * s;
        kx = clampFinite(kx, 0.7f, 1.3f, 1.0f);
        ky = clampFinite(ky, 0.7f, 1.3f, 1.0f);
        t.scaleX *= kx;
        t.scaleY *= ky;
    } else if (a == "wobble") {
        const float aPx = clampFinite(p.animAmplitude, 0.0f, 200.0f, 0.0f);
        const float sway = std::sin(timeSec * spd * 2.0f + ph) * aPx * 0.2f;
        const float angDeg = clampFinite(aPx * 0.2f, 0.0f, 30.0f, 0.0f) * std::sin(timeSec * spd * 2.0f);
        t.dxPx += sway;
        t.rotationDeg += angDeg;
    }

    // Safety
    if (!std::isfinite(t.dxPx)) t.dxPx = 0.0f;
    if (!std::isfinite(t.dyPx)) t.dyPx = 0.0f;
    if (!std::isfinite(t.scaleX) || std::fabs(t.scaleX) < 0.0001f) t.scaleX = 1.0f;
    if (!std::isfinite(t.scaleY) || std::fabs(t.scaleY) < 0.0001f) t.scaleY = 1.0f;
    if (!std::isfinite(t.rotationDeg)) t.rotationDeg = 0.0f;
    return t;
}

static void rotateRgba90CW(std::vector<uint8_t>& rgba, int32_t& w, int32_t& h) {
    if (w <= 0 || h <= 0) return;
    const int32_t srcW = w;
    const int32_t srcH = h;
    std::vector<uint8_t> out(static_cast<size_t>(srcW) * static_cast<size_t>(srcH) * 4u);
    const int32_t dstW = srcH;
    const int32_t dstH = srcW;
    for (int32_t y = 0; y < dstH; y++) {
        for (int32_t x = 0; x < dstW; x++) {
            const int32_t srcX = y;
            const int32_t srcY = srcH - 1 - x;
            const size_t srcI = (static_cast<size_t>(srcY) * static_cast<size_t>(srcW) + static_cast<size_t>(srcX)) * 4u;
            const size_t dstI = (static_cast<size_t>(y) * static_cast<size_t>(dstW) + static_cast<size_t>(x)) * 4u;
            out[dstI + 0] = rgba[srcI + 0];
            out[dstI + 1] = rgba[srcI + 1];
            out[dstI + 2] = rgba[srcI + 2];
            out[dstI + 3] = rgba[srcI + 3];
        }
    }
    rgba.swap(out);
    w = dstW;
    h = dstH;
}

static void rotateRgba270CW(std::vector<uint8_t>& rgba, int32_t& w, int32_t& h) {
    if (w <= 0 || h <= 0) return;
    const int32_t srcW = w;
    const int32_t srcH = h;
    std::vector<uint8_t> out(static_cast<size_t>(srcW) * static_cast<size_t>(srcH) * 4u);
    const int32_t dstW = srcH;
    const int32_t dstH = srcW;
    for (int32_t y = 0; y < dstH; y++) {
        for (int32_t x = 0; x < dstW; x++) {
            const int32_t srcX = srcW - 1 - y;
            const int32_t srcY = x;
            const size_t srcI = (static_cast<size_t>(srcY) * static_cast<size_t>(srcW) + static_cast<size_t>(srcX)) * 4u;
            const size_t dstI = (static_cast<size_t>(y) * static_cast<size_t>(dstW) + static_cast<size_t>(x)) * 4u;
            out[dstI + 0] = rgba[srcI + 0];
            out[dstI + 1] = rgba[srcI + 1];
            out[dstI + 2] = rgba[srcI + 2];
            out[dstI + 3] = rgba[srcI + 3];
        }
    }
    rgba.swap(out);
    w = dstW;
    h = dstH;
}

static void applyExifOrientationRgba(std::vector<uint8_t>& rgba, int32_t& w, int32_t& h, int orientation) {
    // EXIF orientation values (ExifInterface)
    // 1: normal
    // 2: flip horizontal
    // 3: rotate 180
    // 4: flip vertical
    // 5: transpose (flipH + rotate270)
    // 6: rotate 90
    // 7: transverse (flipH + rotate90)
    // 8: rotate 270
    switch (orientation) {
        case 2:
            flipRgbaHorizontal(rgba, w, h);
            break;
        case 3:
            flipRgbaHorizontal(rgba, w, h);
            flipRgbaVertical(rgba, w, h);
            break;
        case 4:
            flipRgbaVertical(rgba, w, h);
            break;
        case 5:
            flipRgbaHorizontal(rgba, w, h);
            rotateRgba270CW(rgba, w, h);
            break;
        case 6:
            rotateRgba90CW(rgba, w, h);
            break;
        case 7:
            flipRgbaHorizontal(rgba, w, h);
            rotateRgba90CW(rgba, w, h);
            break;
        case 8:
            rotateRgba270CW(rgba, w, h);
            break;
        default:
            break;
    }
}

GLuint compileShaderObject(GLenum type, const std::string& src, std::string* outError) {
    const char* csrc = src.c_str();
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &csrc, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char logBuf[2048];
        GLsizei len = 0;
        glGetShaderInfoLog(s, sizeof(logBuf), &len, logBuf);
        LOGE("Shader compile failed: %s", logBuf);
        if (outError) {
            *outError = std::string("Shader compile failed: ") + std::string(logBuf);
        }
        glDeleteShader(s);
        return 0;
    }
    return s;
}

static GLuint compileBasic(GLenum type, const char* src) {
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

static GLuint linkBasic(GLuint vs, GLuint fs) {
    GLuint p = glCreateProgram();
    glAttachShader(p, vs);
    glAttachShader(p, fs);
    glLinkProgram(p);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

static bool ensureTexturedQuadProgram(
    GLuint& program,
    GLint& posLoc,
    GLint& uvLoc,
    GLint& texLoc,
    GLint& alphaLoc,
    GLint& sizeLoc,
    GLint& radiusLoc,
    GLint& uvRectLoc,
    GLuint& vbo
) {
    if (program != 0 && vbo != 0) {
        return true;
    }

    static const char* kVS =
        "#version 300 es\n"
        "in vec2 aPos;\n"
        "in vec2 aUV;\n"
        "out vec2 vUV;\n"
        "void main(){\n"
        "  vUV = aUV;\n"
        "  gl_Position = vec4(aPos, 0.0, 1.0);\n"
        "}\n";

    static const char* kFS =
        "#version 300 es\n"
        "precision highp float;\n"
        "in vec2 vUV;\n"
        "out vec4 fragColor;\n"
        "uniform sampler2D uTex;\n"
        "uniform float uAlpha;\n"
        "uniform vec2 uSizePx;\n"
        "uniform float uRadiusPx;\n"
        "uniform vec4 uUvRect;\n"
        "uniform vec2 uFitScale;\n"
        "uniform vec2 uFitOffset;\n"
        "float sdRoundRect(vec2 p, vec2 b, float r){\n"
        "  vec2 q = abs(p) - b + vec2(r);\n"
        "  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;\n"
        "}\n"
        "void main(){\n"
        "  vec2 uvIn = (vUV - uFitOffset) / max(uFitScale, vec2(1e-6));\n"
        "  float inside = step(0.0, uvIn.x) * step(0.0, uvIn.y) * step(uvIn.x, 1.0) * step(uvIn.y, 1.0);\n"
        "  vec2 uv = mix(uUvRect.xy, uUvRect.zw, uvIn);\n"
        "  vec4 c = texture(uTex, uv) * inside;\n"
        "  float a = uAlpha * inside;\n"
        "  float r = clamp(uRadiusPx, 0.0, 0.5 * min(uSizePx.x, uSizePx.y));\n"
        "  if (r > 0.0001) {\n"
        "    vec2 p = (vUV * uSizePx) - (0.5 * uSizePx);\n"
        "    vec2 b = 0.5 * uSizePx;\n"
        "    float d = sdRoundRect(p, b, r);\n"
        "    float aa = 1.0; // anti-alias width (px)\n"
        "float mask = 1.0 - smoothstep(0.0, aa, d);\n"
        "    a *= mask;\n"
        "  }\n"
        "  c.rgb *= a;\n"
        "  c.a *= a;\n"
        "  fragColor = c;\n"
        "}\n";

    GLuint vs = compileBasic(GL_VERTEX_SHADER, kVS);
    GLuint fs = compileBasic(GL_FRAGMENT_SHADER, kFS);
    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return false;
    }

    GLuint p = linkBasic(vs, fs);
    glDeleteShader(vs);
    glDeleteShader(fs);
    if (!p) {
        return false;
    }

    program = p;
    posLoc = glGetAttribLocation(program, "aPos");
    uvLoc = glGetAttribLocation(program, "aUV");
    texLoc = glGetUniformLocation(program, "uTex");
    alphaLoc = glGetUniformLocation(program, "uAlpha");
    sizeLoc = glGetUniformLocation(program, "uSizePx");
    radiusLoc = glGetUniformLocation(program, "uRadiusPx");
    uvRectLoc = glGetUniformLocation(program, "uUvRect");

    glGenBuffers(1, &vbo);
    if (!vbo) {
        glDeleteProgram(program);
        program = 0;
        return false;
    }
    return true;
}

static void pushTexturedQuad(
    GLuint program,
    GLint posLoc,
    GLint uvLoc,
    GLint texLoc,
    GLint alphaLoc,
    GLint sizeLoc,
    GLint radiusLoc,
    GLint uvRectLoc,
    GLuint vbo,
    int32_t dstW,
    int32_t dstH,
    GLuint texId,
    float cxN,
    float cyN,
    float quadWpx,
    float quadHpx,
    float rotationDeg,
    float alpha,
    float radiusPx
) {
    if (!program || !vbo || !texId) return;
    if (dstW <= 0 || dstH <= 0) return;
    if (quadWpx <= 0.0f || quadHpx <= 0.0f) return;

    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;

    // IMPORTANT: rotation must be performed in pixel space to avoid aspect-ratio distortion
    // when dstW != dstH. Doing rotation in NDC causes a "sheared / 2.5D" look.
    const float cxPx = cxN * static_cast<float>(dstW);
    const float cyPx = cyN * static_cast<float>(dstH);
    const float hxPx = 0.5f * quadWpx;
    const float hyPx = 0.5f * quadHpx;

    const float rad = rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rotPx = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float xPx) -> float {
        return (xPx / static_cast<float>(dstW)) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float yPx) -> float {
        // Convert from top-left pixel origin to OpenGL NDC
        return 1.0f - (yPx / static_cast<float>(dstH)) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rotPx(-hxPx, -hyPx, x0p, y0p);
    rotPx( hxPx, -hyPx, x1p, y1p);
    rotPx(-hxPx,  hyPx, x2p, y2p);
    rotPx( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    const float verts[] = {
        x0, y0, 0.0f, 0.0f,
        x1, y1, 1.0f, 0.0f,
        x2, y2, 0.0f, 1.0f,
        x3, y3, 1.0f, 1.0f,
    };

    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texId);
    if (texLoc >= 0) glUniform1i(texLoc, 0);
    if (alphaLoc >= 0) glUniform1f(alphaLoc, alpha);
    if (sizeLoc >= 0) glUniform2f(sizeLoc, quadWpx, quadHpx);
    if (radiusLoc >= 0) glUniform1f(radiusLoc, radiusPx);
    if (uvRectLoc >= 0) glUniform4f(uvRectLoc, 0.0f, 0.0f, 1.0f, 1.0f);
    {
        const GLint fitScaleLoc = glGetUniformLocation(program, "uFitScale");
        if (fitScaleLoc >= 0) glUniform2f(fitScaleLoc, 1.0f, 1.0f);
        const GLint fitOffLoc = glGetUniformLocation(program, "uFitOffset");
        if (fitOffLoc >= 0) glUniform2f(fitOffLoc, 0.0f, 0.0f);
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(posLoc));
        glVertexAttribPointer(static_cast<GLuint>(posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(posLoc));
    if (uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

static bool ensureOesQuadProgram(
    GLuint& program,
    GLint& posLoc,
    GLint& uvLoc,
    GLint& texLoc,
    GLint& alphaLoc,
    GLint& sizeLoc,
    GLint& radiusLoc,
    GLint& uvRectLoc,
    GLuint& vbo
) {
    if (program != 0 && vbo != 0) {
        return true;
    }

    static const char* kVS =
        "#version 300 es\n"
        "in vec2 aPos;\n"
        "in vec2 aUV;\n"
        "out vec2 vUV;\n"
        "void main(){\n"
        "  vUV = aUV;\n"
        "  gl_Position = vec4(aPos, 0.0, 1.0);\n"
        "}\n";

    static const char* kFS =
        "#version 300 es\n"
        "#extension GL_OES_EGL_image_external_essl3 : require\n"
        "precision highp float;\n"
        "in vec2 vUV;\n"
        "out vec4 fragColor;\n"
        "uniform samplerExternalOES uTex;\n"
        "uniform float uAlpha;\n"
        "uniform vec2 uSizePx;\n"
        "uniform float uRadiusPx;\n"
        "uniform vec4 uUvRect;\n"
        "uniform vec2 uFitScale;\n"
        "uniform vec2 uFitOffset;\n"
        "float sdRoundRect(vec2 p, vec2 b, float r){\n"
        "  vec2 q = abs(p) - b + vec2(r);\n"
        "  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;\n"
        "}\n"
        "void main(){\n"
        "  vec2 uvIn = vUV;\n"
        "  float inside = step(0.0, uvIn.x) * step(0.0, uvIn.y) * step(uvIn.x, 1.0) * step(uvIn.y, 1.0);\n"
        "  vec2 uv = mix(uUvRect.xy, uUvRect.zw, uvIn);\n"
        "  vec4 c = texture(uTex, uv) * inside;\n"
        "  float a = uAlpha * inside;\n"
        "  float r = clamp(uRadiusPx, 0.0, 0.5 * min(uSizePx.x, uSizePx.y));\n"
        "  if (r > 0.0001) {\n"
        "    vec2 p = (vUV * uSizePx) - (0.5 * uSizePx);\n"
        "    vec2 q = abs(p) - (0.5 * uSizePx) + vec2(r);\n"
        "    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;\n"
        "    float mask = 1.0 - smoothstep(0.0, 1.0, d);\n"
        "    a *= mask;\n"
        "  }\n"
        "  c.rgb *= a;\n"
        "  c.a *= a;\n"
        "  fragColor = c;\n"
        "}\n";

    GLuint vs = compileBasic(GL_VERTEX_SHADER, kVS);
    GLuint fs = compileBasic(GL_FRAGMENT_SHADER, kFS);
    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return false;
    }

    GLuint p = linkBasic(vs, fs);
    glDeleteShader(vs);
    glDeleteShader(fs);
    if (!p) {
        return false;
    }

    program = p;
    posLoc = glGetAttribLocation(program, "aPos");
    uvLoc = glGetAttribLocation(program, "aUV");
    texLoc = glGetUniformLocation(program, "uTex");
    alphaLoc = glGetUniformLocation(program, "uAlpha");
    sizeLoc = glGetUniformLocation(program, "uSizePx");
    radiusLoc = glGetUniformLocation(program, "uRadiusPx");
    uvRectLoc = glGetUniformLocation(program, "uUvRect");

    glGenBuffers(1, &vbo);
    if (!vbo) {
        glDeleteProgram(program);
        program = 0;
        return false;
    }
    return true;
}

static void pushOesQuad(
    GLuint program,
    GLint posLoc,
    GLint uvLoc,
    GLint texLoc,
    GLint alphaLoc,
    GLint sizeLoc,
    GLint radiusLoc,
    GLuint vbo,
    int32_t dstW,
    int32_t dstH,
    GLuint oesTex,
    float cxN,
    float cyN,
    float quadWpx,
    float quadHpx,
    float rotationDeg,
    float alpha,
    float radiusPx
) {
    if (!program || !vbo || !oesTex) return;
    if (dstW <= 0 || dstH <= 0) return;
    if (quadWpx <= 0.0f || quadHpx <= 0.0f) return;

    if (alpha < 0.0f) alpha = 0.0f;
    if (alpha > 1.0f) alpha = 1.0f;

    // IMPORTANT: rotate in pixel space (not NDC) to avoid aspect-ratio distortion.
    const float cxPx = cxN * static_cast<float>(dstW);
    const float cyPx = cyN * static_cast<float>(dstH);
    const float hxPx = 0.5f * quadWpx;
    const float hyPx = 0.5f * quadHpx;

    const float rad = rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rot = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float xPx) -> float {
        return (xPx / static_cast<float>(dstW)) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float yPx) -> float {
        return 1.0f - (yPx / static_cast<float>(dstH)) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rot(-hxPx, -hyPx, x0p, y0p);
    rot( hxPx, -hyPx, x1p, y1p);
    rot(-hxPx,  hyPx, x2p, y2p);
    rot( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    // OES renderer path uses inverted V (see gl_external_oes_renderer.cpp)
    const float u0 = 0.0f, u1 = 1.0f;
    const float vTop = 1.0f, vBottom = 0.0f;
    const float verts[] = {
        x0, y0, u0, vBottom,
        x1, y1, u1, vBottom,
        x2, y2, u0, vTop,
        x3, y3, u1, vTop,
    };

    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, oesTex);
    if (texLoc >= 0) glUniform1i(texLoc, 0);
    if (alphaLoc >= 0) glUniform1f(alphaLoc, alpha);
    if (sizeLoc >= 0) glUniform2f(sizeLoc, quadWpx, quadHpx);
    if (radiusLoc >= 0) glUniform1f(radiusLoc, radiusPx);
    {
        const GLint uvRectLoc = glGetUniformLocation(program, "uUvRect");
        if (uvRectLoc >= 0) glUniform4f(uvRectLoc, 0.0f, 0.0f, 1.0f, 1.0f);
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(posLoc));
        glVertexAttribPointer(static_cast<GLuint>(posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(posLoc));
    if (uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_EXTERNAL_OES, 0);
}

GLuint linkProgram(GLuint vs, GLuint fs, std::string* outError) {
    GLuint p = glCreateProgram();
    glAttachShader(p, vs);
    glAttachShader(p, fs);
    glLinkProgram(p);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char logBuf[2048];
        GLsizei len = 0;
        glGetProgramInfoLog(p, sizeof(logBuf), &len, logBuf);
        LOGE("Program link failed: %s", logBuf);
        if (outError) {
            *outError = std::string("Program link failed: ") + std::string(logBuf);
        }
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

static bool parseTextParams(const std::string& dataJson, vidviz::android::gles::ParsedTextParams& out) {
    out = vidviz::android::gles::ParsedTextParams{};
    if (dataJson.empty()) return false;
    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;
    const minijson::Value* textV = minijson::get(*root, "text");
    const auto* textO = textV ? textV->asObject() : nullptr;
    if (!textO) return false;

    minijson::getString(*textO, "title", &out.title);
    minijson::getString(*textO, "font", &out.font);
    minijson::getString(*textO, "effectType", &out.effectType);
    minijson::getString(*textO, "animType", &out.animType);

    double d = 0.0;
    if (minijson::getDouble(*textO, "fontSize", &d)) out.fontSizeN = static_cast<float>(d);
    if (minijson::getDouble(*textO, "alpha", &d)) out.alpha = static_cast<float>(d);
    if (minijson::getDouble(*textO, "x", &d)) out.x = static_cast<float>(d);
    if (minijson::getDouble(*textO, "y", &d)) out.y = static_cast<float>(d);

    if (minijson::getDouble(*textO, "borderw", &d)) out.borderW = static_cast<float>(d);
    if (minijson::getDouble(*textO, "shadowx", &d)) out.shadowX = static_cast<float>(d);
    if (minijson::getDouble(*textO, "shadowy", &d)) out.shadowY = static_cast<float>(d);
    if (minijson::getDouble(*textO, "shadowBlur", &d)) out.shadowBlur = static_cast<float>(d);
    if (minijson::getDouble(*textO, "padPx", &d)) out.padPx = static_cast<float>(d);
    if (minijson::getDouble(*textO, "boxborderw", &d)) out.boxBorderW = static_cast<float>(d);
    if (minijson::getDouble(*textO, "boxPad", &d)) out.boxPad = static_cast<float>(d);
    if (minijson::getDouble(*textO, "boxRadius", &d)) out.boxRadius = static_cast<float>(d);
    if (minijson::getDouble(*textO, "glowRadius", &d)) out.glowRadius = static_cast<float>(d);

    bool bDecor = false;
    if (minijson::getBool(*textO, "decorAlreadyScaled", &bDecor)) out.decorAlreadyScaled = bDecor;

    if (minijson::getDouble(*textO, "effectIntensity", &d)) out.effectIntensity = static_cast<float>(d);
    if (minijson::getDouble(*textO, "effectSpeed", &d)) out.effectSpeed = static_cast<float>(d);
    if (minijson::getDouble(*textO, "effectThickness", &d)) out.effectThickness = static_cast<float>(d);
    if (minijson::getDouble(*textO, "effectAngle", &d)) out.effectAngle = static_cast<float>(d);

    if (minijson::getDouble(*textO, "animSpeed", &d)) out.animSpeed = static_cast<float>(d);
    if (minijson::getDouble(*textO, "animAmplitude", &d)) out.animAmplitude = static_cast<float>(d);
    if (minijson::getDouble(*textO, "animPhase", &d)) out.animPhase = static_cast<float>(d);

    bool bb = false;
    if (minijson::getBool(*textO, "box", &bb)) out.box = bb;

    int64_t i64 = 0;
    if (minijson::getInt64(*textO, "fontColor", &i64)) out.fontColor = i64;
    if (minijson::getInt64(*textO, "bordercolor", &i64)) out.borderColor = i64;
    if (minijson::getInt64(*textO, "shadowcolor", &i64)) out.shadowColor = i64;
    if (minijson::getInt64(*textO, "boxcolor", &i64)) out.boxColor = i64;
    if (minijson::getInt64(*textO, "glowColor", &i64)) out.glowColor = i64;
    if (minijson::getInt64(*textO, "effectColorA", &i64)) out.effectColorA = i64;
    if (minijson::getInt64(*textO, "effectColorB", &i64)) out.effectColorB = i64;
    return !out.title.empty();
}

static GLuint createTextureFromRgba(const uint8_t* rgba, int32_t w, int32_t h) {
    if (!rgba || w <= 0 || h <= 0) return 0;
    GLuint tid = 0;
    glGenTextures(1, &tid);
    if (!tid) return 0;
    glBindTexture(GL_TEXTURE_2D, tid);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    glBindTexture(GL_TEXTURE_2D, 0);
    return tid;
}

static bool parseShaderTypeAndParams(
    const std::string& dataJson,
    std::string& outShaderType,
    float& outIntensity,
    float& outSpeed,
    float& outAngle,
    float& outFrequency,
    float& outAmplitude,
    float& outSize,
    float& outDensity,
    float& outBlurRadius,
    float& outVignetteSize,
    int64_t& outColor
) {
    outShaderType.clear();
    outIntensity = 0.5f;
    outSpeed = 1.0f;
    outAngle = 0.0f;
    outFrequency = 1.0f;
    outAmplitude = 0.5f;
    outSize = 1.0f;
    outDensity = 0.5f;
    outBlurRadius = 5.0f;
    outVignetteSize = 0.5f;
    outColor = 0xFFFFFFFF;

    if (dataJson.empty()) return false;
    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;
    const minijson::Value* shaderV = minijson::get(*root, "shader");
    const auto* shaderO = shaderV ? shaderV->asObject() : nullptr;
    if (!shaderO) return false;

    minijson::getString(*shaderO, "type", &outShaderType);

    double d = 0.0;
    if (minijson::getDouble(*shaderO, "intensity", &d)) outIntensity = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "speed", &d)) outSpeed = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "angle", &d)) outAngle = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "frequency", &d)) outFrequency = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "amplitude", &d)) outAmplitude = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "size", &d)) outSize = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "density", &d)) outDensity = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "blurRadius", &d)) outBlurRadius = static_cast<float>(d);
    if (minijson::getDouble(*shaderO, "vignetteSize", &d)) outVignetteSize = static_cast<float>(d);

    int64_t i64 = 0;
    if (minijson::getInt64(*shaderO, "color", &i64)) outColor = i64;
    return !outShaderType.empty();
}

static void argbToRgb01(int64_t argb, float& r, float& g, float& b) {
    const uint32_t c = static_cast<uint32_t>(argb);
    r = static_cast<float>((c >> 16) & 0xFF) / 255.0f;
    g = static_cast<float>((c >> 8) & 0xFF) / 255.0f;
    b = static_cast<float>((c >> 0) & 0xFF) / 255.0f;
}

} // namespace

GlesSurfaceRenderer::GlesSurfaceRenderer() {
}

GlesSurfaceRenderer::~GlesSurfaceRenderer() {
    shutdown();
}

bool GlesSurfaceRenderer::initialize() {
    return true;
}

void GlesSurfaceRenderer::shutdown() {
    if (ensureEgl()) {
        if (m_lastHwBuffer) {
            AHardwareBuffer_release(m_lastHwBuffer);
            m_lastHwBuffer = nullptr;
        }
        m_oes.shutdown(m_display);

        if (m_overlayLastHwBuffer) {
            AHardwareBuffer_release(m_overlayLastHwBuffer);
            m_overlayLastHwBuffer = nullptr;
        }
        m_overlayOes.shutdown(m_display);
        m_overlayOesTex = 0;

        m_sceneFbo.destroy();
        m_pingFbo.destroy();
        if (m_rgbaTex) {
            glDeleteTextures(1, &m_rgbaTex);
            m_rgbaTex = 0;
        }

        if (m_texQuadVbo) {
            glDeleteBuffers(1, &m_texQuadVbo);
            m_texQuadVbo = 0;
        }
        if (m_texQuadProgram) {
            glDeleteProgram(m_texQuadProgram);
            m_texQuadProgram = 0;
        }
        m_texQuadPosLoc = -1;
        m_texQuadUvLoc = -1;
        m_texQuadTexLoc = -1;
        m_texQuadAlphaLoc = -1;
        m_texQuadSizeLoc = -1;
        m_texQuadRadiusLoc = -1;
        m_texQuadUvRectLoc = -1;

        if (m_oesQuadVbo) {
            glDeleteBuffers(1, &m_oesQuadVbo);
            m_oesQuadVbo = 0;
        }
        if (m_oesQuadProgram) {
            glDeleteProgram(m_oesQuadProgram);
            m_oesQuadProgram = 0;
        }
        m_oesQuadPosLoc = -1;
        m_oesQuadUvLoc = -1;
        m_oesQuadTexLoc = -1;
        m_oesQuadAlphaLoc = -1;
        m_oesQuadSizeLoc = -1;
        m_oesQuadRadiusLoc = -1;
        m_oesQuadUvRectLoc = -1;

        m_quad.shutdown();

        if (m_shaderPassVbo) {
            glDeleteBuffers(1, &m_shaderPassVbo);
            m_shaderPassVbo = 0;
        }

        for (auto& kv : m_loadedTextures) {
            GLuint tid = kv.second;
            if (tid) {
                glDeleteTextures(1, &tid);
            }
        }
        m_loadedTextures.clear();
        m_loadedTextureInfo.clear();

        for (auto& kv : m_textTextures) {
            if (kv.second.texId) {
                glDeleteTextures(1, &kv.second.texId);
            }
        }
        m_textTextures.clear();

        for (auto& kv : m_textEffectPrograms) {
            if (kv.second.vbo) {
                glDeleteBuffers(1, &kv.second.vbo);
                kv.second.vbo = 0;
            }
            if (kv.second.program) {
                glDeleteProgram(kv.second.program);
                kv.second.program = 0;
            }
        }
        m_textEffectPrograms.clear();
        m_shaderSources.clear();
        for (auto& kv : m_shaderPrograms) {
            if (kv.second.program) {
                glDeleteProgram(kv.second.program);
                kv.second.program = 0;
            }
        }
        m_shaderPrograms.clear();
    }
    m_currentFbo = nullptr;
    m_altFbo = nullptr;
    m_videoDecoderGpu.close();
    m_videoDecoder.close();
    m_currentVideoPath.clear();

    m_overlayVideoDecoderGpu.close();
    m_currentOverlayVideoPath.clear();
    if (m_overlayLastHwBuffer) {
        AHardwareBuffer_release(m_overlayLastHwBuffer);
        m_overlayLastHwBuffer = nullptr;
    }
    m_videoDecodePath.clear();
    m_videoDecodeError.clear();
    m_rgbaBuffer.clear();
    m_srcW = 0;
    m_srcH = 0;
    m_hasFrame = false;
    m_hasOesFrame = false;
    m_oesTex = 0;
    cleanupEgl();
}

void GlesSurfaceRenderer::setOutputSize(int32_t width, int32_t height) {
    m_width = width;
    m_height = height;
}

void GlesSurfaceRenderer::setVideoSettings(const VideoSettings& settings) {
    // Crop mode mapping (string from Flutter)
    if (settings.cropMode == "fill") {
        m_cropMode = 1;
    } else if (settings.cropMode == "stretch") {
        m_cropMode = 2;
    } else {
        m_cropMode = 0;
    }

    m_rotation = settings.rotation;
    m_flipHorizontal = settings.flipHorizontal;
    m_flipVertical = settings.flipVertical;

    const uint32_t c = static_cast<uint32_t>(settings.backgroundColor);
    m_bgR = static_cast<float>((c >> 16) & 0xFF) / 255.0f;
    m_bgG = static_cast<float>((c >> 8) & 0xFF) / 255.0f;
    m_bgB = static_cast<float>((c >> 0) & 0xFF) / 255.0f;

    m_uiPlayerWidth = settings.uiPlayerWidth;
    m_uiPlayerHeight = settings.uiPlayerHeight;
    m_uiDevicePixelRatio = settings.uiDevicePixelRatio;
}

void GlesSurfaceRenderer::beginFrame() {
    m_hasFrame = false;
    m_hasOesFrame = false;

    if (!ensureEgl()) return;

    // Always start from a known framebuffer binding.
    GlFramebuffer::unbind();

    // RenderGraph: draw the whole scene into an offscreen FBO.
    // Shader passes will ping-pong between FBOs.
    if (!m_sceneFbo.ensure(m_width, m_height)) {
        return;
    }
    (void)m_pingFbo.ensure(m_width, m_height);

    m_currentFbo = &m_sceneFbo;
    m_altFbo = &m_pingFbo;
    m_currentFbo->bind();

    glViewport(0, 0, m_width, m_height);
    glClearColor(m_bgR, m_bgG, m_bgB, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

// GPUTexture GlesSurfaceRenderer::endFrame() {
//    GPUTexture t;
//    t.width = m_width;
//    t.height = m_height;
//    return t;
//}

GPUTexture GlesSurfaceRenderer::endFrame() {
    GPUTexture t;
    t.width = m_width;
    t.height = m_height;
    // DÜZELTME: Aktif FBO'nun texture ID'sini ekliyoruz
    t.handle = (void*)(uintptr_t)(m_currentFbo ? m_currentFbo->texture() : 0);
    return t;
}

void GlesSurfaceRenderer::clear(float r, float g, float b, float a) {
    (void)r; (void)g; (void)b; (void)a;
}

void GlesSurfaceRenderer::renderMedia(const Asset& asset, TimeMs localTime) {
    if (!ensureEgl()) return;
    if (asset.srcPath.empty()) return;
    if (!m_currentFbo) return;

    // Ensure our 2D quad program exists for image/overlay drawing.
    if (!ensureTexturedQuadProgram(
            m_texQuadProgram,
            m_texQuadPosLoc,
            m_texQuadUvLoc,
            m_texQuadTexLoc,
            m_texQuadAlphaLoc,
            m_texQuadSizeLoc,
            m_texQuadRadiusLoc,
            m_texQuadUvRectLoc,
            m_texQuadVbo)) {
        return;
    }

    if (!ensureOesQuadProgram(
            m_oesQuadProgram,
            m_oesQuadPosLoc,
            m_oesQuadUvLoc,
            m_oesQuadTexLoc,
            m_oesQuadAlphaLoc,
            m_oesQuadSizeLoc,
            m_oesQuadRadiusLoc,
            m_oesQuadUvRectLoc,
            m_oesQuadVbo)) {
        return;
    }

    // IMAGE path (including media overlays stored as AssetType::Image)
    if (asset.type == AssetType::Image) {
        vidviz::android::gles::MediaOverlayParams overlay;
        (void)vidviz::android::gles::parseMediaOverlayParams(asset.dataJson, overlay);

        // For media overlay images, draw as quad at x/y with base size.
        // Flutter preview uses baseSize = clamp(minSide * 0.25, 100..400) and Transform.scale.
        // In export (native), we map base size in pixels based on output resolution.
        if (overlay.isOverlay) {
            // Apply overlay animations in native (parity with Flutter MediaOverlayPlayer)
            float animAlphaMul = 1.0f;
            float animDxN = 0.0f;
            float animDyN = 0.0f;
            float animScaleMul = 1.0f;

            const int64_t localMs = std::max<int64_t>(0, localTime);
            const int32_t animDurMs = std::max<int32_t>(1, overlay.animationDurationMs);
            const float tIn = std::min(1.0f, std::max(0.0f, static_cast<float>(localMs) / static_cast<float>(animDurMs)));
            const bool wantsAnim = (!overlay.animationType.empty() && overlay.animationType != "none" && overlay.animationDurationMs > 0);
            const bool wantsSlide = wantsAnim && (overlay.animationType.rfind("slide_", 0) == 0);

            if (wantsAnim) {
                if (overlay.animationType == "fade_in") {
                    animAlphaMul = tIn;
                } else if (overlay.animationType == "fade_out") {
                    // Flutter: fade-out is applied over the last animationDuration before overlay end.
                    const int64_t durMs = static_cast<int64_t>(asset.duration);
                    if (durMs > 0) {
                        const int64_t startFade = std::max<int64_t>(0, durMs - static_cast<int64_t>(animDurMs));
                        const float tOut = std::min(1.0f, std::max(0.0f, static_cast<float>(localMs - startFade) / static_cast<float>(animDurMs)));
                        animAlphaMul = 1.0f - tOut;
                    } else {
                        animAlphaMul = 1.0f - tIn;
                    }
                } else if (overlay.animationType == "zoom_in") {
                    animScaleMul = tIn;
                } else if (overlay.animationType == "zoom_out") {
                    // Flutter: begin=2.0, end=1.0
                    animScaleMul = 2.0f - tIn;
                }

                if (animAlphaMul < 0.0f) animAlphaMul = 0.0f;
                if (animAlphaMul > 1.0f) animAlphaMul = 1.0f;
                if (animScaleMul < 0.0f) animScaleMul = 0.0f;
            }

            // Media overlay VIDEO: decode via second GPU decoder and draw OES quad with transform+opacity.
            if (overlay.mediaType == "video") {
                // program is ensured above

                // Ensure overlay OES importer is ready
                if (!m_overlayOes.initialize()) {
                    return;
                }

                // Ensure decoder open for this path
                if (m_currentOverlayVideoPath != asset.srcPath) {
                    m_overlayVideoDecoderGpu.close();
                    m_currentOverlayVideoPath.clear();
                }
                if (m_currentOverlayVideoPath.empty()) {
                    if (!m_overlayVideoDecoderGpu.open(asset.srcPath)) {
                        m_overlayVideoDecoderGpu.close();
                        return;
                    }
                    m_currentOverlayVideoPath = asset.srcPath;
                }

                const int64_t timeUs = std::max<int64_t>(0, localTime) * 1000;

                AHardwareBuffer* hb = nullptr;
                int32_t w = 0;
                int32_t h = 0;
                if (!m_overlayVideoDecoderGpu.decodeHardwareBufferAtUs(timeUs, &hb, w, h)) {
                    return;
                }

                int32_t cl = 0, ct = 0, cr = w - 1, cb = h - 1;
                m_overlayVideoDecoderGpu.getCropRect(cl, ct, cr, cb);
                cl = std::max(0, std::min(w - 1, cl));
                cr = std::max(0, std::min(w - 1, cr));
                ct = std::max(0, std::min(h - 1, ct));
                cb = std::max(0, std::min(h - 1, cb));

                const float visW = static_cast<float>(std::max(1, (cr - cl + 1)));
                const float visH = static_cast<float>(std::max(1, (cb - ct + 1)));
                const float baseU0 = static_cast<float>(cl) / static_cast<float>(w);
                const float baseV0 = static_cast<float>(ct) / static_cast<float>(h);
                const float baseU1 = static_cast<float>(cr + 1) / static_cast<float>(w);
                const float baseV1 = static_cast<float>(cb + 1) / static_cast<float>(h);

                if (hb) {
                    const GLuint newTex = m_overlayOes.bindHardwareBuffer(hb, m_display);
                    if (!newTex) {
                        AHardwareBuffer_release(hb);
                        hb = nullptr;
                    } else {
                        if (m_overlayLastHwBuffer) {
                            AHardwareBuffer_release(m_overlayLastHwBuffer);
                            m_overlayLastHwBuffer = nullptr;
                        }
                        m_overlayLastHwBuffer = hb;
                        m_overlayOesTex = newTex;
                    }
                } else {
                    if (!m_overlayLastHwBuffer || !m_overlayOesTex) {
                        return;
                    }
                }

                float basePx = 0.0f;
                float quadPx = 0.0f;
                float radiusPx = 0.0f;
                vidviz::android::gles::computeMediaOverlayQuad(
                    m_width,
                    m_height,
                    1.0f,
                    overlay.borderRadius,
                    basePx,
                    quadPx,
                    radiusPx
                );

                float frameWpx = basePx;
                float frameHpx = basePx;
                if (overlay.frameMode == "fullscreen") {
                    frameWpx = static_cast<float>(m_width);
                    frameHpx = static_cast<float>(m_height);
                } else if (overlay.frameMode == "portrait") {
                    frameWpx = basePx * (9.0f / 16.0f);
                    frameHpx = basePx;
                } else if (overlay.frameMode == "landscape") {
                    frameWpx = basePx;
                    frameHpx = basePx * (9.0f / 16.0f);
                }

                float s = overlay.scale * animScaleMul;
                if (!std::isfinite(s)) s = 1.0f;
                if (s < 0.01f) s = 0.01f;
                frameWpx *= s;
                frameHpx *= s;

                float drawWpx = frameWpx;
                float drawHpx = frameHpx;
                float fitU0 = 0.0f, fitV0 = 0.0f, fitU1 = 1.0f, fitV1 = 1.0f;
                if (overlay.fitMode == "contain") {
                    if (w > 0 && h > 0) {
                        const float srcAspect = visW / visH;
                        const float dstAspect = (frameHpx > 0.0f) ? (frameWpx / frameHpx) : 1.0f;
                        if (srcAspect > dstAspect) {
                            drawWpx = frameWpx;
                            drawHpx = (srcAspect > 0.0f) ? (frameWpx / srcAspect) : frameHpx;
                        } else {
                            drawHpx = frameHpx;
                            drawWpx = frameHpx * srcAspect;
                        }
                    }
                } else if (overlay.fitMode == "cover") {
                    if (w > 0 && h > 0) {
                        const float srcAspect = visW / visH;
                        const float dstAspect = (frameHpx > 0.0f) ? (frameWpx / frameHpx) : 1.0f;
                        if (srcAspect > dstAspect) {
                            const float fracW = (srcAspect > 0.0f) ? (dstAspect / srcAspect) : 1.0f;
                            fitU0 = 0.5f - 0.5f * fracW;
                            fitU1 = 0.5f + 0.5f * fracW;
                            fitV0 = 0.0f;
                            fitV1 = 1.0f;
                        } else {
                            const float fracH = (dstAspect > 0.0f) ? (srcAspect / dstAspect) : 1.0f;
                            fitV0 = 0.5f - 0.5f * fracH;
                            fitV1 = 0.5f + 0.5f * fracH;
                            fitU0 = 0.0f;
                            fitU1 = 1.0f;
                        }
                    }
                } else {
                    // stretch
                    drawWpx = frameWpx;
                    drawHpx = frameHpx;
                }

                float radiusPxDraw = 0.0f;
                {
                    float brRatio = overlay.borderRadius / 100.0f;
                    if (brRatio < 0.0f) brRatio = 0.0f;
                    if (brRatio > 1.0f) brRatio = 1.0f;
                    // Flutter parity: border radius is applied to the overlay frame (ClipRRect),
                    // not to the fitted media content. So radius must depend on frame size.
                    const float maxRadius = 0.5f * std::min(frameWpx, frameHpx);
                    radiusPxDraw = brRatio * maxRadius;
                }

                // SlideTransition parity: offset is in "widget sizes".
                if (wantsSlide) {
                    if (overlay.animationType == "slide_left" || overlay.animationType == "slide_right") {
                        const float distPx = (1.0f - tIn) * frameWpx;
                        const float dxN = distPx / static_cast<float>(m_width);
                        if (overlay.animationType == "slide_left") animDxN = dxN;
                        else animDxN = -dxN;
                    } else if (overlay.animationType == "slide_up" || overlay.animationType == "slide_down") {
                        const float distPx = (1.0f - tIn) * frameHpx;
                        const float dyN = distPx / static_cast<float>(m_height);
                        if (overlay.animationType == "slide_up") animDyN = dyN;
                        else animDyN = -dyN;
                    }
                }

                float cropU0 = 0.0f;
                float cropV0 = 0.0f;
                float cropU1 = 1.0f;
                float cropV1 = 1.0f;
                if (overlay.cropMode == "custom") {
                    float z = overlay.cropZoom;
                    if (!std::isfinite(z)) z = 1.0f;
                    if (z < 1.0f) z = 1.0f;
                    if (z > 4.0f) z = 4.0f;
                    const float win = 1.0f / z;
                    const float maxOff = (1.0f - win) * 0.5f;
                    float px = overlay.cropPanX;
                    float py = overlay.cropPanY;
                    if (!std::isfinite(px)) px = 0.0f;
                    if (!std::isfinite(py)) py = 0.0f;
                    if (px < -1.0f) px = -1.0f;
                    if (px > 1.0f) px = 1.0f;
                    if (py < -1.0f) py = -1.0f;
                    if (py > 1.0f) py = 1.0f;
                    const float cx = 0.5f + px * maxOff;
                    const float cy = 0.5f + py * maxOff;
                    cropU0 = cx - win * 0.5f;
                    cropV0 = cy - win * 0.5f;
                    cropU1 = cx + win * 0.5f;
                    cropV1 = cy + win * 0.5f;
                }

                const float fu0 = fitU0 + cropU0 * (fitU1 - fitU0);
                const float fv0 = fitV0 + cropV0 * (fitV1 - fitV0);
                const float fu1 = fitU0 + cropU1 * (fitU1 - fitU0);
                const float fv1 = fitV0 + cropV1 * (fitV1 - fitV0);

                const float u0 = baseU0 + fu0 * (baseU1 - baseU0);
                const float v0 = baseV0 + fv0 * (baseV1 - baseV0);
                const float u1 = baseU0 + fu1 * (baseU1 - baseU0);
                const float v1 = baseV0 + fv1 * (baseV1 - baseV0);

                const float fitScaleX = (frameWpx > 0.0f) ? (drawWpx / frameWpx) : 1.0f;
                const float fitScaleY = (frameHpx > 0.0f) ? (drawHpx / frameHpx) : 1.0f;
                const float fitOffX = 0.5f * (1.0f - fitScaleX);
                const float fitOffY = 0.5f * (1.0f - fitScaleY);

                pushOesQuadUVRect(
                    m_oesQuadProgram,
                    m_oesQuadPosLoc,
                    m_oesQuadUvLoc,
                    m_oesQuadTexLoc,
                    m_oesQuadAlphaLoc,
                    m_oesQuadSizeLoc,
                    m_oesQuadRadiusLoc,
                    m_oesQuadUvRectLoc,
                    m_oesQuadVbo,
                    m_width,
                    m_height,
                    m_overlayOesTex,
                    overlay.x + animDxN,
                    overlay.y + animDyN,
                    frameWpx,
                    frameHpx,
                    overlay.rotation,
                    overlay.opacity * animAlphaMul,
                    radiusPxDraw,
                    fitScaleX,
                    fitScaleY,
                    fitOffX,
                    fitOffY,
                    u0,
                    v0,
                    u1,
                    v1
                );
                return;
            }

            float basePx = 0.0f;
            float quadPx = 0.0f;
            float radiusPx = 0.0f;
            vidviz::android::gles::computeMediaOverlayQuad(
                m_width,
                m_height,
                1.0f,
                overlay.borderRadius,
                basePx,
                quadPx,
                radiusPx
            );

            float frameWpx = basePx;
            float frameHpx = basePx;
            if (overlay.frameMode == "fullscreen") {
                frameWpx = static_cast<float>(m_width);
                frameHpx = static_cast<float>(m_height);
            } else if (overlay.frameMode == "portrait") {
                frameWpx = basePx * (9.0f / 16.0f);
                frameHpx = basePx;
            } else if (overlay.frameMode == "landscape") {
                frameWpx = basePx;
                frameHpx = basePx * (9.0f / 16.0f);
            }

            float s = overlay.scale * animScaleMul;
            if (!std::isfinite(s)) s = 1.0f;
            if (s < 0.01f) s = 0.01f;
            frameWpx *= s;
            frameHpx *= s;

            if (wantsSlide) {
                if (overlay.animationType == "slide_left" || overlay.animationType == "slide_right") {
                    const float distPx = (1.0f - tIn) * frameWpx;
                    const float dxN = distPx / static_cast<float>(m_width);
                    if (overlay.animationType == "slide_left") animDxN = dxN;
                    else animDxN = -dxN;
                } else if (overlay.animationType == "slide_up" || overlay.animationType == "slide_down") {
                    const float distPx = (1.0f - tIn) * frameHpx;
                    const float dyN = distPx / static_cast<float>(m_height);
                    if (overlay.animationType == "slide_up") animDyN = dyN;
                    else animDyN = -dyN;
                }
            }
            GPUTexture t = loadTexture(asset.srcPath);
            if (!t.handle) return;

            const GLuint tid = static_cast<GLuint>(reinterpret_cast<uintptr_t>(t.handle));

            float drawWpx = frameWpx;
            float drawHpx = frameHpx;
            float fitU0 = 0.0f, fitV0 = 0.0f, fitU1 = 1.0f, fitV1 = 1.0f;
            if (overlay.fitMode == "contain") {
                if (t.width > 0 && t.height > 0) {
                    const float srcAspect = static_cast<float>(t.width) / static_cast<float>(t.height);
                    const float dstAspect = (frameHpx > 0.0f) ? (frameWpx / frameHpx) : 1.0f;
                    if (srcAspect > dstAspect) {
                        drawWpx = frameWpx;
                        drawHpx = (srcAspect > 0.0f) ? (frameWpx / srcAspect) : frameHpx;
                    } else {
                        drawHpx = frameHpx;
                        drawWpx = frameHpx * srcAspect;
                    }
                }
            } else if (overlay.fitMode == "cover") {
                if (t.width > 0 && t.height > 0) {
                    const float srcAspect = static_cast<float>(t.width) / static_cast<float>(t.height);
                    const float dstAspect = (frameHpx > 0.0f) ? (frameWpx / frameHpx) : 1.0f;
                    if (srcAspect > dstAspect) {
                        const float fracW = (srcAspect > 0.0f) ? (dstAspect / srcAspect) : 1.0f;
                        fitU0 = 0.5f - 0.5f * fracW;
                        fitU1 = 0.5f + 0.5f * fracW;
                        fitV0 = 0.0f;
                        fitV1 = 1.0f;
                    } else {
                        const float fracH = (dstAspect > 0.0f) ? (srcAspect / dstAspect) : 1.0f;
                        fitV0 = 0.5f - 0.5f * fracH;
                        fitV1 = 0.5f + 0.5f * fracH;
                        fitU0 = 0.0f;
                        fitU1 = 1.0f;
                    }
                }
            } else {
                // stretch
                drawWpx = frameWpx;
                drawHpx = frameHpx;
            }

            float cropU0 = 0.0f;
            float cropV0 = 0.0f;
            float cropU1 = 1.0f;
            float cropV1 = 1.0f;
            if (overlay.cropMode == "custom") {
                float z = overlay.cropZoom;
                if (!std::isfinite(z)) z = 1.0f;
                if (z < 1.0f) z = 1.0f;
                if (z > 4.0f) z = 4.0f;
                const float win = 1.0f / z;
                const float maxOff = (1.0f - win) * 0.5f;
                float px = overlay.cropPanX;
                float py = overlay.cropPanY;
                if (!std::isfinite(px)) px = 0.0f;
                if (!std::isfinite(py)) py = 0.0f;
                if (px < -1.0f) px = -1.0f;
                if (px > 1.0f) px = 1.0f;
                if (py < -1.0f) py = -1.0f;
                if (py > 1.0f) py = 1.0f;
                const float cx = 0.5f + px * maxOff;
                const float cy = 0.5f + py * maxOff;
                cropU0 = cx - win * 0.5f;
                cropV0 = cy - win * 0.5f;
                cropU1 = cx + win * 0.5f;
                cropV1 = cy + win * 0.5f;
            }

            const float u0 = fitU0 + cropU0 * (fitU1 - fitU0);
            const float v0 = fitV0 + cropV0 * (fitV1 - fitV0);
            const float u1 = fitU0 + cropU1 * (fitU1 - fitU0);
            const float v1 = fitV0 + cropV1 * (fitV1 - fitV0);

            const float fitScaleX = (frameWpx > 0.0f) ? (drawWpx / frameWpx) : 1.0f;
            const float fitScaleY = (frameHpx > 0.0f) ? (drawHpx / frameHpx) : 1.0f;
            const float fitOffX = 0.5f * (1.0f - fitScaleX);
            const float fitOffY = 0.5f * (1.0f - fitScaleY);

            float radiusPxDraw = 0.0f;
            {
                float brRatio = overlay.borderRadius / 100.0f;
                if (brRatio < 0.0f) brRatio = 0.0f;
                if (brRatio > 1.0f) brRatio = 1.0f;
                const float maxRadius = 0.5f * std::min(frameWpx, frameHpx);
                radiusPxDraw = brRatio * maxRadius;
            }

            pushTexturedQuadXformUVRect(
                m_texQuadProgram,
                m_texQuadPosLoc,
                m_texQuadUvLoc,
                m_texQuadTexLoc,
                m_texQuadAlphaLoc,
                m_texQuadSizeLoc,
                m_texQuadRadiusLoc,
                m_texQuadUvRectLoc,
                m_texQuadVbo,
                m_width,
                m_height,
                tid,
                overlay.x + animDxN,
                overlay.y + animDyN,
                frameWpx,
                frameHpx,
                overlay.rotation,
                overlay.opacity * animAlphaMul,
                radiusPxDraw,
                1.0f,
                1.0f,
                fitScaleX,
                fitScaleY,
                fitOffX,
                fitOffY,
                u0,
                v0,
                u1,
                v1
            );
            return;
        }

        // Base image asset (main raster) - draw full-screen using cropMode logic (fit/fill/stretch).
        GPUTexture t = loadTexture(asset.srcPath);
        if (!t.handle) return;
        const GLuint tid = static_cast<GLuint>(reinterpret_cast<uintptr_t>(t.handle));

        float quadW = static_cast<float>(m_width);
        float quadH = static_cast<float>(m_height);
        if (t.width > 0 && t.height > 0) {
            const float dstAspect = static_cast<float>(m_width) / static_cast<float>(m_height);
            const float srcAspect = static_cast<float>(t.width) / static_cast<float>(t.height);

            if (m_cropMode == 2) {
                // stretch
                quadW = static_cast<float>(m_width);
                quadH = static_cast<float>(m_height);
            } else if (m_cropMode == 1) {
                // fill (cover)
                if (srcAspect > dstAspect) {
                    quadH = static_cast<float>(m_height);
                    quadW = quadH * srcAspect;
                } else {
                    quadW = static_cast<float>(m_width);
                    quadH = quadW / srcAspect;
                }
            } else {
                // fit (contain)
                if (srcAspect > dstAspect) {
                    quadW = static_cast<float>(m_width);
                    quadH = quadW / srcAspect;
                } else {
                    quadH = static_cast<float>(m_height);
                    quadW = quadH * srcAspect;
                }
            }
        }

        pushTexturedQuad(
            m_texQuadProgram,
            m_texQuadPosLoc,
            m_texQuadUvLoc,
            m_texQuadTexLoc,
            m_texQuadAlphaLoc,
            m_texQuadSizeLoc,
            m_texQuadRadiusLoc,
            m_texQuadUvRectLoc,
            m_texQuadVbo,
            m_width,
            m_height,
            tid,
            0.5f,
            0.5f,
            quadW,
            quadH,
            0.0f,
            1.0f,
            0.0f
        );
        return;
    }

    // VIDEO path (current)
    if (asset.type != AssetType::Video) return;

    const int64_t timeUs = std::max<int64_t>(0, localTime) * 1000;

    if (m_currentVideoPath != asset.srcPath) {
        m_videoDecoderGpu.close();
        m_videoDecoder.close();
        m_currentVideoPath.clear();
    }

    if (m_currentVideoPath.empty()) {
        if (m_videoDecoderGpu.open(asset.srcPath)) {
            m_currentVideoPath = asset.srcPath;
            m_videoDecodePath = "gpu";
        } else {
            m_videoDecoderGpu.close();
            m_videoDecoder.close();
            m_videoDecodePath = "gpu";
            m_videoDecodeError = "gpu_open_failed";
            return;
        }
    }

    if (m_videoDecoderGpu.isOpen()) {
        m_videoDecodePath = "gpu";
        AHardwareBuffer* hb = nullptr;
        int32_t w = 0;
        int32_t h = 0;
        
        // v6 Syn Fix: decodeHardwareBufferAtUs TRUE dönerse başarılıdır. 
        // Ancak hb NULL dönerse "yeni frame yok, eskisiyle devam et" demektir.
        if (m_videoDecoderGpu.decodeHardwareBufferAtUs(timeUs, &hb, w, h)) {
            // hb valid -> Yeni frame geldi, texture güncelle
            if (hb) {
                const GLuint newTex = m_oes.bindHardwareBuffer(hb, m_display);
                if (!newTex) {
                    AHardwareBuffer_release(hb);
                    hb = nullptr;
                } else {
                    if (m_lastHwBuffer) {
                        AHardwareBuffer_release(m_lastHwBuffer);
                        m_lastHwBuffer = nullptr;
                    }
                    m_lastHwBuffer = hb;
                    m_srcW = w;
                    m_srcH = h;
                    m_oesTex = newTex;
                }
            } 
            // else: hb null -> "m_lastHwBuffer" ve "m_oesTex" hala geçerli, dokunma.

            m_hasOesFrame = (m_oesTex != 0); // Eski texture varsa onu kullan
            if (m_hasOesFrame) {
                int32_t cl = 0, ct = 0, cr = m_srcW - 1, cb = m_srcH - 1;
                m_videoDecoderGpu.getCropRect(cl, ct, cr, cb);
                cl = std::max(0, std::min(m_srcW - 1, cl));
                cr = std::max(0, std::min(m_srcW - 1, cr));
                ct = std::max(0, std::min(m_srcH - 1, ct));
                cb = std::max(0, std::min(m_srcH - 1, cb));

                const float visW = static_cast<float>(std::max(1, (cr - cl + 1)));
                const float visH = static_cast<float>(std::max(1, (cb - ct + 1)));
                const float dstAspect = static_cast<float>(m_width) / static_cast<float>(m_height);
                const float srcAspect = visW / visH;

                const float baseU0 = static_cast<float>(cl) / static_cast<float>(m_srcW);
                const float baseV0 = static_cast<float>(ct) / static_cast<float>(m_srcH);
                const float baseU1 = static_cast<float>(cr + 1) / static_cast<float>(m_srcW);
                const float baseV1 = static_cast<float>(cb + 1) / static_cast<float>(m_srcH);

                float quadWpx = static_cast<float>(m_width);
                float quadHpx = static_cast<float>(m_height);
                float innerU0 = 0.0f, innerV0 = 0.0f, innerU1 = 1.0f, innerV1 = 1.0f;

                if (m_cropMode == 2) {
                } else if (m_cropMode == 1) {
                    if (srcAspect > dstAspect) {
                        const float keep = dstAspect / srcAspect;
                        const float m = (1.0f - keep) * 0.5f;
                        innerU0 = m;
                        innerU1 = 1.0f - m;
                    } else {
                        const float keep = srcAspect / dstAspect;
                        const float m = (1.0f - keep) * 0.5f;
                        innerV0 = m;
                        innerV1 = 1.0f - m;
                    }
                } else {
                    if (srcAspect > dstAspect) {
                        const float sy = dstAspect / srcAspect;
                        quadHpx = quadHpx * sy;
                    } else {
                        const float sx = srcAspect / dstAspect;
                        quadWpx = quadWpx * sx;
                    }
                }

                const float u0 = baseU0 + innerU0 * (baseU1 - baseU0);
                const float v0 = baseV0 + innerV0 * (baseV1 - baseV0);
                const float u1 = baseU0 + innerU1 * (baseU1 - baseU0);
                const float v1 = baseV0 + innerV1 * (baseV1 - baseV0);

                pushOesQuadUVRect(
                    m_oesQuadProgram,
                    m_oesQuadPosLoc,
                    m_oesQuadUvLoc,
                    m_oesQuadTexLoc,
                    m_oesQuadAlphaLoc,
                    m_oesQuadSizeLoc,
                    m_oesQuadRadiusLoc,
                    m_oesQuadUvRectLoc,
                    m_oesQuadVbo,
                    m_width,
                    m_height,
                    m_oesTex,
                    0.5f,
                    0.5f,
                    quadWpx,
                    quadHpx,
                    0.0f,
                    1.0f,
                    0.0f,
                    1.0f,
                    1.0f,
                    0.0f,
                    0.0f,
                    u0,
                    v0,
                    u1,
                    v1
                );
                return;
            }
            m_videoDecodeError = "oes_bind_failed";
        } else {
            m_videoDecodeError = "gpu_decode_failed";
            LOGE("GPU DECODE FAILED AT %lld US - CHECK ASYNC LATENCY", timeUs);
        }
    }
 
    /** 
     * PERFORMANS KRITIK: 
     * Asagidaki CPU Fallback ve glTexImage2D satirlari bilerek devre disi birakildi. 
     * Gpu decoder hata verdiginde sistemin sessizce (ve cok yavas) CPU yoluna sapmasi engelleniyor.
     * Export suresini 2 dakikadan 2 saniyeye dusurmek icin bu kisim calismamali.
     */
    
    /* CPU Fallback - SADECE REFERANS ICIN KALIYOR
    if (!m_videoDecoder.isOpen()) {
        if (m_videoDecodePath.empty()) m_videoDecodePath = "none";
        if (m_videoDecodeError.empty()) m_videoDecodeError = "cpu_not_open";
        return;
    }
    m_videoDecodePath = "cpu";
    if (!m_videoDecoder.decodeRgbaAtUs(timeUs, m_rgbaBuffer, m_srcW, m_srcH)) {
        m_videoDecodeError = "cpu_decode_failed";
        return;
    }

    // TEHLIKELI: CPU-GPU Pixel Transferi (Zombi Kod)
    if (m_rgbaTex == 0) {
        glGenTextures(1, &m_rgbaTex);
        glBindTexture(GL_TEXTURE_2D, m_rgbaTex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    } else {
        glBindTexture(GL_TEXTURE_2D, m_rgbaTex);
    }
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, m_srcW, m_srcH, 0, GL_RGBA, GL_UNSIGNED_BYTE, m_rgbaBuffer.data());
    glBindTexture(GL_TEXTURE_2D, 0);
    m_hasFrame = true;
    m_quad.draw(m_width, m_height, m_srcW, m_srcH, m_rgbaTex);
    */
}

void GlesSurfaceRenderer::renderText(const Asset& asset, TimeMs localTime) {
    if (!ensureEgl()) return;
    if (!m_currentFbo) return;
    if (m_width <= 0 || m_height <= 0) return;

    static bool s_textParityOnce_Setup = false;
    static bool s_textParityOnce_Baked = false;
    static bool s_textParityOnce_ShaderDecor = false;
    static bool s_textParityOnce_ShaderMask = false;
    static bool s_boxParityOnce_Render = false;

    if (!ensureTexturedQuadProgram(
            m_texQuadProgram,
            m_texQuadPosLoc,
            m_texQuadUvLoc,
            m_texQuadTexLoc,
            m_texQuadAlphaLoc,
            m_texQuadSizeLoc,
            m_texQuadRadiusLoc,
            m_texQuadUvRectLoc,
            m_texQuadVbo)) {
        return;
    }

    vidviz::android::gles::ParsedTextParams p;
    if (!parseTextParams(asset.dataJson, p)) return;
    if (p.title.empty()) return;
    if (p.alpha < 0.0f) p.alpha = 0.0f;
    if (p.alpha > 1.0f) p.alpha = 1.0f;

    const float timeSec = static_cast<float>(localTime) / 1000.0f;

    // Global alpha (matches Flutter TextEffectPainter)
    float gAlpha = p.alpha;
    if (p.animType == "fade_in") {
        float spd = p.animSpeed;
        if (!std::isfinite(spd)) spd = 1.0f;
        if (spd < 0.2f) spd = 0.2f;
        if (spd > 2.0f) spd = 2.0f;
        const float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
        gAlpha = gAlpha * prog;
    } else if (p.animType == "blink") {
        float spd = p.animSpeed;
        if (!std::isfinite(spd)) spd = 1.0f;
        if (spd < 0.2f) spd = 0.2f;
        if (spd > 2.0f) spd = 2.0f;
        float ph = p.animPhase;
        if (!std::isfinite(ph)) ph = 0.0f;
        const float f = 0.5f + 0.5f * std::sin(timeSec * spd * 6.0f + ph);
        gAlpha = gAlpha * f;
    }
    if (gAlpha < 0.0f) gAlpha = 0.0f;
    if (gAlpha > 1.0f) gAlpha = 1.0f;

    const TextAnimTransform xform = computeTextAnimTransform(p, timeSec, 0.0f, 0.0f);

    vidviz::android::gles::ParsedTextParams cacheP = p;
    applyTextDecorAnimQuantized(cacheP, timeSec);

    auto computeTextPadPx = [&](const vidviz::android::gles::ParsedTextParams& q) -> float {
        if (q.padPx >= 0.0f && std::isfinite(q.padPx)) {
            float pad = q.padPx;
            if (pad < 0.0f) pad = 0.0f;
            if (pad > 200.0f) pad = 200.0f;
            return pad;
        }
        float bleed = 0.0f;
        bleed = std::max(bleed, std::max(0.0f, q.glowRadius) * 2.0f);
        bleed = std::max(bleed, std::max(0.0f, q.shadowBlur) * 2.0f + (std::fabs(q.shadowX) + std::fabs(q.shadowY)));
        bleed = std::max(bleed, std::max(0.0f, q.borderW));
        if (q.box) {
            bleed = std::max(bleed, std::max(0.0f, q.boxBorderW) * 0.5f);
        }
        if (!std::isfinite(bleed)) bleed = 0.0f;
        if (bleed < 0.0f) bleed = 0.0f;
        if (bleed > 80.0f) bleed = 80.0f;
        const float pad = std::ceil(bleed) + 6.0f;
        return pad;
    };

    const float padBeforeScalePx = computeTextPadPx(cacheP);
    float padAfterScalePx = padBeforeScalePx;
    float boxPadAfterScalePx = 0.0f;
    float totalPadAfterScalePx = padBeforeScalePx;

    bool hasUiMetrics = false;
    float uiW = 0.0f;
    float uiH = 0.0f;
    float sxUi = 0.0f;
    float syUi = 0.0f;
    float uiDpr = 0.0f;

    auto snapPos = [&](float& xx, float& yy, float qw, float qh) {
        if (std::fabs(xform.rotationDeg) < 0.0001f) {
            const float tlx = xx + 0.5f * qw * (1.0f - xform.scaleX);
            const float tly = yy + 0.5f * qh * (1.0f - xform.scaleY);
            if (hasUiMetrics && uiDpr > 0.5f && sxUi > 0.0f && syUi > 0.0f) {
                // Snap to Flutter physical pixel grid to remove 1px drift between preview and export.
                // Convert output px -> UI logical px -> UI physical px (DPR), snap, then map back.
                const float tlxUi = tlx / sxUi;
                const float tlyUi = tly / syUi;
                const float tlxUiPhys = tlxUi * uiDpr;
                const float tlyUiPhys = tlyUi * uiDpr;
                const float stlxUiPhys = std::round(tlxUiPhys);
                const float stlyUiPhys = std::round(tlyUiPhys);
                const float stlx = (stlxUiPhys / uiDpr) * sxUi;
                const float stly = (stlyUiPhys / uiDpr) * syUi;
                xx = stlx - 0.5f * qw * (1.0f - xform.scaleX);
                yy = stly - 0.5f * qh * (1.0f - xform.scaleY);
            } else if (!hasUiMetrics) {
                const float stlx = std::round(tlx);
                const float stly = std::round(tly);
                xx = stlx - 0.5f * qw * (1.0f - xform.scaleX);
                yy = stly - 0.5f * qh * (1.0f - xform.scaleY);
            }
        }
    };

    auto computeTextBiasXPx = [&](const vidviz::android::gles::ParsedTextParams& q) -> float {
        const bool hasExplicitPadPx = (q.padPx >= 0.0f && std::isfinite(q.padPx));
        if (!hasExplicitPadPx) return 0.0f;

        std::string fontLower;
        fontLower.reserve(q.font.size());
        for (const char c : q.font) {
            fontLower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
        }
        const bool isPacifico = (fontLower.find("pacifico") != std::string::npos);
        const bool isItalic = (fontLower.find("italic") != std::string::npos);
        const bool isSourceSans = (fontLower.find("sourcesans") != std::string::npos);
        const int titleLen = static_cast<int>(q.title.size());

        float bias = 0.0f;
        if (isPacifico) {
            bias -= 4.0f;
        }
        if (isItalic && isSourceSans) {
            bias += 5.0f;
        } else if (titleLen >= 6) {
            bias += 4.0f;
        }
        return bias;
    };

    {
        uiW = (m_uiPlayerWidth > 0.0f) ? m_uiPlayerWidth : 0.0f;
        uiH = (m_uiPlayerHeight > 0.0f) ? m_uiPlayerHeight : 0.0f;
        if (uiW > 0.0f && uiH > 0.0f) {
            hasUiMetrics = true;
            sxUi = static_cast<float>(m_width) / uiW;
            syUi = static_cast<float>(m_height) / uiH;
            uiDpr = (m_uiDevicePixelRatio > 0.0f) ? m_uiDevicePixelRatio : 0.0f;
            const float s = 0.5f * (sxUi + syUi);
            const float sStroke = std::max(sxUi, syUi);

            auto scaleDecor = [&](vidviz::android::gles::ParsedTextParams& q) {
                q.borderW *= s;
                q.glowRadius *= s;
                q.shadowBlur *= s;
                q.boxBorderW *= sStroke;
                q.boxPad *= s;
                q.boxRadius *= s;

                q.shadowX *= sxUi;
                q.shadowY *= syUi;
            };

            if (!p.decorAlreadyScaled) {
                scaleDecor(cacheP);
            } else {
                if (cacheP.animType == "shadow_swing") {
                    cacheP.shadowX *= sxUi;
                    cacheP.shadowY *= syUi;
                }
            }

            padAfterScalePx = computeTextPadPx(cacheP);
            float boxPadRaw = 0.0f;
            if (cacheP.box) {
                boxPadRaw = cacheP.boxPad;
                if (!std::isfinite(boxPadRaw)) boxPadRaw = 0.0f;
                if (boxPadRaw < 0.0f) boxPadRaw = 0.0f;
                if (boxPadRaw > 1024.0f) boxPadRaw = 1024.0f;
            }
            boxPadAfterScalePx = std::ceil(boxPadRaw);
            if (!std::isfinite(boxPadAfterScalePx) || boxPadAfterScalePx < 0.0f) boxPadAfterScalePx = 0.0f;
            totalPadAfterScalePx = padAfterScalePx + boxPadAfterScalePx;

            if (cacheP.box && !s_boxParityOnce_Render) {
                LOGI(
                    "BOX_PARITY render box=1 boxPadRaw=%.3f boxPadCeil=%.3f padAfter=%.3f totalPad=%.3f boxBorderW=%.3f boxRadius=%.3f",
                    boxPadRaw,
                    boxPadAfterScalePx,
                    padAfterScalePx,
                    totalPadAfterScalePx,
                    cacheP.boxBorderW,
                    cacheP.boxRadius
                );
                s_boxParityOnce_Render = true;
            }

            if (!s_textParityOnce_Setup) {
                LOGI(
                    "TEXT_PARITY render setup uiW=%.3f uiH=%.3f outW=%d outH=%d sx=%.6f sy=%.6f dpr=%.3f pxy(%.6f,%.6f) s=%.6f sStroke=%.6f padBefore=%.3f padAfter=%.3f boxPad=%.3f totalPad=%.3f xform(dx=%.3f dy=%.3f sx=%.6f sy=%.6f rot=%.6f) box=%d boxBorderW=%.3f boxRadius=%.3f borderW=%.3f glowRadius=%.3f shadow(x=%.3f y=%.3f blur=%.3f)",
                    uiW,
                    uiH,
                    m_width,
                    m_height,
                    sxUi,
                    syUi,
                    uiDpr,
                    p.x,
                    p.y,
                    s,
                    sStroke,
                    padBeforeScalePx,
                    padAfterScalePx,
                    boxPadAfterScalePx,
                    totalPadAfterScalePx,
                    xform.dxPx,
                    xform.dyPx,
                    xform.scaleX,
                    xform.scaleY,
                    xform.rotationDeg,
                    p.box ? 1 : 0,
                    cacheP.boxBorderW,
                    cacheP.boxRadius,
                    cacheP.borderW,
                    cacheP.glowRadius,
                    cacheP.shadowX,
                    cacheP.shadowY,
                    cacheP.shadowBlur
                );
                s_textParityOnce_Setup = true;
            }
        }
    }

    if (!hasUiMetrics) {
        float boxPadRaw = 0.0f;
        if (cacheP.box) {
            boxPadRaw = cacheP.boxPad;
            if (!std::isfinite(boxPadRaw)) boxPadRaw = 0.0f;
            if (boxPadRaw < 0.0f) boxPadRaw = 0.0f;
            if (boxPadRaw > 1024.0f) boxPadRaw = 1024.0f;
        }
        boxPadAfterScalePx = std::ceil(boxPadRaw);
        if (!std::isfinite(boxPadAfterScalePx) || boxPadAfterScalePx < 0.0f) boxPadAfterScalePx = 0.0f;
        totalPadAfterScalePx = padAfterScalePx + boxPadAfterScalePx;
    }

    int blurInStep = -1;
    if (p.animType == "blur_in") {
        float spd = p.animSpeed;
        if (!std::isfinite(spd)) spd = 1.0f;
        if (spd < 0.2f) spd = 0.2f;
        if (spd > 2.0f) spd = 2.0f;
        const float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
        blurInStep = static_cast<int>(std::round(prog * 30.0f));
        if (blurInStep < 0) blurInStep = 0;
        if (blurInStep > 30) blurInStep = 30;
    }

    float clipU = 1.0f;
    if (p.animType == "typing" || p.animType == "type_delete") {
        float spd = p.animSpeed;
        if (!std::isfinite(spd)) spd = 1.0f;
        if (spd < 0.2f) spd = 0.2f;
        if (spd > 2.0f) spd = 2.0f;
        float t = timeSec * spd;
        float prog = 0.0f;
        if (p.animType == "typing") {
            prog = std::fmod(std::max(0.0f, t), 1.0f);
        } else {
            const float x = std::fmod(std::max(0.0f, t), 2.0f);
            prog = (x < 1.0f) ? x : (2.0f - x);
        }
        if (!std::isfinite(prog)) prog = 0.0f;
        if (prog < 0.0f) prog = 0.0f;
        if (prog > 1.0f) prog = 1.0f;
        clipU = prog;
    }

    const bool hasShaderEffect =
        !p.effectType.empty() &&
        p.effectType != "none" &&
        p.effectType != "inner_glow" &&
        p.effectType != "inner_shadow";

    // If we're in shader mode, we must bake only decorations (no fill) so the shader fill is the only glyph fill.
    const bool bakeDecorOnly = hasShaderEffect;

    float fontPx = p.fontSizeN * static_cast<float>(m_width);
    if (!std::isfinite(fontPx) || fontPx < 1.0f) fontPx = 16.0f;
    const float glMaxTex = static_cast<float>(std::max<int32_t>(1, getCachedGlMaxTextureSize()));
    const float fontPxMax = std::min(2048.0f, glMaxTex);
    if (fontPx > fontPxMax) fontPx = fontPxMax;

    std::string key;
    key.reserve(asset.id.size() + p.title.size() + p.font.size() + 256);
    key += asset.id;
    key += "|";
    key += std::to_string(m_width);
    key += "x";
    key += std::to_string(m_height);
    key += "|";
    key += p.title;
    key += "|";
    key += p.font;
    key += "|";
    key += std::to_string(static_cast<int>(fontPx));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.fontColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.borderW * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.borderColor));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.shadowColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowX * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowY * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowBlur * 1000.0f));
    key += "|";
    key += (p.box ? "1" : "0");
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxBorderW * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.boxColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxPad * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxRadius * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.glowRadius * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.glowColor));
    key += "|";
    key += p.effectType;
    key += "|";
    key += std::to_string(static_cast<int>(p.effectIntensity * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.effectColorA));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.effectColorB));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectSpeed * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectThickness * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectAngle * 1000.0f));
    key += "|";
    key += p.animType;
    key += "|";
    key += std::to_string(static_cast<int>(p.animSpeed * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.animAmplitude * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.animPhase * 1000.0f));
    key += "|";
    key += (bakeDecorOnly ? "decorOnly" : "full");
    key += "|textAlignV2";

    if (!hasShaderEffect && blurInStep >= 0) {
        key += "|blurIn=";
        key += std::to_string(blurInStep);
    }

    auto it = m_textTextures.find(key);
    if (it == m_textTextures.end() || it->second.texId == 0) {
        vidviz::android::gles::ParsedTextParams rp = cacheP;
        // Do NOT bake global alpha into bitmap; apply via quad alpha/uAlpha instead.
        rp.alpha = 1.0f;
        std::vector<uint8_t> rgba;
        int32_t tw = 0;
        int32_t th = 0;
        if (!vidviz::android::gles::rasterizeTextBitmap(rp, fontPx, timeSec, false, bakeDecorOnly, rgba, tw, th)) {
            return;
        }
        GLuint tid = createTextureFromRgba(rgba.data(), tw, th);
        if (!tid) return;
        TextTextureInfo info;
        info.texId = tid;
        info.width = tw;
        info.height = th;
        m_textTextures[key] = info;
        it = m_textTextures.find(key);
    }

    if (it == m_textTextures.end()) return;
    const TextTextureInfo& tex = it->second;
    if (!tex.texId || tex.width <= 0 || tex.height <= 0) return;

    // If no shader effect, or painter-only effects, draw the baked bitmap.
    if (!hasShaderEffect) {
        float xPx = p.x * static_cast<float>(m_width) + xform.dxPx;
        float yPx = p.y * static_cast<float>(m_height) + xform.dyPx;
        // xPx -= totalPadAfterScalePx * xform.scaleX;
        // yPx -= totalPadAfterScalePx * xform.scaleY;

        const bool hasExplicitPadPx = (p.padPx >= 0.0f && std::isfinite(p.padPx));
        if (hasExplicitPadPx) {
            xPx -= padAfterScalePx * xform.scaleX;
            yPx -= padAfterScalePx * xform.scaleY;
        }

        xPx += computeTextBiasXPx(p);

        float quadW = static_cast<float>(tex.width);
        float uMax = 1.0f;
        if (clipU < 0.9999f) {
            uMax = clipU;
            quadW = std::max(1.0f, quadW * uMax);
        }

        const float tlx0 = xPx + 0.5f * quadW * (1.0f - xform.scaleX);
        const float tly0 = yPx + 0.5f * static_cast<float>(tex.height) * (1.0f - xform.scaleY);

        snapPos(xPx, yPx, quadW, static_cast<float>(tex.height));

        const float tlx1 = xPx + 0.5f * quadW * (1.0f - xform.scaleX);
        const float tly1 = yPx + 0.5f * static_cast<float>(tex.height) * (1.0f - xform.scaleY);

        if (!s_textParityOnce_Baked) {
            LOGI(
                "TEXT_PARITY render baked fontPx=%.3f clipU=%.6f quadW=%.3f quadH=%d xPx0=%.3f yPx0=%.3f tl0(%.3f,%.3f) xPx1=%.3f yPx1=%.3f tl1(%.3f,%.3f) padAfter=%.3f boxPad=%.3f totalPad=%.3f",
                fontPx,
                clipU,
                quadW,
                tex.height,
                (p.x * static_cast<float>(m_width) + xform.dxPx) - (hasExplicitPadPx ? (padAfterScalePx * xform.scaleX) : 0.0f) + computeTextBiasXPx(p),
                (p.y * static_cast<float>(m_height) + xform.dyPx) - (hasExplicitPadPx ? (padAfterScalePx * xform.scaleY) : 0.0f),
                tlx0,
                tly0,
                xPx,
                yPx,
                tlx1,
                tly1,
                padAfterScalePx,
                boxPadAfterScalePx,
                totalPadAfterScalePx
            );
            s_textParityOnce_Baked = true;
        }

        const float cxN = (xPx + quadW * 0.5f) / static_cast<float>(m_width);
        const float cyN = (yPx + static_cast<float>(tex.height) * 0.5f) / static_cast<float>(m_height);

        pushTexturedQuadXformUV(
            m_texQuadProgram,
            m_texQuadPosLoc,
            m_texQuadUvLoc,
            m_texQuadTexLoc,
            m_texQuadAlphaLoc,
            m_texQuadSizeLoc,
            m_texQuadRadiusLoc,
            m_texQuadUvRectLoc,
            m_texQuadVbo,
            m_width,
            m_height,
            tex.texId,
            cxN,
            cyN,
            quadW,
            static_cast<float>(tex.height),
            xform.rotationDeg,
            gAlpha,
            0.0f,
            xform.scaleX,
            xform.scaleY,
            uMax,
            1.0f
        );
        return;
    }

    // Shader effect path:
    // 1) draw decorations behind (baked bitmap already includes them except fill)
    // 2) draw glyph mask with effect shader on top
    {
        float xPx = p.x * static_cast<float>(m_width) + xform.dxPx;
        float yPx = p.y * static_cast<float>(m_height) + xform.dyPx;
        // xPx -= totalPadAfterScalePx * xform.scaleX;
        // yPx -= totalPadAfterScalePx * xform.scaleY;

        const bool hasExplicitPadPx = (p.padPx >= 0.0f && std::isfinite(p.padPx));
        if (hasExplicitPadPx) {
            xPx -= padAfterScalePx * xform.scaleX;
            yPx -= padAfterScalePx * xform.scaleY;
        }

        xPx += computeTextBiasXPx(p);

        float quadW = static_cast<float>(tex.width);
        float uMax = 1.0f;
        if (clipU < 0.9999f) {
            uMax = clipU;
            quadW = std::max(1.0f, quadW * uMax);
        }

        const float tlx0 = xPx + 0.5f * quadW * (1.0f - xform.scaleX);
        const float tly0 = yPx + 0.5f * static_cast<float>(tex.height) * (1.0f - xform.scaleY);

        snapPos(xPx, yPx, quadW, static_cast<float>(tex.height));

        const float tlx1 = xPx + 0.5f * quadW * (1.0f - xform.scaleX);
        const float tly1 = yPx + 0.5f * static_cast<float>(tex.height) * (1.0f - xform.scaleY);

        if (!s_textParityOnce_ShaderDecor) {
            LOGI(
                "TEXT_PARITY render shader_decor fontPx=%.3f clipU=%.6f quadW=%.3f quadH=%d xPx0=%.3f yPx0=%.3f tl0(%.3f,%.3f) xPx1=%.3f yPx1=%.3f tl1(%.3f,%.3f) padAfter=%.3f boxPad=%.3f totalPad=%.3f",
                fontPx,
                clipU,
                quadW,
                tex.height,
                (p.x * static_cast<float>(m_width) + xform.dxPx) - (hasExplicitPadPx ? (padAfterScalePx * xform.scaleX) : 0.0f) + computeTextBiasXPx(p),
                (p.y * static_cast<float>(m_height) + xform.dyPx) - (hasExplicitPadPx ? (padAfterScalePx * xform.scaleY) : 0.0f),
                tlx0,
                tly0,
                xPx,
                yPx,
                tlx1,
                tly1,
                padAfterScalePx,
                boxPadAfterScalePx,
                totalPadAfterScalePx
            );
            s_textParityOnce_ShaderDecor = true;
        }

        const float cxN = (xPx + quadW * 0.5f) / static_cast<float>(m_width);
        const float cyN = (yPx + static_cast<float>(tex.height) * 0.5f) / static_cast<float>(m_height);
        pushTexturedQuadXformUV(
            m_texQuadProgram,
            m_texQuadPosLoc,
            m_texQuadUvLoc,
            m_texQuadTexLoc,
            m_texQuadAlphaLoc,
            m_texQuadSizeLoc,
            m_texQuadRadiusLoc,
            m_texQuadUvRectLoc,
            m_texQuadVbo,
            m_width,
            m_height,
            tex.texId,
            cxN,
            cyN,
            quadW,
            static_cast<float>(tex.height),
            xform.rotationDeg,
            gAlpha,
            0.0f,
            xform.scaleX,
            xform.scaleY,
            uMax,
            1.0f
        );
    }

    // Create/find glyph mask texture
    std::string maskKey = key;
    maskKey += "|mask";
    if (blurInStep >= 0) {
        maskKey += "|blurIn=";
        maskKey += std::to_string(blurInStep);
    }
    auto maskIt = m_textTextures.find(maskKey);
    if (maskIt == m_textTextures.end() || maskIt->second.texId == 0) {
        vidviz::android::gles::ParsedTextParams mp = cacheP;
        mp.alpha = 1.0f;
        std::vector<uint8_t> rgba;
        int32_t tw = 0;
        int32_t th = 0;
        if (!vidviz::android::gles::rasterizeTextBitmap(mp, fontPx, timeSec, true, false, rgba, tw, th)) {
            return;
        }
        GLuint tid = createTextureFromRgba(rgba.data(), tw, th);
        if (!tid) return;
        TextTextureInfo info;
        info.texId = tid;
        info.width = tw;
        info.height = th;
        m_textTextures[maskKey] = info;
        maskIt = m_textTextures.find(maskKey);
    }
    if (maskIt == m_textTextures.end()) return;
    const TextTextureInfo& mask = maskIt->second;
    if (!mask.texId || mask.width <= 0 || mask.height <= 0) return;

    // Ensure effect shader program exists
    auto progIt = m_textEffectPrograms.find(p.effectType);
    if (progIt == m_textEffectPrograms.end() || progIt->second.program == 0 || progIt->second.vbo == 0) {
        const auto srcIt = m_shaderSources.find(p.effectType);
        if (srcIt == m_shaderSources.end() || srcIt->second.empty()) {
            return;
        }

        GlTextEffectProgram prog;
        std::string err;
        static const char* kVS =
            "#version 300 es\n"
            "in vec2 aPos;\n"
            "in vec2 aUV;\n"
            "out vec2 vUV;\n"
            "void main(){\n"
            "  vUV=aUV;\n"
            "  gl_Position=vec4(aPos,0.0,1.0);\n"
            "}\n";

        const std::string fsSrc = vidviz::android::gles::toGles3TextEffectFragmentSource(srcIt->second);
        GLuint vs = compileShaderObject(GL_VERTEX_SHADER, std::string(kVS), &err);
        if (!vs) return;
        err.clear();
        GLuint fs = compileShaderObject(GL_FRAGMENT_SHADER, fsSrc, &err);
        if (!fs) {
            glDeleteShader(vs);
            return;
        }
        err.clear();
        GLuint program = linkProgram(vs, fs, &err);
        glDeleteShader(vs);
        glDeleteShader(fs);
        if (!program) {
            return;
        }
        prog.program = program;
        prog.posLoc = glGetAttribLocation(program, "aPos");
        prog.uvLoc = glGetAttribLocation(program, "aUV");
        prog.uMaskLoc = glGetUniformLocation(program, "uMask");
        prog.uAlphaLoc = glGetUniformLocation(program, "uAlpha");
        glGenBuffers(1, &prog.vbo);
        if (!prog.vbo) {
            glDeleteProgram(program);
            return;
        }
        m_textEffectPrograms[p.effectType] = prog;
        progIt = m_textEffectPrograms.find(p.effectType);
    }
    if (progIt == m_textEffectPrograms.end()) return;
    GlTextEffectProgram& ep = progIt->second;
    if (!ep.program || !ep.vbo) return;

    // Uniform parity with Flutter (TextEffectPainter uses runtime effect uniforms).
    glUseProgram(ep.program);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, mask.texId);
    if (ep.uMaskLoc >= 0) glUniform1i(ep.uMaskLoc, 0);
    if (ep.uAlphaLoc >= 0) glUniform1f(ep.uAlphaLoc, gAlpha);

    setUniform("uResolution", static_cast<float>(mask.width), static_cast<float>(mask.height));
    setUniform("uTime", timeSec);

    float intensity = p.effectIntensity;
    if (!std::isfinite(intensity)) intensity = 0.7f;
    if (p.animType == "flicker") {
        float spd2 = p.animSpeed;
        if (!std::isfinite(spd2)) spd2 = 1.0f;
        if (spd2 < 0.2f) spd2 = 0.2f;
        if (spd2 > 2.0f) spd2 = 2.0f;
        float ph2 = p.animPhase;
        if (!std::isfinite(ph2)) ph2 = 0.0f;
        const float f = (0.7f + 0.3f * (0.5f * (1.0f + std::sin(timeSec * spd2 * 10.0f + ph2))));
        intensity = intensity * f;
    }
    if (intensity < 0.0f) intensity = 0.0f;
    if (intensity > 1.0f) intensity = 1.0f;
    setUniform("uIntensity", intensity);

    float eSpeed = p.effectSpeed;
    if (!std::isfinite(eSpeed)) eSpeed = 1.0f;
    if (eSpeed < 0.01f) eSpeed = 0.01f;
    if (eSpeed > 5.0f) eSpeed = 5.0f;
    setUniform("uSpeed", eSpeed);

    float eAngle = p.effectAngle;
    if (!std::isfinite(eAngle)) eAngle = 0.0f;
    if (eAngle < -3600.0f) eAngle = -3600.0f;
    if (eAngle > 3600.0f) eAngle = 3600.0f;
    setUniform("uAngle", eAngle);

    float eThick = p.effectThickness;
    if (!std::isfinite(eThick)) eThick = 1.0f;
    if (eThick < 0.0f) eThick = 0.0f;
    if (eThick > 5.0f) eThick = 5.0f;
    setUniform("uThickness", eThick);

    {
        float r = 1.0f, g = 1.0f, b = 1.0f;
        argbToRgb01(p.effectColorA, r, g, b);
        setUniform("uColorA", r, g, b);
        argbToRgb01(p.effectColorB, r, g, b);
        setUniform("uColorB", r, g, b);
    }

    float xPx = p.x * static_cast<float>(m_width) + xform.dxPx;
    float yPx = p.y * static_cast<float>(m_height) + xform.dyPx;
    // xPx -= totalPadAfterScalePx * xform.scaleX;
    // yPx -= totalPadAfterScalePx * xform.scaleY;

    const bool hasExplicitPadPx = (p.padPx >= 0.0f && std::isfinite(p.padPx));
    if (hasExplicitPadPx) {
        xPx -= padAfterScalePx * xform.scaleX;
        yPx -= padAfterScalePx * xform.scaleY;
    }

    xPx += computeTextBiasXPx(p);

    float quadW = static_cast<float>(mask.width);
    float uMax = 1.0f;
    if (clipU < 0.9999f) {
        uMax = clipU;
        quadW = std::max(1.0f, quadW * uMax);
    }

    const float tlx0 = xPx + 0.5f * quadW * (1.0f - xform.scaleX);
    const float tly0 = yPx + 0.5f * static_cast<float>(mask.height) * (1.0f - xform.scaleY);

    snapPos(xPx, yPx, quadW, static_cast<float>(mask.height));

    const float tlx1 = xPx + 0.5f * quadW * (1.0f - xform.scaleX);
    const float tly1 = yPx + 0.5f * static_cast<float>(mask.height) * (1.0f - xform.scaleY);

    if (!s_textParityOnce_ShaderMask) {
        LOGI(
            "TEXT_PARITY render shader_mask fontPx=%.3f clipU=%.6f quadW=%.3f quadH=%d xPx0=%.3f yPx0=%.3f tl0(%.3f,%.3f) xPx1=%.3f yPx1=%.3f tl1(%.3f,%.3f) padAfter=%.3f boxPad=%.3f totalPad=%.3f",
            fontPx,
            clipU,
            quadW,
            mask.height,
            (p.x * static_cast<float>(m_width) + xform.dxPx) - (hasExplicitPadPx ? (padAfterScalePx * xform.scaleX) : 0.0f) + computeTextBiasXPx(p),
            (p.y * static_cast<float>(m_height) + xform.dyPx) - (hasExplicitPadPx ? (padAfterScalePx * xform.scaleY) : 0.0f),
            tlx0,
            tly0,
            xPx,
            yPx,
            tlx1,
            tly1,
            padAfterScalePx,
            boxPadAfterScalePx,
            totalPadAfterScalePx
        );
        s_textParityOnce_ShaderMask = true;
    }

    const float cxN = (xPx + quadW * 0.5f) / static_cast<float>(m_width);
    const float cyN = (yPx + static_cast<float>(mask.height) * 0.5f) / static_cast<float>(m_height);

    const float cxPx = cxN * static_cast<float>(m_width);
    const float cyPx = cyN * static_cast<float>(m_height);
    const float hxPx = 0.5f * quadW * xform.scaleX;
    const float hyPx = 0.5f * static_cast<float>(mask.height) * xform.scaleY;
    const float rad = xform.rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rotPx = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float x) -> float {
        return (x / static_cast<float>(m_width)) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float y) -> float {
        return 1.0f - (y / static_cast<float>(m_height)) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rotPx(-hxPx, -hyPx, x0p, y0p);
    rotPx( hxPx, -hyPx, x1p, y1p);
    rotPx(-hxPx,  hyPx, x2p, y2p);
    rotPx( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    const float verts[] = {
        x0, y0, 0.0f, 1.0f,
        x1, y1, uMax, 1.0f,
        x2, y2, 0.0f, 0.0f,
        x3, y3, uMax, 0.0f,
    };

    glBindBuffer(GL_ARRAY_BUFFER, ep.vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);
    if (ep.posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(ep.posLoc));
        glVertexAttribPointer(static_cast<GLuint>(ep.posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (ep.uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(ep.uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(ep.uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    if (ep.posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(ep.posLoc));
    if (ep.uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(ep.uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    return;

}

void GlesSurfaceRenderer::renderShader(const Asset& asset, vidviz::ShaderManager* shaderManager, TimeMs localTime) {
    if (!ensureEgl()) return;
    if (!m_currentFbo || !m_altFbo) return;
    if (m_currentFbo->texture() == 0) return;
    if (!shaderManager) return;

    std::string shaderType;
    float intensity = 0.5f;
    float speed = 1.0f;
    float angle = 0.0f;
    float frequency = 1.0f;
    float amplitude = 0.5f;
    float size = 1.0f;
    float density = 0.5f;
    float blurRadius = 5.0f;
    float vignetteSize = 0.5f;
    int64_t color = 0xFFFFFFFF;
    if (!parseShaderTypeAndParams(asset.dataJson, shaderType, intensity, speed, angle, frequency, amplitude, size, density, blurRadius, vignetteSize, color)) {
        return;
    }

    const std::string shaderId = shaderType;
    const auto* shader = shaderManager->getShader(shaderId);
    if (!shader) {
        // Shader not present in job->shaders; can't compile.
        return;
    }

    // Compile once and cache.
    if (m_shaderPrograms.find(shaderId) == m_shaderPrograms.end() || m_shaderPrograms[shaderId].program == 0) {
        if (!compileShader(shaderId, shader->vertexSource, shader->fragmentSource)) {
            return;
        }
    }

    auto it = m_shaderPrograms.find(shaderId);
    if (it == m_shaderPrograms.end() || it->second.program == 0) {
        return;
    }
    GlShaderProgram& prog = it->second;

    if (!m_altFbo->ensure(m_width, m_height)) {
        return;
    }

    if (m_shaderPassVbo == 0) {
        glGenBuffers(1, &m_shaderPassVbo);
        if (m_shaderPassVbo == 0) return;
    }

    // Apply shader pass: current -> alt
    m_altFbo->bind();
    glDisable(GL_BLEND);
    glViewport(0, 0, m_width, m_height);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(prog.program);

    setUniform("vvViewportHeight", static_cast<float>(m_height));

    // Bind common uniforms used by runtime_effect shaders
    const float tSec = static_cast<float>(localTime) / 1000.0f;

    float resW = static_cast<float>(m_width);
    float resH = static_cast<float>(m_height);

    // Shadertoy aliases
    setUniform("iResolution", static_cast<float>(m_width), static_cast<float>(m_height));
    setUniform("iTime", tSec);

    // VidViz / Flutter runtime_effect style
    setUniform("uResolution", static_cast<float>(m_width), static_cast<float>(m_height));
    setUniform("uTime", tSec);
    setUniform("uIntensity", intensity);
    setUniform("uSpeed", speed);
    setUniform("uAngle", angle);
    setUniform("uFrequency", frequency);
    setUniform("uAmplitude", amplitude);
    setUniform("uDensity", density);
    setUniform("uDropSize", size);
    setUniform("uFlakeSize", size);
    setUniform("uBlurRadius", blurRadius);
    setUniform("uVignetteSize", vignetteSize);
    {
        float r = 1.0f, g = 1.0f, b = 1.0f;
        argbToRgb01(color, r, g, b);
        setUniform("uColor", r, g, b);
    }
    setUniform("uAspect", resW / std::max(1.0f, resH));

    // Shadertoy aliases
    setUniform("iResolution", static_cast<float>(m_width), static_cast<float>(m_height));
    setUniform("iTime", tSec);
    const auto parsed = minijson::parse(asset.dataJson);
    const auto* root = parsed.ok() ? parsed.value.asObject() : nullptr;
    const minijson::Value* visV = root ? minijson::get(*root, "visualizer") : nullptr;
    const auto* visO = visV ? visV->asObject() : nullptr;

        // Nation overlays: ringColor (works even without image textures)
        if (visO) {
            int64_t ringColorI64 = 0;
            if (minijson::getInt64(*visO, "ringColor", &ringColorI64)) {
                float rr = 1.0f, rg = 1.0f, rb = 1.0f;
                argbToRgb01(ringColorI64, rr, rg, rb);
                setUniform("uRingColor", rr, rg, rb);
                setUniform("uHasRingColor", 1.0f);
            } else {
                setUniform("uHasRingColor", 0.0f);
            }

            std::string centerPath;
            std::string bgPath;
            minijson::getString(*visO, "centerImagePath", &centerPath);
            minijson::getString(*visO, "backgroundImagePath", &bgPath);

            if (!centerPath.empty()) {
                GPUTexture ct = loadTexture(centerPath);
                if (ct.handle) {
                    setTexture("uCenterImg", ct, 1);
                    setUniform("uHasCenter", 1.0f);
                } else {
                    setUniform("uHasCenter", 0.0f);
                }
            } else {
                setUniform("uHasCenter", 0.0f);
            }

            if (!bgPath.empty()) {
                GPUTexture bt = loadTexture(bgPath);
                if (bt.handle) {
                    setTexture("uBgImg", bt, 2);
                    setUniform("uHasBg", 1.0f);
                } else {
                    setUniform("uHasBg", 0.0f);
                }
            } else {
                setUniform("uHasBg", 0.0f);
            }
        }

    // Bind input texture (sampler uniforms)
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_currentFbo->texture());
    if (prog.uTexLoc >= 0) glUniform1i(prog.uTexLoc, 0);
    if (prog.uTextureLoc >= 0) glUniform1i(prog.uTextureLoc, 0);
    // Shadertoy alias
    setUniform("iChannel0", 0);

    // Fullscreen quad (NO Y-flip; keep internal RenderGraph orientation stable)
    const float verts[] = {
        -1.0f, -1.0f, 0.0f, 0.0f,
         1.0f, -1.0f, 1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f, 1.0f,
         1.0f,  1.0f, 1.0f, 1.0f,
    };

    glBindBuffer(GL_ARRAY_BUFFER, m_shaderPassVbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (prog.posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(prog.posLoc));
        glVertexAttribPointer(static_cast<GLuint>(prog.posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (prog.uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(prog.uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(prog.uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (prog.posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(prog.posLoc));
    if (prog.uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(prog.uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Swap for next layers/passes
    GlFramebuffer* tmp = m_currentFbo;
    m_currentFbo = m_altFbo;
    m_altFbo = tmp;
    m_currentFbo->bind();
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    (void)asset;
}

void GlesSurfaceRenderer::renderVisualizer(const Asset& asset, const std::vector<FFTData>& fftData, TimeMs localTime) {
    if (!ensureEgl()) return;
    if (!m_currentFbo || !m_altFbo) return;
    if (!m_currentFbo->texture()) return;

    vidviz::android::gles::VisualizerParams vp;
    if (!vidviz::android::gles::parseVisualizerParams(asset.dataJson, vp)) {
        return;
    }

    if (vp.renderMode == "counter") {
        if (!ensureTexturedQuadProgram(
                m_texQuadProgram,
                m_texQuadPosLoc,
                m_texQuadUvLoc,
                m_texQuadTexLoc,
                m_texQuadAlphaLoc,
                m_texQuadSizeLoc,
                m_texQuadRadiusLoc,
                m_texQuadUvRectLoc,
                m_texQuadVbo)) {
            return;
        }

        auto two = [](int64_t v) -> std::string {
            if (v < 0) v = 0;
            std::string s = std::to_string(static_cast<long long>(v));
            if (s.size() < 2) s = std::string("0") + s;
            return s;
        };
        auto formatMs = [&](int64_t ms) -> std::string {
            if (ms < 0) ms = 0;
            const int64_t totalSec = ms / 1000;
            const int64_t minutes = totalSec / 60;
            const int64_t seconds = totalSec % 60;
            return two(minutes) + std::string(":") + two(seconds);
        };

        const float timeSec = static_cast<float>(localTime) / 1000.0f;

        int64_t totalMs = vp.projectDurationMs;
        if (totalMs <= 0) totalMs = static_cast<int64_t>(asset.duration);
        if (totalMs <= 0) totalMs = 1;

        int64_t elapsedMs = static_cast<int64_t>(asset.begin) + static_cast<int64_t>(localTime);
        if (elapsedMs < 0) elapsedMs = 0;
        if (elapsedMs > totalMs) elapsedMs = totalMs;

        auto modeLabel = [&](const std::string& mode) -> std::string {
            if (mode == "remaining") return formatMs(totalMs - elapsedMs);
            if (mode == "total") return formatMs(totalMs);
            return formatMs(elapsedMs);
        };

        float r = 1.0f, g = 1.0f, b = 1.0f;
        argbToRgb01(vp.color, r, g, b);
        const float lum = 0.2126f * r + 0.7152f * g + 0.0722f * b;
        const int64_t defaultLabelColor = (lum < 0.5f) ? 0xFF000000 : 0xFFFFFFFF;

        float labelSize = 12.0f;
        if (vp.counterLabelSize == "small") labelSize = 10.0f;
        else if (vp.counterLabelSize == "large") labelSize = 14.0f;
        float fontPx = 0.03f * (labelSize / 12.0f) * static_cast<float>(m_width);
        if (!std::isfinite(fontPx) || fontPx < 8.0f) fontPx = 16.0f;
        {
            const float glMaxTex = static_cast<float>(std::max<int32_t>(1, getCachedGlMaxTextureSize()));
            const float fontPxMax = std::min(2048.0f, glMaxTex);
            if (fontPx > fontPxMax) fontPx = fontPxMax;
        }

        auto drawLabel = [&](
            const std::string& keySuffix,
            const std::string& text,
            float posX01,
            float posY01,
            bool useLegacyTopLeftPx,
            float legacyXpx,
            float legacyYpx,
            int64_t labelColor,
            const std::string& weight,
            float shadowOpacity,
            float shadowBlur,
            float shadowOffsetX,
            float shadowOffsetY,
            float glowRadius,
            float glowOpacity,
            float rotationDeg,
            float scaleX,
            float scaleY,
            float extraOffsetYPx
        ) {
            if (text.empty()) return;

            std::string key;
            key.reserve(asset.id.size() + text.size() + 128);
            key += asset.id;
            key += "|counter|";
            key += keySuffix;
            key += "|";
            key += std::to_string(m_width);
            key += "x";
            key += std::to_string(m_height);
            key += "|";
            key += text;
            key += "|";
            key += std::to_string(static_cast<int>(fontPx));
            key += "|";
            key += std::to_string(static_cast<int64_t>(labelColor));
            key += "|";
            key += weight;
            key += "|";
            key += std::to_string(shadowOpacity);
            key += "|";
            key += std::to_string(shadowBlur);
            key += "|";
            key += std::to_string(shadowOffsetX);
            key += "|";
            key += std::to_string(shadowOffsetY);
            key += "|";
            key += std::to_string(glowRadius);
            key += "|";
            key += std::to_string(glowOpacity);

            auto itT = m_textTextures.find(key);
            if (itT == m_textTextures.end() || itT->second.texId == 0) {
                vidviz::android::gles::ParsedTextParams p;
                p.title = text;
                p.fontSizeN = 0.1f;
                p.fontColor = labelColor;
                p.alpha = 1.0f;

                // Weight parity: semibold/bold => fake bold, normal => off.
                if (weight == "bold") {
                    p.fakeBold = true;
                    p.borderW = 0.9f;
                    p.borderColor = labelColor;
                } else if (weight == "semibold") {
                    // Semibold should NOT look like bold. We keep it as normal weight on native,
                    // since we don't have real font weight variants loaded here.
                    p.fakeBold = false;
                    p.borderW = 0.0f;
                } else {
                    p.fakeBold = false;
                    p.borderW = 0.0f;
                }

                // Shadow: we use black with configurable opacity.
                if (shadowOpacity > 0.0f && (shadowBlur > 0.0f || shadowOffsetX != 0.0f || shadowOffsetY != 0.0f)) {
                    const float op = std::min(1.0f, std::max(0.0f, shadowOpacity));
                    const int a = (int)std::round(op * 255.0f);
                    const int64_t shadowArgb = (static_cast<int64_t>(a) << 24) | 0x000000;
                    p.shadowColor = shadowArgb;
                    p.shadowBlur = shadowBlur;
                    p.shadowX = shadowOffsetX;
                    p.shadowY = shadowOffsetY;
                }

                // Glow: use labelColor with configurable opacity.
                if (glowOpacity > 0.0f && glowRadius > 0.0f) {
                    const float op = std::min(1.0f, std::max(0.0f, glowOpacity));
                    const int a = (int)std::round(op * 255.0f);
                    const int64_t rgb = (labelColor & 0x00FFFFFF);
                    p.glowColor = (static_cast<int64_t>(a) << 24) | rgb;
                    p.glowRadius = glowRadius;
                }

                std::vector<uint8_t> rgba;
                int32_t tw = 0;
                int32_t th = 0;
                float inkDx = 0.0f;
                float inkDy = 0.0f;
                if (!vidviz::android::gles::rasterizeTextBitmap(p, fontPx, timeSec, false, false, rgba, tw, th, &inkDx, &inkDy)) {
                    return;
                }

                // Counter-only: compute ink center from actual rendered pixels (alpha bbox).
                // This makes placement stable even when shadow/blur/fakeBold changes the visible bounds.
                if (tw > 0 && th > 0 && rgba.size() >= static_cast<size_t>(tw) * static_cast<size_t>(th) * 4u) {
                    constexpr uint8_t kAlphaThresh = 8;
                    int minX = tw;
                    int minY = th;
                    int maxX = -1;
                    int maxY = -1;
                    const size_t stride = static_cast<size_t>(tw) * 4u;
                    for (int y = 0; y < th; y++) {
                        const uint8_t* row = rgba.data() + static_cast<size_t>(y) * stride;
                        for (int x = 0; x < tw; x++) {
                            const uint8_t a = row[static_cast<size_t>(x) * 4u + 3u];
                            if (a > kAlphaThresh) {
                                if (x < minX) minX = x;
                                if (y < minY) minY = y;
                                if (x > maxX) maxX = x;
                                if (y > maxY) maxY = y;
                            }
                        }
                    }
                    if (maxX >= minX && maxY >= minY) {
                        const float inkCx = 0.5f * static_cast<float>(minX + maxX + 1);
                        const float inkCy = 0.5f * static_cast<float>(minY + maxY + 1);
                        const float bmpCx = 0.5f * static_cast<float>(tw);
                        const float bmpCy = 0.5f * static_cast<float>(th);
                        float dx = inkCx - bmpCx;
                        float dy = inkCy - bmpCy;
                        if (!std::isfinite(dx)) dx = 0.0f;
                        if (!std::isfinite(dy)) dy = 0.0f;
                        inkDx = dx;
                        inkDy = dy;
                    }
                }

                static int s_counterLogCount = 0;
                if (s_counterLogCount < 10) {
                    LOGI(
                        "COUNTER_PARITY key=%s text=%s fontPx=%.2f color=0x%llX weight=%s shadow(op=%.2f blur=%.2f offX=%.2f offY=%.2f) glow(r=%.2f op=%.2f) tex=%dx%d inkDx=%.2f inkDy=%.2f",
                        keySuffix.c_str(),
                        text.c_str(),
                        fontPx,
                        static_cast<long long>(labelColor),
                        weight.c_str(),
                        shadowOpacity,
                        shadowBlur,
                        shadowOffsetX,
                        shadowOffsetY,
                        glowRadius,
                        glowOpacity,
                        tw,
                        th,
                        inkDx,
                        inkDy
                    );
                    s_counterLogCount++;
                }
                GLuint tid = createTextureFromRgba(rgba.data(), tw, th);
                if (!tid) return;
                TextTextureInfo info;
                info.texId = tid;
                info.width = tw;
                info.height = th;
                info.inkCenterDxPx = inkDx;
                info.inkCenterDyPx = inkDy;
                m_textTextures[key] = info;
                itT = m_textTextures.find(key);
            }
            if (itT == m_textTextures.end()) return;
            const TextTextureInfo& tex = itT->second;
            if (!tex.texId || tex.width <= 0 || tex.height <= 0) return;

            float cxN = posX01;
            float cyN = posY01;
            if (useLegacyTopLeftPx) {
                const float cxPx = legacyXpx + static_cast<float>(tex.width) * 0.5f;
                const float cyPx = legacyYpx + static_cast<float>(tex.height) * 0.5f + extraOffsetYPx;
                cxN = cxPx / std::max(1.0f, static_cast<float>(m_width));
                cyN = cyPx / std::max(1.0f, static_cast<float>(m_height));
            } else {
                cxN = posX01;
                cyN = posY01 + (extraOffsetYPx / std::max(1.0f, static_cast<float>(m_height)));
            }

            // Align quad center to ink center (glyph bounds) instead of bitmap center.
            // rasterizeTextBitmap reports inkCenterDelta = (inkCenter - bitmapCenter).
            // We need the inverse shift so that inkCenter lands at requested (cxN, cyN).
            cxN -= (tex.inkCenterDxPx / std::max(1.0f, static_cast<float>(m_width)));
            cyN -= (tex.inkCenterDyPx / std::max(1.0f, static_cast<float>(m_height)));

            const float counterBiasXPx = 11.0f;
            const float counterBiasYPx = 4.0f;
            cxN += (counterBiasXPx / std::max(1.0f, static_cast<float>(m_width)));
            cyN += (counterBiasYPx / std::max(1.0f, static_cast<float>(m_height)));
            if (!std::isfinite(cxN)) cxN = 0.5f;
            if (!std::isfinite(cyN)) cyN = 0.5f;
            if (cxN < 0.0f) cxN = 0.0f;
            if (cxN > 1.0f) cxN = 1.0f;
            if (cyN < 0.0f) cyN = 0.0f;
            if (cyN > 1.0f) cyN = 1.0f;
            float a = vp.alpha;
            if (a < 0.0f) a = 0.0f;
            if (a > 1.0f) a = 1.0f;

            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            pushTexturedQuadXformUV(
                m_texQuadProgram,
                m_texQuadPosLoc,
                m_texQuadUvLoc,
                m_texQuadTexLoc,
                m_texQuadAlphaLoc,
                m_texQuadSizeLoc,
                m_texQuadRadiusLoc,
                m_texQuadUvRectLoc,
                m_texQuadVbo,
                m_width,
                m_height,
                tex.texId,
                cxN,
                cyN,
                static_cast<float>(tex.width),
                static_cast<float>(tex.height),
                rotationDeg,
                a,
                0.0f,
                scaleX,
                scaleY,
                1.0f,
                1.0f
            );
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        };

        float scale = vp.scale;
        if (scale < 0.05f) scale = 0.05f;
        if (scale > 4.0f) scale = 4.0f;

        float left = -1.0f;
        float right = 1.0f;
        float bottom = -1.0f;
        float top = 1.0f;
        if (!vp.fullScreen) {
            const float tx = (vp.x * 2.0f) - 1.0f;
            const float ty = ((1.0f - vp.y) * 2.0f) - 1.0f;
            const float sxy = scale;
            left = -sxy + tx;
            right = sxy + tx;
            bottom = -sxy + ty;
            top = sxy + ty;
        }

        const float leftPx = (left + 1.0f) * 0.5f * static_cast<float>(m_width);
        const float rightPx = (right + 1.0f) * 0.5f * static_cast<float>(m_width);
        const float topPx = (1.0f - top) * 0.5f * static_cast<float>(m_height);
        const float bottomPx = (1.0f - bottom) * 0.5f * static_cast<float>(m_height);
        const float regionW = std::max(1.0f, rightPx - leftPx);
        const float regionH = std::max(1.0f, bottomPx - topPx);
        const float boxH = std::max(1.0f, regionH * 0.10f);
        const float padPx = 12.0f;

        const float heightPxF = std::max(1.0f, static_cast<float>(m_height));
        float legacyDefaultY = 0.50f;
        if (vp.counterPos == "top") legacyDefaultY = 0.08f;
        else if (vp.counterPos == "bottom") legacyDefaultY = 0.92f;
        const float legacyDy01 = vp.counterOffsetY / heightPxF;
        legacyDefaultY = std::min(1.0f, std::max(0.0f, legacyDefaultY + legacyDy01));

        const bool hasStartPos = (vp.counterStartPosX >= 0.0f && vp.counterStartPosY >= 0.0f);
        const bool hasEndPos = (vp.counterEndPosX >= 0.0f && vp.counterEndPosY >= 0.0f);
        (void)hasStartPos;
        (void)hasEndPos;

        const float startX01 = (vp.counterStartPosX >= 0.0f) ? vp.counterStartPosX : 0.10f;
        const float startY01 = (vp.counterStartPosY >= 0.0f) ? vp.counterStartPosY : legacyDefaultY;
        const float endX01 = (vp.counterEndPosX >= 0.0f) ? vp.counterEndPosX : 0.90f;
        const float endY01 = (vp.counterEndPosY >= 0.0f) ? vp.counterEndPosY : legacyDefaultY;

        const int64_t startColor = vp.hasCounterStartColor ? vp.counterStartColor : defaultLabelColor;
        const int64_t endColor = vp.hasCounterEndColor ? vp.counterEndColor : defaultLabelColor;

        const float animSec = static_cast<float>(elapsedMs) / 1000.0f;
        float animSpeed = vp.speed;
        if (!std::isfinite(animSpeed)) animSpeed = 1.0f;
        if (animSpeed < 0.5f) animSpeed = 0.5f;
        if (animSpeed > 2.0f) animSpeed = 2.0f;

        float rotationDeg = 0.0f;
        float scaleX = 1.0f;
        float scaleY = 1.0f;
        float extraOffsetYPx = 0.0f;
        if (vp.counterAnim == "pulse") {
            const float baseFreq = 1.0f + 0.4f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float s = 1.0f + 0.06f * std::sin(phase);
            scaleX = s;
            scaleY = s;
        } else if (vp.counterAnim == "flip") {
            const float baseFreq = 0.8f + 0.7f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float c = std::cos(phase);
            const float mag = 0.15f + 0.85f * std::fabs(c);
            const float sign = (c >= 0.0f) ? 1.0f : -1.0f;
            scaleX = sign * mag;
            scaleY = 1.0f + 0.03f * std::cos(phase);
        } else if (vp.counterAnim == "leaf") {
            const float baseFreq = 1.0f + 0.6f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float wave = std::sin(phase);
            rotationDeg = (0.18f * wave) * (180.0f / 3.1415926535f);
            extraOffsetYPx = -(std::fabs(wave)) * 10.0f;
            const float s = 1.0f + 0.03f * std::sin(phase + 1.2f);
            scaleX = s;
            scaleY = s;
        } else if (vp.counterAnim == "bounce") {
            const float baseFreq = 1.2f + 0.7f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float wave = (std::sin(phase) + 1.0f) * 0.5f;
            const float eased = wave * wave;
            extraOffsetYPx = -eased * 18.0f;
            scaleX = 1.0f + 0.16f * eased;
            scaleY = 1.0f - 0.10f * eased;
        }

        if (vp.counterStartEnabled) {
            const std::string s = modeLabel(vp.counterStartMode);
            drawLabel(
                "start",
                s,
                startX01,
                startY01,
                false,
                leftPx + padPx,
                topPx + (boxH * 0.5f) - 20.0f + vp.counterOffsetY,
                startColor,
                vp.counterStartWeight,
                vp.counterStartShadowOpacity,
                vp.counterStartShadowBlur,
                vp.counterStartShadowOffsetX,
                vp.counterStartShadowOffsetY,
                vp.counterStartGlowRadius,
                vp.counterStartGlowOpacity,
                rotationDeg,
                scaleX,
                scaleY,
                extraOffsetYPx
            );
        }
        if (vp.counterEndEnabled) {
            const std::string e = modeLabel(vp.counterEndMode);
            drawLabel(
                "end",
                e,
                endX01,
                endY01,
                false,
                (leftPx + regionW) - padPx - 120.0f,
                topPx + (boxH * 0.5f) - 20.0f + vp.counterOffsetY,
                endColor,
                vp.counterEndWeight,
                vp.counterEndShadowOpacity,
                vp.counterEndShadowBlur,
                vp.counterEndShadowOffsetX,
                vp.counterEndShadowOffsetY,
                vp.counterEndGlowRadius,
                vp.counterEndGlowOpacity,
                rotationDeg,
                scaleX,
                scaleY,
                extraOffsetYPx
            );
        }
        return;
    }

    const std::string shaderId = vidviz::android::gles::pickVisualizerShaderId(vp);

    auto it = m_shaderPrograms.find(shaderId);
    if (it == m_shaderPrograms.end() || it->second.program == 0) {
        return;
    }
    GlShaderProgram& prog = it->second;

    const float tSec = static_cast<float>(localTime) / 1000.0f;

    float resW = static_cast<float>(m_width);
    float resH = static_cast<float>(m_height);

    const std::string& fftKey = (!vp.audioPath.empty()) ? vp.audioPath : asset.srcPath;
    const FFTData* fft = vidviz::android::gles::findFftByAudioPath(fftData, fftKey);
    const std::vector<float>* frame = nullptr;
    if (fft && !fft->frames.empty() && fft->hopSize > 0 && fft->sampleRate > 0) {
        const double seconds = static_cast<double>(std::max<int64_t>(0, localTime)) / 1000.0;
        const double frameIndexD = (seconds * static_cast<double>(fft->sampleRate)) / static_cast<double>(fft->hopSize);
        int64_t frameIndex = static_cast<int64_t>(frameIndexD);
        if (frameIndex < 0) frameIndex = 0;
        if (frameIndex >= static_cast<int64_t>(fft->frames.size())) frameIndex = static_cast<int64_t>(fft->frames.size()) - 1;
        if (frameIndex >= 0 && frameIndex < static_cast<int64_t>(fft->frames.size())) {
            frame = &fft->frames[static_cast<size_t>(frameIndex)];
        }
    }

    const std::vector<float>* dynSrc = frame;
    std::vector<float> dynFrame;
    if (dynSrc && !dynSrc->empty()) {
        float smooth = vp.smoothness;
        if (std::fabs(smooth - 0.6f) < 0.001f) smooth = 0.0f;
        if (smooth < 0.0f) smooth = 0.0f;
        if (smooth > 1.0f) smooth = 1.0f;

        float react = vp.reactivity;
        if (react < 0.5f) react = 0.5f;
        if (react > 2.0f) react = 2.0f;

        if (!(smooth == 0.0f && std::fabs(react - 1.0f) < 0.001f)) {
            dynFrame = *dynSrc;
            const int n = static_cast<int>(dynFrame.size());
            std::vector<float> smoothed(static_cast<size_t>(n), 0.0f);
            if (smooth > 0.0f) {
                for (int i = 0; i < n; i++) {
                    float self = dynFrame[static_cast<size_t>(i)];
                    if (!std::isfinite(self)) self = 0.0f;
                    if (self < 0.0f) self = 0.0f;
                    if (self > 1.0f) self = 1.0f;
                    float prev = (i > 0) ? dynFrame[static_cast<size_t>(i - 1)] : self;
                    float next = (i < n - 1) ? dynFrame[static_cast<size_t>(i + 1)] : self;
                    if (!std::isfinite(prev)) prev = 0.0f;
                    if (!std::isfinite(next)) next = 0.0f;
                    if (prev < 0.0f) prev = 0.0f;
                    if (prev > 1.0f) prev = 1.0f;
                    if (next < 0.0f) next = 0.0f;
                    if (next > 1.0f) next = 1.0f;
                    const float avg = (prev + self + next) / 3.0f;
                    smoothed[static_cast<size_t>(i)] = self * (1.0f - smooth) + avg * smooth;
                }
            } else {
                for (int i = 0; i < n; i++) {
                    float v = dynFrame[static_cast<size_t>(i)];
                    if (!std::isfinite(v)) v = 0.0f;
                    if (v < 0.0f) v = 0.0f;
                    if (v > 1.0f) v = 1.0f;
                    smoothed[static_cast<size_t>(i)] = v;
                }
            }

            if (std::fabs(react - 1.0f) < 0.001f) {
                dynFrame.swap(smoothed);
            } else {
                const float exp = 1.0f / react;
                for (int i = 0; i < n; i++) {
                    float v = smoothed[static_cast<size_t>(i)];
                    if (!std::isfinite(v)) v = 0.0f;
                    if (v < 0.0f) v = 0.0f;
                    if (v > 1.0f) v = 1.0f;
                    dynFrame[static_cast<size_t>(i)] = std::pow(v, exp);
                }
            }
            dynSrc = &dynFrame;
        }
    }

    float f8[8];
    vidviz::android::gles::fillFft8(dynSrc, f8);

    // Apply Flutter semantics: sensitivity scales FFT values (NOT uIntensity)
    float sensitivity = vp.sensitivity;
    if (sensitivity < 0.0f) sensitivity = 0.0f;
    if (sensitivity > 2.0f) sensitivity = 2.0f;
    for (int i = 0; i < 8; i++) {
        float v = f8[i] * sensitivity;
        if (v < 0.0f) v = 0.0f;
        if (v > 1.0f) v = 1.0f;
        f8[i] = v;
    }
    if (vp.mirror) {
        // Mirror: second half mirrors the first half
        f8[4] = f8[3];
        f8[5] = f8[2];
        f8[6] = f8[1];
        f8[7] = f8[0];
    }

    if (m_shaderPassVbo == 0) {
        glGenBuffers(1, &m_shaderPassVbo);
        if (m_shaderPassVbo == 0) return;
    }

    glUseProgram(prog.program);
    setUniform("vvViewportHeight", static_cast<float>(m_height));

    // Flutter parity: ShaderEffect/VisualStageEffect operate in logical pixels (dp).
    // If UI player metrics are available, keep shader-space resolution in dp to match preview.
    // (Export geometry still maps to m_width/m_height via NDC; this only affects shader uniforms.)
    const float uiW = (m_uiPlayerWidth > 0.0f) ? m_uiPlayerWidth : 0.0f;
    const float uiH = (m_uiPlayerHeight > 0.0f) ? m_uiPlayerHeight : 0.0f;
    if (uiW > 0.0f && uiH > 0.0f) {
        resW = std::max(1.0f, uiW);
        resH = std::max(1.0f, (vp.renderMode == "progress") ? (uiH * 0.10f) : uiH);
    }

    setUniform("iResolution", resW, resH);
    setUniform("iTime", tSec);
    setUniform("uResolution", resW, resH);
    setUniform("uTime", tSec);

    float speed = vp.speed;
    float scale = vp.scale;
    float rotation = vp.rotation;
    int32_t barCount = vp.barCount;

    // sensitivity already clamped and applied to FFT above
    if (speed < 0.0f) speed = 0.0f;
    if (speed > 3.0f) speed = 3.0f;
    if (scale < 0.05f) scale = 0.05f;
    if (scale > 4.0f) scale = 4.0f;
    if (barCount < 1) barCount = 1;
    if (barCount > 128) barCount = 128;

    // Flutter parity:
    // - visualizers use uIntensity = amplitude
    // - progress uses uIntensity = glowIntensity
    float intensityU = (vp.renderMode == "progress") ? vp.glow : vp.amplitude;
    if (intensityU < 0.0f) intensityU = 0.0f;
    if (intensityU > 3.0f) intensityU = 3.0f;
    setUniform("uIntensity", intensityU);
    setUniform("uSpeed", speed);
    setUniform("uBars", static_cast<float>(barCount));
    setUniform("uAngle", rotation);

    float r = 1.0f, g = 1.0f, b = 1.0f;
    argbToRgb01(vp.color, r, g, b);
    setUniform("uColor", r, g, b);
    if (vp.gradientColor != 0) {
        float r2 = 1.0f, g2 = 1.0f, b2 = 1.0f;
        argbToRgb01(vp.gradientColor, r2, g2, b2);
        setUniform("uColor2", r2, g2, b2);
    } else {
        setUniform("uColor2", r, g, b);
    }

    setUniform("uFreq0", f8[0]);
    setUniform("uFreq1", f8[1]);
    setUniform("uFreq2", f8[2]);
    setUniform("uFreq3", f8[3]);
    setUniform("uFreq4", f8[4]);
    setUniform("uFreq5", f8[5]);
    setUniform("uFreq6", f8[6]);
    setUniform("uFreq7", f8[7]);

    // Optional uniforms for parity
    {
        float bf = vp.barFill;
        if (bf < 0.0f) bf = 0.0f;
        if (bf > 1.0f) bf = 1.0f;
        setUniform("uBarFill", bf);
    }
    {
        float gl = vp.glow;
        if (gl < 0.0f) gl = 0.0f;
        if (gl > 1.0f) gl = 1.0f;
        setUniform("uGlow", gl);
    }
    {
        float st = vp.strokeWidth;
        if (st < 0.0f) st = 0.0f;
        if (st > 24.0f) st = 24.0f;
        setUniform("uStroke", st);
    }

    if (vp.renderMode == "progress") {
        // Flutter parity: progress uses global timeline position / project duration.
        int64_t projectDurationMs = vp.projectDurationMs;
        if (projectDurationMs <= 0) projectDurationMs = static_cast<int64_t>(asset.duration);
        if (projectDurationMs <= 0) projectDurationMs = 1;

        const int64_t globalMs = static_cast<int64_t>(asset.begin) + static_cast<int64_t>(localTime);
        float p = static_cast<float>(globalMs) / static_cast<float>(projectDurationMs);
        if (p < 0.0f) p = 0.0f;
        if (p > 1.0f) p = 1.0f;
        setUniform("uProgress", p);

        float styleIdx = 0.0f;
        if (vp.effectStyle == "segments") styleIdx = 1.0f;
        else if (vp.effectStyle == "steps") styleIdx = 2.0f;
        else if (vp.effectStyle == "centered") styleIdx = 3.0f;
        else if (vp.effectStyle == "outline") styleIdx = 4.0f;
        else if (vp.effectStyle == "thin") styleIdx = 5.0f;
        else styleIdx = 0.0f;
        setUniform("uStyle", styleIdx);

        float th = vp.strokeWidth;
        if (th < 6.0f) th = 6.0f;
        if (th > 24.0f) th = 24.0f;
        // Flutter parity: scale thickness to bar height so max stroke fills the progress bar.
        float thicknessPx = (resH > 0.0f) ? ((th / 24.0f) * resH) : th;
        if (!std::isfinite(thicknessPx) || thicknessPx <= 0.0f) thicknessPx = th;
        setUniform("uThickness", thicknessPx);

        setUniform("uTrackAlpha", vp.progressTrackAlpha);
        setUniform("uCorner", vp.progressCorner);
        setUniform("uGap", vp.progressGap);
        setUniform("uTheme", vp.progressThemeIdx);
        setUniform("uEffectAmount", vp.progressEffectAmount);
        setUniform("uHeadAmount", vp.progressHeadAmount);
        setUniform("uHeadSize", vp.progressHeadSize);
        setUniform("uHeadStyle", vp.progressHeadStyleIdx);

        if (vp.hasProgressTrackColor) {
            float tr = 0.0f, tg = 0.0f, tb = 0.0f;
            argbToRgb01(vp.progressTrackColor, tr, tg, tb);
            setUniform("uTrackColor", tr, tg, tb);
        } else {
            setUniform("uTrackColor", 0.0f, 0.0f, 0.0f);
        }
    }

    setUniform("uAspect", resW / std::max(1.0f, resH));

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_currentFbo->texture());
    if (prog.uTexLoc >= 0) glUniform1i(prog.uTexLoc, 0);
    if (prog.uTextureLoc >= 0) glUniform1i(prog.uTextureLoc, 0);
    setUniform("iChannel0", 0);

    if (shaderId == "pro_nation") {
        const auto parsed = minijson::parse(asset.dataJson);
        const auto* root = parsed.ok() ? parsed.value.asObject() : nullptr;
        const minijson::Value* visV = root ? minijson::get(*root, "visualizer") : nullptr;
        const auto* visO = visV ? visV->asObject() : nullptr;
        if (visO) {
            int64_t ringColorI64 = 0;
            if (minijson::getInt64(*visO, "ringColor", &ringColorI64)) {
                float rr = 1.0f, rg = 1.0f, rb = 1.0f;
                argbToRgb01(ringColorI64, rr, rg, rb);
                setUniform("uRingColor", rr, rg, rb);
                setUniform("uHasRingColor", 1.0f);
            } else {
                setUniform("uHasRingColor", 0.0f);
            }

            std::string centerPath;
            std::string bgPath;
            minijson::getString(*visO, "centerImagePath", &centerPath);
            minijson::getString(*visO, "backgroundImagePath", &bgPath);

            if (!centerPath.empty()) {
                GPUTexture ct = loadTexture(centerPath);
                if (ct.handle) {
                    setTexture("uCenterImg", ct, 1);
                    setUniform("uHasCenter", 1.0f);
                } else {
                    setUniform("uHasCenter", 0.0f);
                }
            } else {
                setUniform("uHasCenter", 0.0f);
            }

            if (!bgPath.empty()) {
                GPUTexture bt = loadTexture(bgPath);
                if (bt.handle) {
                    setTexture("uBgImg", bt, 2);
                    setUniform("uHasBg", 1.0f);
                } else {
                    setUniform("uHasBg", 0.0f);
                }
            } else {
                setUniform("uHasBg", 0.0f);
            }
        }
    }

    glActiveTexture(GL_TEXTURE0);

    if (vp.renderMode == "visual") {
        if (!m_altFbo->ensure(m_width, m_height)) {
            glBindTexture(GL_TEXTURE_2D, 0);
            return;
        }

        m_altFbo->bind();
        glDisable(GL_BLEND);
        glViewport(0, 0, m_width, m_height);
        // Preserve background by copying current scene into the visual pass target.
        m_quad.draw(
            m_width,
            m_height,
            m_currentFbo->width(),
            m_currentFbo->height(),
            m_currentFbo->texture()
        );
        glUseProgram(prog.program);
        // Rebind scene texture after the quad copy (m_quad.draw unbinds GL_TEXTURE_2D).
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, m_currentFbo->texture());
        if (prog.uTexLoc >= 0) glUniform1i(prog.uTexLoc, 0);
        if (prog.uTextureLoc >= 0) glUniform1i(prog.uTextureLoc, 0);
        setUniform("iChannel0", 0);

        float left = -1.0f;
        float right = 1.0f;
        float bottom = -1.0f;
        float top = 1.0f;
        if (!vp.fullScreen) {
            const float tx = (vp.x * 2.0f) - 1.0f;
            const float ty = ((1.0f - vp.y) * 2.0f) - 1.0f;
            const float sxy = scale;
            left = -sxy + tx;
            right = sxy + tx;
            bottom = -sxy + ty;
            top = sxy + ty;
        }

        const float verts[] = {
            left,  bottom, 0.0f, 0.0f,
            right, bottom, 1.0f, 0.0f,
            left,  top,    0.0f, 1.0f,
            right, top,    1.0f, 1.0f,
        };

        glBindBuffer(GL_ARRAY_BUFFER, m_shaderPassVbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);
        if (prog.posLoc >= 0) {
            glEnableVertexAttribArray(static_cast<GLuint>(prog.posLoc));
            glVertexAttribPointer(static_cast<GLuint>(prog.posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
        }
        if (prog.uvLoc >= 0) {
            glEnableVertexAttribArray(static_cast<GLuint>(prog.uvLoc));
            glVertexAttribPointer(static_cast<GLuint>(prog.uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
        }
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        if (prog.posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(prog.posLoc));
        if (prog.uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(prog.uvLoc));
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindTexture(GL_TEXTURE_2D, 0);

        GlFramebuffer* tmp = m_currentFbo;
        m_currentFbo = m_altFbo;
        m_altFbo = tmp;
        m_currentFbo->bind();
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        return;
    }

    m_currentFbo->bind();
    glViewport(0, 0, m_width, m_height);
    glEnable(GL_BLEND);
    if (vp.renderMode == "progress") {
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }

    float left = -1.0f;
    float right = 1.0f;
    float bottom = -1.0f;
    float top = 1.0f;
    if (!vp.fullScreen) {
        const float tx = (vp.x * 2.0f) - 1.0f;
        const float ty = ((1.0f - vp.y) * 2.0f) - 1.0f;
        const float sx = scale;
        const float sy = (vp.renderMode == "progress") ? (scale * 0.10f) : scale;
        left = -sx + tx;
        right = sx + tx;
        bottom = -sy + ty;
        top = sy + ty;
    }

    if (vp.renderMode == "progress") {
        const float pxL = (left * 0.5f + 0.5f) * static_cast<float>(m_width);
        const float pxR = (right * 0.5f + 0.5f) * static_cast<float>(m_width);
        const float pyB = (bottom * 0.5f + 0.5f) * static_cast<float>(m_height);
        const float pyT = (top * 0.5f + 0.5f) * static_cast<float>(m_height);

        float wPx = pxR - pxL;
        float hPx = pyT - pyB;
        float cxPx = (pxL + pxR) * 0.5f;
        float cyPx = (pyB + pyT) * 0.5f;

        // Avoid snapping to integer pixels here; it can shift half-coverage to one edge.
        wPx = std::max(1.0f, wPx);
        hPx = std::max(1.0f, hPx);

        const float pxL2 = cxPx - (wPx * 0.5f);
        const float pxR2 = cxPx + (wPx * 0.5f);
        const float pyB2 = cyPx - (hPx * 0.5f);
        const float pyT2 = cyPx + (hPx * 0.5f);

        left = ((pxL2 / static_cast<float>(m_width)) - 0.5f) * 2.0f;
        right = ((pxR2 / static_cast<float>(m_width)) - 0.5f) * 2.0f;
        bottom = ((pyB2 / static_cast<float>(m_height)) - 0.5f) * 2.0f;
        top = ((pyT2 / static_cast<float>(m_height)) - 0.5f) * 2.0f;
    }

    const float verts[] = {
        left,  bottom, 0.0f, 0.0f,
        right, bottom, 1.0f, 0.0f,
        left,  top,    0.0f, 1.0f,
        right, top,    1.0f, 1.0f,
    };

    glBindBuffer(GL_ARRAY_BUFFER, m_shaderPassVbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STREAM_DRAW);

    if (prog.posLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(prog.posLoc));
        glVertexAttribPointer(static_cast<GLuint>(prog.posLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    }
    if (prog.uvLoc >= 0) {
        glEnableVertexAttribArray(static_cast<GLuint>(prog.uvLoc));
        glVertexAttribPointer(static_cast<GLuint>(prog.uvLoc), 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    }

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (prog.posLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(prog.posLoc));
    if (prog.uvLoc >= 0) glDisableVertexAttribArray(static_cast<GLuint>(prog.uvLoc));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

bool GlesSurfaceRenderer::compileShader(const std::string& shaderId, const std::string& vertexSource, const std::string& fragmentSource) {
    (void)vertexSource;
    if (!ensureEgl()) return false;
    if (shaderId.empty()) return false;
    if (fragmentSource.empty()) return false;

    m_shaderSources[shaderId] = fragmentSource;

    m_lastShaderId = shaderId;
    m_lastShaderCompileError.clear();

    // Destroy old program if re-compiling
    auto& prog = m_shaderPrograms[shaderId];
    if (prog.program) {
        glDeleteProgram(prog.program);
        prog.program = 0;
        prog.uniformLocs.clear();
    }

    static const char* kVS =
        "#version 300 es\n"
        "in vec2 aPos;\n"
        "in vec2 aUV;\n"
        "out vec2 vUV;\n"
        "void main(){\n"
        "  vUV=aUV;\n"
        "  gl_Position=vec4(aPos,0.0,1.0);\n"
        "}\n";

    std::string fsSrc = vidviz::android::gles::toGles3FragmentSource(fragmentSource);

    std::string err;

    GLuint vs = compileShaderObject(GL_VERTEX_SHADER, std::string(kVS), &err);
    if (!vs) {
        m_lastShaderCompileError = err;
        return false;
    }
    err.clear();
    GLuint fs = compileShaderObject(GL_FRAGMENT_SHADER, fsSrc, &err);
    if (!fs) {
        m_lastShaderCompileError = err;
        glDeleteShader(vs);
        return false;
    }

    err.clear();
    GLuint program = linkProgram(vs, fs, &err);
    glDeleteShader(vs);
    glDeleteShader(fs);
    if (!program) {
        m_lastShaderCompileError = err;
        return false;
    }

    prog.program = program;
    prog.posLoc = glGetAttribLocation(program, "aPos");
    prog.uvLoc = glGetAttribLocation(program, "aUV");
    prog.uTexLoc = glGetUniformLocation(program, "uTex");
    prog.uTextureLoc = glGetUniformLocation(program, "uTexture");
    return true;
}

void GlesSurfaceRenderer::bindShader(const std::string& shaderId) {
    if (!ensureEgl()) return;
    auto it = m_shaderPrograms.find(shaderId);
    if (it == m_shaderPrograms.end() || it->second.program == 0) return;
    glUseProgram(it->second.program);
}

void GlesSurfaceRenderer::setUniform(const std::string& name, float value) {
    if (name.empty()) return;
    // Find currently bound program
    GLint cur = 0;
    glGetIntegerv(GL_CURRENT_PROGRAM, &cur);
    if (cur == 0) return;
    const GLint loc = glGetUniformLocation(static_cast<GLuint>(cur), name.c_str());
    if (loc < 0) return;
    glUniform1f(loc, value);
}

void GlesSurfaceRenderer::setUniform(const std::string& name, float x, float y) {
    if (name.empty()) return;
    GLint cur = 0;
    glGetIntegerv(GL_CURRENT_PROGRAM, &cur);
    if (cur == 0) return;
    const GLint loc = glGetUniformLocation(static_cast<GLuint>(cur), name.c_str());
    if (loc < 0) return;
    glUniform2f(loc, x, y);
}

void GlesSurfaceRenderer::setUniform(const std::string& name, float x, float y, float z) {
    if (name.empty()) return;
    GLint cur = 0;
    glGetIntegerv(GL_CURRENT_PROGRAM, &cur);
    if (cur == 0) return;
    const GLint loc = glGetUniformLocation(static_cast<GLuint>(cur), name.c_str());
    if (loc < 0) return;
    glUniform3f(loc, x, y, z);
}

void GlesSurfaceRenderer::setUniform(const std::string& name, float x, float y, float z, float w) {
    if (name.empty()) return;
    GLint cur = 0;
    glGetIntegerv(GL_CURRENT_PROGRAM, &cur);
    if (cur == 0) return;
    const GLint loc = glGetUniformLocation(static_cast<GLuint>(cur), name.c_str());
    if (loc < 0) return;
    glUniform4f(loc, x, y, z, w);
}

void GlesSurfaceRenderer::setUniform(const std::string& name, int value) {
    if (name.empty()) return;
    GLint cur = 0;
    glGetIntegerv(GL_CURRENT_PROGRAM, &cur);
    if (cur == 0) return;
    const GLint loc = glGetUniformLocation(static_cast<GLuint>(cur), name.c_str());
    if (loc < 0) return;
    glUniform1i(loc, value);
}

void GlesSurfaceRenderer::setTexture(const std::string& name, const GPUTexture& texture, int unit) {
    if (name.empty()) return;
    const GLuint texId = static_cast<GLuint>(reinterpret_cast<uintptr_t>(texture.handle));
    if (texId == 0) return;
    if (unit < 0) return;

    GLint cur = 0;
    glGetIntegerv(GL_CURRENT_PROGRAM, &cur);
    if (cur == 0) return;

    glActiveTexture(static_cast<GLenum>(GL_TEXTURE0 + unit));
    glBindTexture(GL_TEXTURE_2D, texId);

    const GLint loc = glGetUniformLocation(static_cast<GLuint>(cur), name.c_str());
    if (loc >= 0) {
        glUniform1i(loc, unit);
    }
}

GPUTexture GlesSurfaceRenderer::loadTexture(const std::string& path) {
    if (!ensureEgl()) return GPUTexture{};
    if (path.empty()) return GPUTexture{};

    std::string normalizedPath = path;
    if (normalizedPath.rfind("file://", 0) == 0) {
        normalizedPath = normalizedPath.substr(7);
    }
    if (normalizedPath.empty()) return GPUTexture{};

    auto it = m_loadedTextureInfo.find(normalizedPath);
    if (it != m_loadedTextureInfo.end()) {
        return it->second;
    }

    if (!g_vidvizJvm) {
        g_vidvizJvm = getJavaVmFallback();
    }
    if (!g_vidvizJvm) {
        LOGE("loadTexture: JavaVM is null");
        return GPUTexture{};
    }

    JNIEnv* env = nullptr;
    bool didAttach = false;
    const jint envRes = g_vidvizJvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (envRes == JNI_EDETACHED) {
        if (g_vidvizJvm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
            LOGE("loadTexture: AttachCurrentThread failed");
            return GPUTexture{};
        }
        didAttach = true;
    } else if (envRes != JNI_OK) {
        LOGE("loadTexture: GetEnv failed: %d", envRes);
        return GPUTexture{};
    }

    std::vector<uint8_t> rgba;
    int32_t w = 0;
    int32_t h = 0;
    int exifOrientation = 1;

    do {
        // Read EXIF orientation for parity with Flutter image decoding.
        // NOTE: On native-attached threads, FindClass reliably works for framework classes,
        // so we try android.media.ExifInterface first and fall back to androidx if present.
        auto tryReadExifOrientation = [&](const char* clsName) {
            jclass exifCls = env->FindClass(clsName);
            if (!exifCls) {
                if (env->ExceptionCheck()) env->ExceptionClear();
                return;
            }
            jmethodID exifCtor = env->GetMethodID(exifCls, "<init>", "(Ljava/lang/String;)V");
            jmethodID getAttrInt = env->GetMethodID(exifCls, "getAttributeInt", "(Ljava/lang/String;I)I");
            if (!exifCtor || !getAttrInt) {
                env->DeleteLocalRef(exifCls);
                if (env->ExceptionCheck()) env->ExceptionClear();
                return;
            }
            jstring exifPath = env->NewStringUTF(normalizedPath.c_str());
            if (!exifPath) {
                env->DeleteLocalRef(exifCls);
                return;
            }
            jobject exifObj = env->NewObject(exifCls, exifCtor, exifPath);
            env->DeleteLocalRef(exifPath);
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
                env->DeleteLocalRef(exifCls);
                return;
            }
            if (exifObj) {
                jstring tag = env->NewStringUTF("Orientation");
                if (tag) {
                    const jint ori = env->CallIntMethod(exifObj, getAttrInt, tag, 1);
                    env->DeleteLocalRef(tag);
                    if (env->ExceptionCheck()) {
                        env->ExceptionClear();
                    } else {
                        exifOrientation = static_cast<int>(ori);
                    }
                }
                env->DeleteLocalRef(exifObj);
            }
            env->DeleteLocalRef(exifCls);
        };

        tryReadExifOrientation("android/media/ExifInterface");
        if (exifOrientation == 1) {
            tryReadExifOrientation("androidx/exifinterface/media/ExifInterface");
        }

        jclass bfCls = env->FindClass("android/graphics/BitmapFactory");
        if (!bfCls) break;
        jclass optCls = env->FindClass("android/graphics/BitmapFactory$Options");
        if (!optCls) break;
        jmethodID optCtor = env->GetMethodID(optCls, "<init>", "()V");
        if (!optCtor) break;
        jobject opts = env->NewObject(optCls, optCtor);
        if (!opts) break;

        jclass cfgCls = env->FindClass("android/graphics/Bitmap$Config");
        if (!cfgCls) {
            env->DeleteLocalRef(opts);
            break;
        }
        jfieldID argbField = env->GetStaticFieldID(cfgCls, "ARGB_8888", "Landroid/graphics/Bitmap$Config;");
        jobject argbObj = argbField ? env->GetStaticObjectField(cfgCls, argbField) : nullptr;
        jfieldID prefField = env->GetFieldID(optCls, "inPreferredConfig", "Landroid/graphics/Bitmap$Config;");
        if (prefField && argbObj) {
            env->SetObjectField(opts, prefField, argbObj);
        }
        if (argbObj) env->DeleteLocalRef(argbObj);
        env->DeleteLocalRef(cfgCls);

        jmethodID decodeMid = env->GetStaticMethodID(
            bfCls,
            "decodeFile",
            "(Ljava/lang/String;Landroid/graphics/BitmapFactory$Options;)Landroid/graphics/Bitmap;"
        );
        if (!decodeMid) {
            env->DeleteLocalRef(opts);
            break;
        }

        jstring jpath = env->NewStringUTF(normalizedPath.c_str());
        if (!jpath) {
            env->DeleteLocalRef(opts);
            break;
        }

        jobject bmp = env->CallStaticObjectMethod(bfCls, decodeMid, jpath, opts);
        env->DeleteLocalRef(jpath);
        env->DeleteLocalRef(opts);
        env->DeleteLocalRef(optCls);
        env->DeleteLocalRef(bfCls);

        if (env->ExceptionCheck()) {
            env->ExceptionClear();
        }

        if (!bmp) break;

        AndroidBitmapInfo info;
        if (AndroidBitmap_getInfo(env, bmp, &info) != ANDROID_BITMAP_RESULT_SUCCESS) {
            env->DeleteLocalRef(bmp);
            break;
        }
        if (info.width <= 0 || info.height <= 0) {
            env->DeleteLocalRef(bmp);
            break;
        }

        void* pixels = nullptr;
        if (AndroidBitmap_lockPixels(env, bmp, &pixels) != ANDROID_BITMAP_RESULT_SUCCESS || !pixels) {
            env->DeleteLocalRef(bmp);
            break;
        }

        w = static_cast<int32_t>(info.width);
        h = static_cast<int32_t>(info.height);
        const size_t stride = static_cast<size_t>(info.stride);
        rgba.resize(static_cast<size_t>(w) * static_cast<size_t>(h) * 4u);

        const uint8_t* src = static_cast<const uint8_t*>(pixels);
        uint8_t* dst = rgba.data();
        for (int32_t y = 0; y < h; y++) {
            const uint8_t* row = src + static_cast<size_t>(y) * stride;
            memcpy(dst + static_cast<size_t>(y) * static_cast<size_t>(w) * 4u, row, static_cast<size_t>(w) * 4u);
        }

        if (exifOrientation != 1) {
            applyExifOrientationRgba(rgba, w, h, exifOrientation);
        }

        AndroidBitmap_unlockPixels(env, bmp);
        env->DeleteLocalRef(bmp);
    } while (false);

    if (didAttach) {
        g_vidvizJvm->DetachCurrentThread();
    }

    if (rgba.empty() || w <= 0 || h <= 0) {
        LOGE("loadTexture failed: %s", normalizedPath.c_str());
        return GPUTexture{};
    }

    GLuint tid = 0;
    glGenTextures(1, &tid);
    if (tid == 0) {
        return GPUTexture{};
    }
    glBindTexture(GL_TEXTURE_2D, tid);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba.data());
    glBindTexture(GL_TEXTURE_2D, 0);

    GPUTexture t;
    t.handle = reinterpret_cast<void*>(static_cast<uintptr_t>(tid));
    t.width = w;
    t.height = h;
    t.format = 0;

    m_loadedTextures[normalizedPath] = tid;
    m_loadedTextureInfo[normalizedPath] = t;
    return t;
}

void GlesSurfaceRenderer::unloadTexture(GPUTexture& texture) {
    const GLuint tid = static_cast<GLuint>(reinterpret_cast<uintptr_t>(texture.handle));
    if (tid == 0) return;
    glDeleteTextures(1, &tid);

    for (auto it = m_loadedTextures.begin(); it != m_loadedTextures.end();) {
        if (it->second == tid) it = m_loadedTextures.erase(it);
        else ++it;
    }
    for (auto it = m_loadedTextureInfo.begin(); it != m_loadedTextureInfo.end();) {
        const GLuint h = static_cast<GLuint>(reinterpret_cast<uintptr_t>(it->second.handle));
        if (h == tid) it = m_loadedTextureInfo.erase(it);
        else ++it;
    }

    texture.handle = nullptr;
    texture.width = 0;
    texture.height = 0;
}

NativeSurface GlesSurfaceRenderer::getEncoderSurface() {
    NativeSurface s;
    s.handle = m_window;
    s.width = m_width;
    s.height = m_height;
    return s;
}

bool GlesSurfaceRenderer::setEncoderSurface(const NativeSurface& surface) {
    if (m_window) {
        ANativeWindow_release(m_window);
        m_window = nullptr;
    }

    m_window = reinterpret_cast<ANativeWindow*>(surface.handle);
    if (m_window) {
        ANativeWindow_acquire(m_window);
    }

    // Keep EGLDisplay/EGLContext alive to preserve GL object handles.
    // Only recreate the EGLSurface for the new ANativeWindow.
    destroyEglSurface();
    m_lastPresentError.clear();
    m_lastEglError = 0;
    m_lastSetEncoderSurfaceOk = ensureEgl();
    if (!m_lastSetEncoderSurfaceOk) {
        m_lastEglError = static_cast<uint32_t>(eglGetError());
        m_lastPresentError = "setEncoderSurface:ensureEgl_failed";
        LOGE("setEncoderSurface failed: eglError=0x%x", m_lastEglError);
    }
    return m_lastSetEncoderSurfaceOk;
}

bool GlesSurfaceRenderer::presentFrame(int64_t ptsUs) {
    if (!ensureEgl()) {
        m_presentFailCount++;
        m_lastEglError = static_cast<uint32_t>(eglGetError());
        m_lastPresentError = "presentFrame:ensureEgl_failed";
        LOGE("presentFrame failed: ensureEgl (eglError=0x%x)", m_lastEglError);
        return false;
    }

    // Composite final scene (currently passthrough) to the encoder surface.
    GlFramebuffer::unbind();
    glViewport(0, 0, m_width, m_height);
    glClearColor(m_bgR, m_bgG, m_bgB, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    if (m_currentFbo && m_currentFbo->texture()) {
        m_quad.draw(m_width, m_height, m_currentFbo->width(), m_currentFbo->height(), m_currentFbo->texture(), m_rotation, m_flipHorizontal, m_flipVertical);
    }

    if (m_presentationTimeFn) {
        m_presentationTimeFn(m_display, m_surface, static_cast<EGLnsecsANDROID>(ptsUs * 1000));
    }

    const EGLBoolean ok = eglSwapBuffers(m_display, m_surface);
    if (ok == EGL_TRUE) {
        m_presentOkCount++;
        return true;
    }
    m_presentFailCount++;
    m_lastEglError = static_cast<uint32_t>(eglGetError());
    m_lastPresentError = "presentFrame:eglSwapBuffers_failed";
    LOGE("presentFrame failed: eglSwapBuffers (eglError=0x%x)", m_lastEglError);
    return false;
}

bool GlesSurfaceRenderer::ensureEgl() {
    if (!m_window) return false;
    if (m_display != EGL_NO_DISPLAY && m_surface != EGL_NO_SURFACE && m_context != EGL_NO_CONTEXT) return true;

    if (m_display == EGL_NO_DISPLAY) {
        m_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        if (m_display == EGL_NO_DISPLAY) return false;

        if (!eglInitialize(m_display, nullptr, nullptr)) return false;
    }

#ifndef EGL_RECORDABLE_ANDROID
#define EGL_RECORDABLE_ANDROID 0x3142
#endif

 #ifndef EGL_OPENGL_ES3_BIT_KHR
 #define EGL_OPENGL_ES3_BIT_KHR 0x0040
 #endif

    const EGLint cfgAttribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_RECORDABLE_ANDROID, 1,
        EGL_NONE
    };

    if (m_config == nullptr) {
        EGLint numConfigs = 0;
        if (!eglChooseConfig(m_display, cfgAttribs, &m_config, 1, &numConfigs) || numConfigs <= 0) return false;
    }

    if (m_context == EGL_NO_CONTEXT) {
        const EGLint ctxAttribs[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
        m_context = eglCreateContext(m_display, m_config, EGL_NO_CONTEXT, ctxAttribs);
        if (m_context == EGL_NO_CONTEXT) return false;
    }

    if (m_surface == EGL_NO_SURFACE) {
        m_surface = eglCreateWindowSurface(m_display, m_config, m_window, nullptr);
        if (m_surface == EGL_NO_SURFACE) return false;
    }

    if (!eglMakeCurrent(m_display, m_surface, m_surface, m_context)) return false;

    eglSwapInterval(m_display, 0);

    m_presentationTimeFn = reinterpret_cast<PresentationTimeFn>(eglGetProcAddress("eglPresentationTimeANDROID"));
    return true;
}

void GlesSurfaceRenderer::destroyEglSurface() {
    if (m_display == EGL_NO_DISPLAY) {
        m_surface = EGL_NO_SURFACE;
        return;
    }
    if (m_surface != EGL_NO_SURFACE) {
        // Detach surface from the current context but keep the context alive.
        eglMakeCurrent(m_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglDestroySurface(m_display, m_surface);
        m_surface = EGL_NO_SURFACE;
    }
}

void GlesSurfaceRenderer::cleanupEgl() {
    if (m_display != EGL_NO_DISPLAY) {
        destroyEglSurface();
        if (m_context != EGL_NO_CONTEXT) {
            eglDestroyContext(m_display, m_context);
            m_context = EGL_NO_CONTEXT;
        }
        eglTerminate(m_display);
        m_display = EGL_NO_DISPLAY;
    }
    m_config = nullptr;
    m_presentationTimeFn = nullptr;
}

} // namespace android
} // namespace vidviz
