#pragma once

#include <string>

#include "platform/ios/text/text_params.h"

namespace vidviz {
namespace ios {
namespace text {

bool parseTextParams(const std::string& dataJson, ParsedTextParams& out);

} // namespace text
} // namespace ios
} // namespace vidviz
