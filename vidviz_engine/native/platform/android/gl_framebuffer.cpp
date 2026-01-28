#include "gl_framebuffer.h"

#include "common/log.h"

namespace vidviz {
namespace android {

bool GlFramebuffer::ensure(int32_t width, int32_t height) {
    if (width <= 0 || height <= 0) return false;
    if (m_fbo && m_tex && m_width == width && m_height == height) return true;

    destroy();

    m_width = width;
    m_height = height;

    glGenTextures(1, &m_tex);
    glBindTexture(GL_TEXTURE_2D, m_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, m_width, m_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenFramebuffers(1, &m_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, m_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_tex, 0);

    const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    if (status != GL_FRAMEBUFFER_COMPLETE) {
        LOGE("GlFramebuffer incomplete: 0x%x", static_cast<unsigned>(status));
        destroy();
        return false;
    }

    return true;
}

void GlFramebuffer::bind() const {
    glBindFramebuffer(GL_FRAMEBUFFER, m_fbo);
}

void GlFramebuffer::unbind() {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void GlFramebuffer::destroy() {
    if (m_fbo) {
        glDeleteFramebuffers(1, &m_fbo);
        m_fbo = 0;
    }
    if (m_tex) {
        glDeleteTextures(1, &m_tex);
        m_tex = 0;
    }
    m_width = 0;
    m_height = 0;
}

} // namespace android
} // namespace vidviz
