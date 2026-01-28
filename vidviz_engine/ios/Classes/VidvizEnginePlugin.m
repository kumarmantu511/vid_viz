/**
 * VidViz Engine iOS Plugin Implementation
 */

#import "VidvizEnginePlugin.h"

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

extern void* vidviz_engine_init(void);
extern void vidviz_engine_destroy(void* handle);
extern int32_t vidviz_submit_job(void* handle, const char* jobJson);
extern void vidviz_cancel_job(void* handle);
extern const char* vidviz_get_status(void* handle);
extern const char* vidviz_get_last_init_error(void);
extern void vidviz_free_string(const char* str);

extern void* vidviz_ios_init(void);
extern void vidviz_ios_set_metal_layer(void* handle, void* metalLayer);

__attribute__((used)) static void* _vidviz_force_link_engine = (void*)&vidviz_engine_init;
__attribute__((used)) static void* _vidviz_force_link_engine_destroy = (void*)&vidviz_engine_destroy;
__attribute__((used)) static void* _vidviz_force_link_submit_job = (void*)&vidviz_submit_job;
__attribute__((used)) static void* _vidviz_force_link_cancel_job = (void*)&vidviz_cancel_job;
__attribute__((used)) static void* _vidviz_force_link_get_status = (void*)&vidviz_get_status;
__attribute__((used)) static void* _vidviz_force_link_get_last_init_error = (void*)&vidviz_get_last_init_error;
__attribute__((used)) static void* _vidviz_force_link_free_string = (void*)&vidviz_free_string;

__attribute__((used)) static void* _vidviz_force_link_ios_init = (void*)&vidviz_ios_init;
__attribute__((used)) static void* _vidviz_force_link_ios_set_metal_layer = (void*)&vidviz_ios_set_metal_layer;

static void* g_vidviz_last_forwarded_layer_ptr = NULL;

static CAMetalLayer* vvFindMetalLayer(UIView* view) {
    if (!view) return nil;
    CALayer* layer = view.layer;
    if ([layer isKindOfClass:[CAMetalLayer class]]) {
        return (CAMetalLayer*)layer;
    }
    for (UIView* sub in view.subviews) {
        CAMetalLayer* found = vvFindMetalLayer(sub);
        if (found) return found;
    }
    return nil;
}

@implementation VidvizEnginePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    // FFI plugin - no method channel needed
    // Native functions are accessed directly via dart:ffi
    NSLog(@"VidViz Engine iOS Plugin registered");

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* vc = registrar.viewController;
        if (!vc || !vc.isViewLoaded) {
            NSLog(@"VidViz Engine: viewController not ready, skipping metal layer forward");
            return;
        }

        CAMetalLayer* metalLayer = vvFindMetalLayer(vc.view);
        if (!metalLayer) {
            NSLog(@"VidViz Engine: CAMetalLayer not found in view hierarchy, skipping metal layer forward");
            return;
        }
        void* metalPtr = (__bridge void*)metalLayer;

        if (g_vidviz_last_forwarded_layer_ptr == metalPtr) {
            return;
        }

        void* handle = vidviz_ios_init();
        if (!handle) {
            NSLog(@"VidViz Engine: vidviz_ios_init returned null");
            return;
        }

        vidviz_ios_set_metal_layer(handle, (__bridge void*)metalLayer);
        g_vidviz_last_forwarded_layer_ptr = metalPtr;
        NSLog(@"VidViz Engine: forwarded CAMetalLayer=%p to native engine", metalLayer);
    });
}

@end
