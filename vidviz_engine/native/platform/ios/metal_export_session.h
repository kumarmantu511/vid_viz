#pragma once

#include "common/types.h"

namespace vidviz {
namespace ios {

struct IosEncoderSurface;

struct MetalExportSessionImpl;

class MetalExportSession {
public:
    MetalExportSession();
    ~MetalExportSession();

    bool configure(void* device, void* queue, void* textureCache, IosEncoderSurface* surface, int32_t width, int32_t height);
    bool beginFrame();
    bool endFrame();
    bool presentFrame(int64_t ptsUs);

    void setCurrentEncoder(void* encoder);

    void* currentEncoder() const;
    void* currentCommandBuffer() const;
    void* targetTexture() const;

private:
    MetalExportSessionImpl* m_impl = nullptr;
};

} // namespace ios
} // namespace vidviz
