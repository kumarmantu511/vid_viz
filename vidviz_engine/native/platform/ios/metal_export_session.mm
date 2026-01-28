#import "metal_export_session.h"

#import "common/log.h"
#import "platform/ios/ios_encoder_surface.h"

#import <Metal/Metal.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CVMetalTextureCache.h>
#import <CoreMedia/CoreMedia.h>
 #include <unistd.h>
 #include <dispatch/dispatch.h>
 #include <string>
 
 #import "avfoundation_encoder.h"

namespace vidviz {
namespace ios {

struct MetalExportSessionImpl {
    id<MTLDevice> device = nil;
    id<MTLCommandQueue> queue = nil;
    CVMetalTextureCacheRef textureCache = nullptr;
    IosEncoderSurface* surface = nullptr;

    int32_t width = 0;
    int32_t height = 0;

    CVPixelBufferRef pixelBuffer = nullptr;
    CVMetalTextureRef cvMetalTexture = nullptr;
    id<MTLTexture> targetTexture = nil;

    id<MTLCommandBuffer> commandBuffer = nil;
    id<MTLRenderCommandEncoder> renderEncoder = nil;
};

MetalExportSession::MetalExportSession() {}

MetalExportSession::~MetalExportSession() {
    if (m_impl) {
        if (m_impl->cvMetalTexture) {
            CFRelease(m_impl->cvMetalTexture);
            m_impl->cvMetalTexture = nullptr;
        }
        if (m_impl->pixelBuffer) {
            CVPixelBufferRelease(m_impl->pixelBuffer);
            m_impl->pixelBuffer = nullptr;
        }
        m_impl->targetTexture = nil;
        m_impl->renderEncoder = nil;
        m_impl->commandBuffer = nil;
        m_impl->surface = nullptr;
        m_impl->textureCache = nullptr;
        m_impl->device = nil;
        m_impl->queue = nil;
    }
    delete m_impl;
    m_impl = nullptr;
}

bool MetalExportSession::configure(void* device, void* queue, void* textureCache, IosEncoderSurface* surface, int32_t width, int32_t height) {
    if (!m_impl) m_impl = new MetalExportSessionImpl();
    m_impl->device = (__bridge id<MTLDevice>)device;
    m_impl->queue = (__bridge id<MTLCommandQueue>)queue;
    m_impl->textureCache = (CVMetalTextureCacheRef)textureCache;
    m_impl->surface = surface;
    m_impl->width = width;
    m_impl->height = height;

    return (m_impl->device != nil) &&
           (m_impl->queue != nil) &&
           (m_impl->textureCache != nullptr) &&
           (m_impl->surface != nullptr) &&
           (m_impl->width > 0) &&
           (m_impl->height > 0);
}

bool MetalExportSession::beginFrame() {
    if (!m_impl || !m_impl->surface || !m_impl->surface->pixelBufferPool) return false;

    if (m_impl->cvMetalTexture) {
        CFRelease(m_impl->cvMetalTexture);
        m_impl->cvMetalTexture = nullptr;
    }
    if (m_impl->pixelBuffer) {
        CVPixelBufferRelease(m_impl->pixelBuffer);
        m_impl->pixelBuffer = nullptr;
    }
    m_impl->targetTexture = nil;
    m_impl->commandBuffer = nil;
    m_impl->renderEncoder = nil;

    CVPixelBufferPoolRef pool = (CVPixelBufferPoolRef)m_impl->surface->pixelBufferPool;
    CVPixelBufferRef pb = nullptr;
    const CVReturn prc = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb);
    if (prc != kCVReturnSuccess || !pb) {
        LOGE("CVPixelBufferPoolCreatePixelBuffer failed: %d", (int)prc);
        return false;
    }
    m_impl->pixelBuffer = pb;

    CVMetalTextureRef cvTex = nullptr;
    const CVReturn trc = CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        m_impl->textureCache,
        pb,
        nil,
        MTLPixelFormatBGRA8Unorm,
        (size_t)m_impl->width,
        (size_t)m_impl->height,
        0,
        &cvTex
    );
    if (trc != kCVReturnSuccess || !cvTex) {
        LOGE("CVMetalTextureCacheCreateTextureFromImage failed: %d", (int)trc);
        if (m_impl->pixelBuffer) {
            CVPixelBufferRelease(m_impl->pixelBuffer);
            m_impl->pixelBuffer = nullptr;
        }
        return false;
    }
    m_impl->cvMetalTexture = cvTex;
    m_impl->targetTexture = CVMetalTextureGetTexture(cvTex);
    if (!m_impl->targetTexture) {
        LOGE("CVMetalTextureGetTexture returned nil");
        if (m_impl->cvMetalTexture) {
            CFRelease(m_impl->cvMetalTexture);
            m_impl->cvMetalTexture = nullptr;
        }
        if (m_impl->pixelBuffer) {
            CVPixelBufferRelease(m_impl->pixelBuffer);
            m_impl->pixelBuffer = nullptr;
        }
        return false;
    }

    id<MTLCommandBuffer> cb = [m_impl->queue commandBuffer];
    if (!cb) {
        if (m_impl->cvMetalTexture) {
            CFRelease(m_impl->cvMetalTexture);
            m_impl->cvMetalTexture = nullptr;
        }
        if (m_impl->pixelBuffer) {
            CVPixelBufferRelease(m_impl->pixelBuffer);
            m_impl->pixelBuffer = nullptr;
        }
        m_impl->targetTexture = nil;
        return false;
    }
    m_impl->commandBuffer = cb;

    return true;
}

bool MetalExportSession::endFrame() {
    if (!m_impl || !m_impl->commandBuffer) return false;

    if (m_impl->renderEncoder) {
        [m_impl->renderEncoder endEncoding];
        m_impl->renderEncoder = nil;
    }

    return true;
}

void MetalExportSession::setCurrentEncoder(void* encoder) {
    if (!m_impl) return;
    m_impl->renderEncoder = (__bridge id<MTLRenderCommandEncoder>)encoder;
}

bool MetalExportSession::presentFrame(int64_t ptsUs) {
    if (!m_impl || !m_impl->surface || !m_impl->pixelBuffer) return false;
    if (!m_impl->surface->pixelBufferAdaptor || !m_impl->surface->videoInput) return false;
    if (!m_impl->commandBuffer) return false;

    AVAssetWriterInput* videoInput = (__bridge AVAssetWriterInput*)m_impl->surface->videoInput;
    AVAssetWriterInputPixelBufferAdaptor* adaptor = (__bridge AVAssetWriterInputPixelBufferAdaptor*)m_impl->surface->pixelBufferAdaptor;

    const CMTime pts = CMTimeMake(ptsUs, 1000000);
    CVPixelBufferRef pb = m_impl->pixelBuffer;
    CVMetalTextureRef cvTex = m_impl->cvMetalTexture;
    id<MTLCommandBuffer> cb = m_impl->commandBuffer;
    CVMetalTextureCacheRef cache = m_impl->textureCache;
    void* encPtr = m_impl->surface->encoder;
    void* writerPtr = m_impl->surface->assetWriter;
    void* appendQPtr = m_impl->surface->videoAppendQueue;

    if (encPtr) {
        vidviz::ios::AVFoundationEncoder* enc = static_cast<vidviz::ios::AVFoundationEncoder*>(encPtr);
        enc->onFrameScheduled();
    }

    [cb addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        (void)buffer;

        void* pbPtr = (void*)pb;
        void* cvTexPtr = (void*)cvTex;
        __block bool finalized = false;
        auto finalize = ^(BOOL appendOk, const std::string& failMsg) {
            if (finalized) return;
            finalized = true;
            if (encPtr) {
                vidviz::ios::AVFoundationEncoder* enc = static_cast<vidviz::ios::AVFoundationEncoder*>(encPtr);
                if (appendOk) {
                    enc->onFrameAppended();
                } else {
                    std::string msg = failMsg;
                    if (msg.empty()) msg = "appendPixelBuffer failed";
                    enc->onFrameAppendFailed(msg);
                }
            }
            if (pbPtr) {
                CVPixelBufferRelease((CVPixelBufferRef)pbPtr);
            }
            if (cvTexPtr) {
                CFRelease((CVMetalTextureRef)cvTexPtr);
            }
            if (cache) {
                CVMetalTextureCacheFlush(cache, 0);
            }
        };

        __block int tries = 0;
        dispatch_queue_t targetQ = nil;
        if (appendQPtr) {
            targetQ = (__bridge dispatch_queue_t)appendQPtr;
        } else {
            targetQ = dispatch_get_main_queue();
        }

        __block dispatch_block_t attemptBlock = nil;
        attemptBlock = ^{
            AVAssetWriter* w = writerPtr ? (__bridge AVAssetWriter*)writerPtr : nil;
            if (w && w.status != AVAssetWriterStatusWriting) {
                const long st = (long)w.status;
                NSString* errStr = (w && w.error) ? [w.error localizedDescription] : nil;
                std::string msg = std::string("writerStatus=") + std::to_string(st);
                if (errStr) {
                    msg += ": ";
                    msg += [errStr UTF8String];
                }
                finalize(NO, msg);
                return;
            }

            if (![videoInput isReadyForMoreMediaData]) {
                tries++;
                if (tries >= 600) {
                    const long st = w ? (long)w.status : -1;
                    NSString* errStr = (w && w.error) ? [w.error localizedDescription] : nil;
                    std::string msg = std::string("videoInput not ready (writerStatus=") + std::to_string(st) + ")";
                    if (errStr) {
                        msg += ": ";
                        msg += [errStr UTF8String];
                    }
                    finalize(NO, msg);
                    return;
                }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)), targetQ, attemptBlock);
                return;
            }

            const BOOL ok = [adaptor appendPixelBuffer:(CVPixelBufferRef)pbPtr withPresentationTime:pts];
            if (ok) {
                finalize(YES, std::string());
                return;
            }

            tries++;
            if (tries < 60) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)), targetQ, attemptBlock);
                return;
            }

            AVAssetWriter* w2 = writerPtr ? (__bridge AVAssetWriter*)writerPtr : nil;
            long st2 = w2 ? (long)w2.status : -1;
            NSString* errStr2 = (w2 && w2.error) ? [w2.error localizedDescription] : nil;
            std::string msg = std::string("appendPixelBuffer failed (writerStatus=") + std::to_string(st2) + ")";
            if (errStr2) {
                msg += ": ";
                msg += [errStr2 UTF8String];
            }
            finalize(NO, msg);
        };

        dispatch_async(targetQ, attemptBlock);
    }];

    [cb commit];

    // Release ownership of per-frame resources; completion handler will free.
    m_impl->pixelBuffer = nullptr;
    m_impl->cvMetalTexture = nullptr;
    m_impl->targetTexture = nil;
    m_impl->commandBuffer = nil;

    return true;
}

void* MetalExportSession::currentEncoder() const {
    return m_impl ? (__bridge void*)m_impl->renderEncoder : nullptr;
}

void* MetalExportSession::currentCommandBuffer() const {
    return m_impl ? (__bridge void*)m_impl->commandBuffer : nullptr;
}

void* MetalExportSession::targetTexture() const {
    return m_impl ? (__bridge void*)m_impl->targetTexture : nullptr;
}

} // namespace ios
} // namespace vidviz
