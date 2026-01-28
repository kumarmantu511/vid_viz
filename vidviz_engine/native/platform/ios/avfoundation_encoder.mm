/**
 * VidViz Engine - AVFoundation Encoder Implementation (iOS)
 * 
 * POC implementation - basic AVAssetWriter setup
 */

#import "avfoundation_encoder.h"
#import "common/log.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

#include <vector>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <dispatch/dispatch.h>

namespace vidviz {
namespace ios {

static CMSampleBufferRef vvCopySampleBufferWithShift(CMSampleBufferRef sb, CMTime shift) {
    if (!sb) return nullptr;
    if (CMTIME_IS_INVALID(shift) || CMTIME_IS_INDEFINITE(shift) || CMTIME_COMPARE_INLINE(shift, ==, kCMTimeZero)) {
        CFRetain(sb);
        return sb;
    }

    CMItemCount count = 0;
    if (CMSampleBufferGetSampleTimingInfoArray(sb, 0, nullptr, &count) != noErr || count <= 0) {
        CFRetain(sb);
        return sb;
    }

    std::vector<CMSampleTimingInfo> infos;
    infos.resize(static_cast<size_t>(count));
    if (CMSampleBufferGetSampleTimingInfoArray(sb, count, infos.data(), &count) != noErr) {
        CFRetain(sb);
        return sb;
    }

    for (auto& ti : infos) {
        if (CMTIME_IS_VALID(ti.presentationTimeStamp)) {
            ti.presentationTimeStamp = CMTimeAdd(ti.presentationTimeStamp, shift);
        }
        if (CMTIME_IS_VALID(ti.decodeTimeStamp)) {
            ti.decodeTimeStamp = CMTimeAdd(ti.decodeTimeStamp, shift);
        }
    }

    CMSampleBufferRef out = nullptr;
    const OSStatus st = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sb, count, infos.data(), &out);
    if (st != noErr || !out) {
        CFRetain(sb);
        return sb;
    }
    return out;
}

static NSString* vvEnsureMp4Extension(NSString* path) {
    if (!path) return path;
    NSString* lower = [path lowercaseString];
    if ([lower hasSuffix:@".mp4"]) return path;
    return [path stringByAppendingString:@".mp4"]; 
}

static NSString* vvResolveOutputPath(const std::string& outputPath) {
    NSString* raw = [NSString stringWithUTF8String:outputPath.c_str()];
    if (!raw || raw.length == 0) {
        NSString* tmp = NSTemporaryDirectory();
        NSString* file = [NSString stringWithFormat:@"vidviz_export_%lld.mp4", (long long)([[NSDate date] timeIntervalSince1970] * 1000.0)];
        return [tmp stringByAppendingPathComponent:file];
    }

    NSURL* url = nil;
    if ([raw hasPrefix:@"file://"]) {
        url = [NSURL URLWithString:raw];
        if (url && url.isFileURL) {
            raw = url.path;
        }
    }

    raw = vvEnsureMp4Extension(raw);

    if (![raw hasPrefix:@"/"]) {
        NSString* tmp = NSTemporaryDirectory();
        raw = [tmp stringByAppendingPathComponent:raw];
    }

    return raw;
}

AVFoundationEncoder::AVFoundationEncoder() {
    LOGI("AVFoundationEncoder created");
}

AVFoundationEncoder::~AVFoundationEncoder() {
    shutdown();
    LOGI("AVFoundationEncoder destroyed");
}

bool AVFoundationEncoder::initialize() {
    LOGI("AVFoundationEncoder initialized");
    return true;
}

void AVFoundationEncoder::shutdown() {
    cleanup();
    LOGI("AVFoundationEncoder shutdown");
}

bool AVFoundationEncoder::configure(
    int32_t width,
    int32_t height,
    int32_t fps,
    int32_t quality,
    const std::string& outputPath
) {
    cleanup();
    m_started = false;
    m_frameCount = 0;
    m_presentationTimeValue = 0;
    m_pendingFrames.store(0);
    m_pendingAudio.store(0);

    m_width = width;
    m_height = height;
    m_fps = fps;
    m_outputPath = outputPath;
    
    // Quality to bitrate mapping
    switch (quality) {
        case 0: m_bitrate = 5000000;  break;
        case 1: m_bitrate = 10000000; break;
        case 2: m_bitrate = 20000000; break;
        default: m_bitrate = 10000000;
    }
    
    if (!createAssetWriter()) return false;
    if (!createVideoInput()) return false;
    if (!createPixelBufferPool()) return false;

    if (!m_videoAppendQueue) {
        dispatch_queue_t q = dispatch_queue_create("vidviz.video.append", DISPATCH_QUEUE_SERIAL);
        m_videoAppendQueue = (__bridge_retained void*)q;
    }
    
    LOGI("Encoder configured: %dx%d @ %dfps, bitrate: %d",
         m_width, m_height, m_fps, m_bitrate);
    
    return true;
}

bool AVFoundationEncoder::start() {
    AVAssetWriter* writer = (__bridge AVAssetWriter*)m_assetWriter;
    if (!writer) return false;

    if (!m_audioTracks.empty() && !m_audioInput) {
        const AudioTrack& t = m_audioTracks[0];
        NSString* path = [NSString stringWithUTF8String:t.audioPath.c_str()];
        if (path && path.length > 0) {
            NSURL* url = [NSURL fileURLWithPath:path];
            AVURLAsset* asset = [AVURLAsset URLAssetWithURL:url options:nil];
            NSArray<AVAssetTrack*>* tracks = [asset tracksWithMediaType:AVMediaTypeAudio];
            AVAssetTrack* aTrack = (tracks.count > 0) ? tracks[0] : nil;

            if (aTrack) {
                double sampleRate = 44100.0;
                int channels = 2;
                if (aTrack.formatDescriptions.count > 0) {
                    CMAudioFormatDescriptionRef fmt = (__bridge CMAudioFormatDescriptionRef)aTrack.formatDescriptions[0];
                    const AudioStreamBasicDescription* asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
                    if (asbd) {
                        if (asbd->mSampleRate > 0) sampleRate = asbd->mSampleRate;
                        if (asbd->mChannelsPerFrame > 0) channels = (int)asbd->mChannelsPerFrame;
                    }
                }

                NSDictionary* audioOutSettings = @{
                    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: @(sampleRate),
                    AVNumberOfChannelsKey: @(channels),
                    AVEncoderBitRateKey: @(128000)
                };

                AVAssetWriterInput* audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                                      outputSettings:audioOutSettings];
                audioInput.expectsMediaDataInRealTime = NO;
                if ([writer canAddInput:audioInput]) {
                    [writer addInput:audioInput];
                    m_audioInput = (__bridge_retained void*)audioInput;
                } else {
                    LOGE("VIDVIZ_ERROR: Cannot add audio input");
                    {
                        std::lock_guard<std::mutex> lock(m_pendingMutex);
                        if (m_lastError.empty()) {
                            m_lastError = "Cannot add audio input";
                        }
                    }
                    return false;
                }

                NSError* rErr = nil;
                AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:asset error:&rErr];
                if (rErr || !reader) {
                    LOGE("VIDVIZ_ERROR: Failed to create AVAssetReader: %s", [[rErr localizedDescription] UTF8String]);
                    {
                        std::lock_guard<std::mutex> lock(m_pendingMutex);
                        if (m_lastError.empty()) {
                            m_lastError = std::string("Audio reader create failed: ") + ([[rErr localizedDescription] UTF8String] ?: "unknown");
                        }
                    }
                    return false;
                }
                m_audioReader = (__bridge_retained void*)reader;

                if (t.duration > 0) {
                    const CMTime start = CMTimeMake(static_cast<int64_t>(t.cutFrom), 1000);
                    const CMTime dur = CMTimeMake(static_cast<int64_t>(t.duration), 1000);
                    reader.timeRange = CMTimeRangeMake(start, dur);
                }

                NSDictionary* readerOut = @{
                    AVFormatIDKey: @(kAudioFormatLinearPCM),
                    AVLinearPCMIsNonInterleaved: @NO,
                    AVLinearPCMBitDepthKey: @(16),
                    AVLinearPCMIsFloatKey: @NO,
                    AVLinearPCMIsBigEndianKey: @NO
                };
                AVAssetReaderTrackOutput* out = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:aTrack outputSettings:readerOut];
                out.alwaysCopiesSampleData = NO;
                if ([reader canAddOutput:out]) {
                    [reader addOutput:out];
                    m_audioOutput = (__bridge_retained void*)out;
                } else {
                    LOGE("VIDVIZ_ERROR: Cannot add audio reader output");
                    {
                        std::lock_guard<std::mutex> lock(m_pendingMutex);
                        if (m_lastError.empty()) {
                            m_lastError = "Cannot add audio reader output";
                        }
                    }
                    return false;
                }

                if (![reader startReading]) {
                    LOGE("VIDVIZ_ERROR: startReading failed");
                    {
                        std::lock_guard<std::mutex> lock(m_pendingMutex);
                        if (m_lastError.empty()) {
                            m_lastError = "Audio startReading failed";
                        }
                    }
                    return false;
                }

                dispatch_queue_t q = dispatch_queue_create("vidviz.audio.append", DISPATCH_QUEUE_SERIAL);
                m_audioQueue = (__bridge_retained void*)q;
                m_pendingAudio.fetch_add(1);
            }
        }
    }
    
    if (![writer startWriting]) {
        LOGE("VIDVIZ_ERROR: Failed to start writing: %s", [[writer.error localizedDescription] UTF8String]);
        return false;
    }
    
    [writer startSessionAtSourceTime:kCMTimeZero];

    // Pixel buffer pool is typically created after startWriting/startSession.
    // Refresh it here and retain for the duration of the encoding session.
    AVAssetWriterInputPixelBufferAdaptor* adaptor = (__bridge AVAssetWriterInputPixelBufferAdaptor*)m_pixelBufferAdaptor;
    CVPixelBufferPoolRef pool = adaptor ? adaptor.pixelBufferPool : nullptr;
    if (!pool) {
        LOGE("VIDVIZ_ERROR: Pixel buffer pool is null after startSession");
        return false;
    }
    if (m_pixelBufferPool) {
        CFRelease(m_pixelBufferPool);
        m_pixelBufferPool = nullptr;
    }
    m_pixelBufferPool = (void*)CFRetain(pool);
    
    m_started = true;
    m_frameCount = 0;
    m_presentationTimeValue = 0;

    if (m_audioReader && m_audioOutput && m_audioInput && m_audioQueue && !m_audioTracks.empty()) {
        AVAssetReaderTrackOutput* out = (__bridge AVAssetReaderTrackOutput*)m_audioOutput;
        AVAssetWriterInput* audioInput = (__bridge AVAssetWriterInput*)m_audioInput;
        dispatch_queue_t q = (__bridge dispatch_queue_t)m_audioQueue;
        const AudioTrack t = m_audioTracks[0];
        const CMTime shift = CMTimeSubtract(CMTimeMake(static_cast<int64_t>(t.startTime), 1000), CMTimeMake(static_cast<int64_t>(t.cutFrom), 1000));

        __block bool finished = false;
        __block bool signaled = false;
        void* encPtr = this;

        [audioInput requestMediaDataWhenReadyOnQueue:q usingBlock:^{
            @autoreleasepool {
                while ([audioInput isReadyForMoreMediaData] && !finished) {
                    CMSampleBufferRef sb = [out copyNextSampleBuffer];
                    if (!sb) {
                        [audioInput markAsFinished];
                        finished = true;
                        break;
                    }

                    CMSampleBufferRef shifted = vvCopySampleBufferWithShift(sb, shift);
                    CFRelease(sb);
                    const BOOL ok = [audioInput appendSampleBuffer:shifted];
                    CFRelease(shifted);
                    if (!ok) {
                        if (encPtr) {
                            auto* enc = static_cast<vidviz::ios::AVFoundationEncoder*>(encPtr);
                            std::lock_guard<std::mutex> lock(enc->m_pendingMutex);
                            if (enc->m_lastError.empty()) {
                                enc->m_lastError = "Audio append failed";
                            }
                        }
                        [audioInput markAsFinished];
                        finished = true;
                        break;
                    }
                }
            }

            if (finished && !signaled && encPtr) {
                signaled = true;
                auto* enc = static_cast<vidviz::ios::AVFoundationEncoder*>(encPtr);
                const int32_t left = enc->m_pendingAudio.fetch_sub(1) - 1;
                if (left <= 0) {
                    std::lock_guard<std::mutex> lock(enc->m_pendingMutex);
                    enc->m_pendingCv.notify_all();
                }
            }
        }];
    }
    
    LOGI("Encoder started");
    return true;
}

bool AVFoundationEncoder::drain() {
    if (!m_started) return false;
    return true;
}

void AVFoundationEncoder::onFrameScheduled() {
    // We must track in-flight frames even if finish/cancel flips m_started while
    // Metal command buffer completion handlers are still running.
    m_pendingFrames.fetch_add(1);
}

void AVFoundationEncoder::onFrameAppended() {
    m_frameCount++;

    int32_t prev = m_pendingFrames.fetch_sub(1);
    int32_t left = prev - 1;
    if (left < 0) {
        m_pendingFrames.store(0);
        left = 0;
    }
    if (left <= 0) {
        std::lock_guard<std::mutex> lock(m_pendingMutex);
        m_pendingCv.notify_all();
    }
}

void AVFoundationEncoder::onFrameAppendFailed(const std::string& error) {
    {
        std::lock_guard<std::mutex> lock(m_pendingMutex);
        if (m_lastError.empty()) {
            m_lastError = error;
        }
    }

    int32_t prev = m_pendingFrames.fetch_sub(1);
    int32_t left = prev - 1;
    if (left < 0) {
        m_pendingFrames.store(0);
        left = 0;
    }
    if (left <= 0) {
        std::lock_guard<std::mutex> lock(m_pendingMutex);
        m_pendingCv.notify_all();
    }
}

std::string AVFoundationEncoder::getLastErrorMessage() const {
    std::lock_guard<std::mutex> lock(m_pendingMutex);
    return m_lastError;
}

bool AVFoundationEncoder::finish() {
    if (!m_started) return true;
    
    LOGI("Finishing encoder...");

    // Wait for any in-flight GPU frames to be appended to the writer.
    {
        std::unique_lock<std::mutex> lock(m_pendingMutex);
        const bool done = m_pendingCv.wait_for(
            lock,
            std::chrono::seconds(30),
            [this] { return m_pendingFrames.load() <= 0 && m_pendingAudio.load() <= 0; }
        );
        if (!done) {
            const int32_t pf = m_pendingFrames.load();
            const int32_t pa = m_pendingAudio.load();
            LOGE("VIDVIZ_ERROR: finish() timeout waiting pending frames (pendingFrames=%d, pendingAudio=%d)", pf, pa);
            if (m_lastError.empty()) {
                m_lastError = "finish() timeout waiting pending frames";
            }
        }
    }

    {
        std::lock_guard<std::mutex> lock(m_pendingMutex);
        if (!m_lastError.empty()) {
            AVAssetWriter* writer = (__bridge AVAssetWriter*)m_assetWriter;
            if (writer) {
                [writer cancelWriting];
            }
            LOGE("VIDVIZ_ERROR: Frame append failed: %s", m_lastError.c_str());
            m_started = false;
            return false;
        }
    }

    AVAssetWriterInput* videoInput = (__bridge AVAssetWriterInput*)m_videoInput;
    [videoInput markAsFinished];

    if (m_audioInput) {
        AVAssetWriterInput* audioInput = (__bridge AVAssetWriterInput*)m_audioInput;
        [audioInput markAsFinished];
    }
    
    AVAssetWriter* writer = (__bridge AVAssetWriter*)m_assetWriter;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [writer finishWritingWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];

    // Avoid hanging forever if writer never completes.
    const dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC));
    const long waitRes = dispatch_semaphore_wait(semaphore, timeout);
    if (waitRes != 0) {
        LOGE("VIDVIZ_ERROR: finishWriting timeout");
        if (writer) {
            [writer cancelWriting];
        }
        {
            std::lock_guard<std::mutex> lock(m_pendingMutex);
            if (m_lastError.empty()) {
                m_lastError = "finishWriting timeout";
            }
        }
        m_started = false;
        return false;
    }
    
    if (writer.status == AVAssetWriterStatusFailed) {
        LOGE("VIDVIZ_ERROR: Writing failed: %s", [[writer.error localizedDescription] UTF8String]);
        {
            std::lock_guard<std::mutex> lock(m_pendingMutex);
            if (m_lastError.empty()) {
                m_lastError = std::string("AVAssetWriter failed: ") + [[writer.error localizedDescription] UTF8String];
            }
        }
        m_started = false;
        return false;
    }
    
    m_started = false;
    LOGI("Encoder finished. Total frames: %d", m_frameCount);
    
    return true;
}

void AVFoundationEncoder::cancel() {
    if (!m_started) return;

    AVAssetWriter* writer = (__bridge AVAssetWriter*)m_assetWriter;
    if (writer) {
        [writer cancelWriting];
    }

    if (m_audioReader) {
        AVAssetReader* reader = (__bridge AVAssetReader*)m_audioReader;
        [reader cancelReading];
    }

    // Unblock any waiting finish/drain.
    m_pendingFrames.store(0);
    m_pendingAudio.store(0);
    {
        std::lock_guard<std::mutex> lock(m_pendingMutex);
        m_pendingCv.notify_all();
    }

    m_started = false;
    LOGI("Encoder cancelled");
}

bool AVFoundationEncoder::addAudioTrack(
    const std::string& audioPath,
    TimeMs startTime,
    TimeMs duration,
    TimeMs cutFrom,
    float volume
) {
    if (audioPath.empty()) return false;
    AudioTrack t;
    t.audioPath = audioPath;
    t.startTime = startTime;
    t.duration = duration;
    t.cutFrom = cutFrom;
    t.volume = volume;
    m_audioTracks.push_back(std::move(t));
    LOGI("Adding audio track: %s", audioPath.c_str());
    return true;
}

void AVFoundationEncoder::setAudioMix(const std::vector<std::pair<std::string, float>>& tracks) {
    // TODO: Configure audio mixing
}

NativeSurface AVFoundationEncoder::getInputSurface() {
    NativeSurface surface;
    m_surface.pixelBufferPool = m_pixelBufferPool;
    m_surface.pixelBufferAdaptor = m_pixelBufferAdaptor;
    m_surface.videoInput = m_videoInput;
    m_surface.videoAppendQueue = m_videoAppendQueue;
    m_surface.assetWriter = m_assetWriter;
    m_surface.encoder = this;

    surface.handle = &m_surface;
    surface.width = m_width;
    surface.height = m_height;
    return surface;
}

// =============================================================================
// Helper Methods
// =============================================================================

bool AVFoundationEncoder::createAssetWriter() {
    NSString* resolvedPath = vvResolveOutputPath(m_outputPath);
    if (!resolvedPath || resolvedPath.length == 0) {
        LOGE("Output path resolve failed");
        return false;
    }
    m_outputPath = [resolvedPath UTF8String];

    NSString* dir = [resolvedPath stringByDeletingLastPathComponent];
    if (dir && dir.length > 0) {
        NSError* mkErr = nil;
        BOOL ok = [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&mkErr];
        if (!ok) {
            LOGE("Failed to create output directory: %s", [[mkErr localizedDescription] UTF8String]);
            return false;
        }
    }

    NSURL* url = [NSURL fileURLWithPath:resolvedPath];

    NSError* rmErr = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:resolvedPath]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:&rmErr];
        if (rmErr) {
            LOGE("Failed to remove existing output file: %s", [[rmErr localizedDescription] UTF8String]);
            return false;
        }
    }
    
    NSError* error = nil;
    AVAssetWriter* writer = [[AVAssetWriter alloc] initWithURL:url
                                                      fileType:AVFileTypeMPEG4
                                                         error:&error];
    
    if (error) {
        LOGE("Failed to create asset writer: %s", [[error localizedDescription] UTF8String]);
        return false;
    }
    
    m_assetWriter = (__bridge_retained void*)writer;
    {
        std::lock_guard<std::mutex> lock(m_pendingMutex);
        m_lastError.clear();
    }
    LOGI("Asset writer created");
    return true;
}

bool AVFoundationEncoder::createVideoInput() {
    NSDictionary* outputSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(m_width),
        AVVideoHeightKey: @(m_height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(m_bitrate),
            AVVideoExpectedSourceFrameRateKey: @(m_fps),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        }
    };
    
    AVAssetWriterInput* videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                        outputSettings:outputSettings];
    videoInput.expectsMediaDataInRealTime = NO;
    
    AVAssetWriter* writer = (__bridge AVAssetWriter*)m_assetWriter;
    if (![writer canAddInput:videoInput]) {
        LOGE("Cannot add video input");
        return false;
    }
    
    [writer addInput:videoInput];
    m_videoInput = (__bridge_retained void*)videoInput;
    
    // Create pixel buffer adaptor
    NSDictionary* sourceAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey: @(m_width),
        (id)kCVPixelBufferHeightKey: @(m_height),
        (id)kCVPixelBufferMetalCompatibilityKey: @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    
    AVAssetWriterInputPixelBufferAdaptor* adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoInput
                                                                         sourcePixelBufferAttributes:sourceAttributes];
    
    m_pixelBufferAdaptor = (__bridge_retained void*)adaptor;
    
    LOGI("Video input created");
    return true;
}

bool AVFoundationEncoder::createPixelBufferPool() {
    AVAssetWriterInputPixelBufferAdaptor* adaptor = (__bridge AVAssetWriterInputPixelBufferAdaptor*)m_pixelBufferAdaptor;
    
    // Pool is created automatically by the adaptor
    // We'll get it after starting
    m_pixelBufferPool = nullptr;
    
    LOGI("Pixel buffer pool ready");
    return true;
}

void AVFoundationEncoder::cleanup() {
    m_pendingFrames.store(0);
    m_pendingAudio.store(0);

    if (m_pixelBufferPool) {
        CFRelease(m_pixelBufferPool);
        m_pixelBufferPool = nullptr;
    }

    if (m_audioQueue) {
        id q = (__bridge_transfer id)m_audioQueue;
        (void)q;
        m_audioQueue = nullptr;
    }

    if (m_videoAppendQueue) {
        id q = (__bridge_transfer id)m_videoAppendQueue;
        (void)q;
        m_videoAppendQueue = nullptr;
    }

    if (m_audioOutput) {
        CFRelease(m_audioOutput);
        m_audioOutput = nullptr;
    }

    if (m_audioReader) {
        CFRelease(m_audioReader);
        m_audioReader = nullptr;
    }

    if (m_audioInput) {
        CFRelease(m_audioInput);
        m_audioInput = nullptr;
    }

    if (m_pixelBufferAdaptor) {
        CFRelease(m_pixelBufferAdaptor);
        m_pixelBufferAdaptor = nullptr;
    }
    
    if (m_videoInput) {
        CFRelease(m_videoInput);
        m_videoInput = nullptr;
    }
    
    if (m_assetWriter) {
        CFRelease(m_assetWriter);
        m_assetWriter = nullptr;
    }
    
    m_pixelBufferPool = nullptr;
}

} // namespace ios
} // namespace vidviz
