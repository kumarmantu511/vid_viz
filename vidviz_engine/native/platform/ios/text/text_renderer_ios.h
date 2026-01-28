#pragma once

#include "common/types.h"

namespace vidviz {
namespace ios {

class MetalRenderer;

namespace text {

class TextRendererIOS {
public:
    explicit TextRendererIOS(MetalRenderer* owner);
    ~TextRendererIOS();

    void render(const Asset& asset, TimeMs localTime);
    void cleanup();

private:
    MetalRenderer* m_owner = nullptr;
};

} // namespace text
} // namespace ios
} // namespace vidviz
