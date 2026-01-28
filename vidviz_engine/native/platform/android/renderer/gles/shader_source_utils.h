#pragma once

#include <string>

namespace vidviz {
namespace android {
namespace gles {

std::string toGles3FragmentSource(std::string src);
std::string toGles3TextEffectFragmentSource(std::string src);

} // namespace gles
} // namespace android
} // namespace vidviz
