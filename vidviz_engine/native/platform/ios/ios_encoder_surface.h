#pragma once

#include "common/types.h"

namespace vidviz {
namespace ios {

struct IosEncoderSurface {
    void* pixelBufferPool = nullptr;     // CVPixelBufferPoolRef
    void* pixelBufferAdaptor = nullptr;  // AVAssetWriterInputPixelBufferAdaptor*
    void* videoInput = nullptr;          // AVAssetWriterInput*
    void* videoAppendQueue = nullptr;    // dispatch_queue_t (serial)
    void* assetWriter = nullptr;         // AVAssetWriter* (diagnostics)
    void* encoder = nullptr;             // vidviz::ios::AVFoundationEncoder*
};

} // namespace ios
} // namespace vidviz
