#pragma once

#include <cstdint>
#include <GLES3/gl3.h>

namespace vidviz {
namespace android {

class GlFramebuffer {
public:
    bool ensure(int32_t width, int32_t height);
    void bind() const;
    static void unbind();
    void destroy();

    GLuint texture() const { return m_tex; }
    int32_t width() const { return m_width; }
    int32_t height() const { return m_height; }

private:
    GLuint m_fbo = 0;
    GLuint m_tex = 0;
    int32_t m_width = 0;
    int32_t m_height = 0;
};

} // namespace android
} // namespace vidviz
