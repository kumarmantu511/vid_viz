/**
 * VidViz Engine - iOS Bridge
 * 
 * iOS Objective-C++ köprüsü.
 * İNCE köprü - iş mantığı YOK!
 * Metal/CAMetalLayer setup ve Core'a bağlantı.
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>

#include "metal_renderer.h"
#include "avfoundation_encoder.h"
#include "core/engine.h"
#include "common/log.h"

// =============================================================================
// FFI Initialization (called from Dart via FFI)
// =============================================================================

extern "C" {

VIDVIZ_API void* vidviz_ios_init(void) {
    LOGI("iOS bridge: init");
    return vidviz_engine_init();
}

VIDVIZ_API void vidviz_ios_set_metal_layer(void* handle, void* metalLayer) {
    if (!metalLayer) {
        LOGW("Metal layer is null");
        return;
    }

    if (!handle) {
        LOGE("VIDVIZ_ERROR: Engine handle is null in set_metal_layer");
        return;
    }
    
    auto* engine = static_cast<vidviz::Engine*>(handle);
    engine->setMetalLayer(metalLayer);
    LOGI("Metal layer set: %p", metalLayer);
}

} // extern "C"
