#pragma once

#include <cstdint>

#if defined(__ANDROID__)
#include <GLES3/gl3.h>
#endif

namespace vidviz {
namespace android {

class GlQuadRenderer {
public:
    GlQuadRenderer();
    ~GlQuadRenderer();

    GlQuadRenderer(const GlQuadRenderer&) = delete;
    GlQuadRenderer& operator=(const GlQuadRenderer&) = delete;

    bool initialize();
    void shutdown();

    void draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint rgbaTex);
    void draw(int32_t dstW, int32_t dstH, int32_t srcW, int32_t srcH, GLuint rgbaTex, int32_t rotation, bool flipH, bool flipV);

private:
    GLuint compile(GLenum type, const char* src);
    bool link(GLuint vs, GLuint fs);

private:
    GLuint m_program = 0;
    GLint m_posLoc = -1;
    GLint m_uvLoc = -1;
    GLint m_texLoc = -1;

    GLuint m_vbo = 0;
};

} // namespace android
} // namespace vidviz
