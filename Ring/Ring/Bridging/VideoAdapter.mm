/*
 * Copyright (C) 2018-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

#import "VideoAdapter.h"
#import "Utils.h"
#import "MediaUtils.h"

#import "Ring-Swift.h"

#include <AVFoundation/AVFoundation.h>

#include <atomic>
#include <map>
#include <memory>
#include <mutex>
#include <utility>

#import "jami/videomanager_interface.h"
#import "jami/callmanager_interface.h"

using namespace libjami;

/// Per-sink state the libjami push callback needs. Jointly owned by the
/// adapter's map and by the SinkTarget registered with libjami, so it outlives
/// whichever side is released first.
struct Renderer
{
    Renderer(NSString* sinkId, int width, int height, bool hasListeners)
        : sinkId([sinkId copy])
        , width_(width)
        , height_(height)
        , hasListeners_(hasListeners)
    {}

    void updateSize(int width, int height)
    {
        std::lock_guard<std::mutex> lock(sizeMutex_);
        width_ = width;
        height_ = height;
    }

    std::pair<int, int> size() const
    {
        std::lock_guard<std::mutex> lock(sizeMutex_);
        return {width_, height_};
    }

    void setHasListeners(bool hasListeners)
    {
        hasListeners_.store(hasListeners, std::memory_order_relaxed);
    }

    /// Runs on a libjami thread, which holds the sink's own mutex for the whole
    /// call. Skipping the conversion when nothing is on screen is the only
    /// reason to consult `hasListeners_` here.
    void pushFrame(FrameBuffer frame)
    {
        if (!hasListeners_.load(std::memory_order_relaxed)) {
            return;
        }
        @autoreleasepool {
            id<VideoAdapterDelegate> delegate = VideoAdapter.videoDelegate;
            if (!delegate) {
                return;
            }
            PixelBufferInfo info = [MediaUtils getCVPixelBufferFromAVFrame:std::move(frame.get())];
            if (info.pixelBuffer == NULL) {
                return;
            }
            [delegate writeFrameWithBuffer:info.pixelBuffer sinkId:sinkId rotation:info.rotation];
            if (info.ownsMemory) {
                CFRelease(info.pixelBuffer);
            }
        }
    }

    __strong NSString* const sinkId;

private:
    mutable std::mutex sizeMutex_;
    int width_;
    int height_;
    std::atomic_bool hasListeners_;
};

@interface VideoAdapter ()

- (std::shared_ptr<Renderer>)findRenderer:(const std::string&)rendererId;

@end

@implementation VideoAdapter {
    std::map<std::string, std::shared_ptr<Renderer>> renderers;
    /// Guards `renderers` alone, and is never held across a libjami call so
    /// that listener updates from the main thread never wait on a frame.
    std::mutex renderersMutex;
    /// Serializes registration against removal for the same sink.
    std::mutex rendererLifecycleMutex;
}

// Static delegates that will receive the propagated daemon events
static __weak id<VideoAdapterDelegate> _videoDelegate;
static __weak id<DecodingAdapterDelegate> _decodingDelegate;

#pragma mark Init

- (id)init {
    if (self = [super init]) {
        [self registerVideoHandlers];
    }
    return self;
}

#pragma mark -

#pragma mark Callbacks registration

- (void)registerVideoHandlers {
    std::map<std::string, std::shared_ptr<CallbackWrapperBase>> videoHandlers;

    videoHandlers.insert(exportable_callback<VideoSignal::DecodingStarted>([](const std::string& renderer_id,
                                                                               const std::string& shm_path,
                                                                               int w,
                                                                               int h,
                                                                               bool is_mixer) {
        id<DecodingAdapterDelegate> delegate = VideoAdapter.decodingDelegate;
        if (delegate) {
            NSString* sinkId = [NSString stringWithUTF8String:renderer_id.c_str()];
            [delegate decodingStartedWithSinkId:sinkId withWidth:(NSInteger)w withHeight:(NSInteger)h];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::DecodingStopped>([](const std::string& renderer_id,
                                                                               const std::string& shm_path,
                                                                               bool is_mixer) {
        id<DecodingAdapterDelegate> delegate = VideoAdapter.decodingDelegate;
        if (delegate) {
            NSString* sinkId = [NSString stringWithUTF8String:renderer_id.c_str()];
            [delegate decodingStoppedWithSinkId:sinkId];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StartCapture>([](const std::string& device) {
        id<VideoAdapterDelegate> delegate = VideoAdapter.videoDelegate;
        if (delegate) {
            NSString* deviceString = [NSString stringWithUTF8String:device.c_str()];
            [delegate startCaptureWithDevice:deviceString];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StopCapture>([](const std::string& deviceId) {
        id<VideoAdapterDelegate> delegate = VideoAdapter.videoDelegate;
        if (delegate) {
            NSString* deviceString = @(deviceId.c_str());
            [delegate stopCaptureWithDevice:deviceString];
        }
    }));

    videoHandlers.insert(exportable_callback<MediaPlayerSignal::FileOpened>([](const std::string& playerId, std::map<std::string, std::string> playerInfo) {
        id<VideoAdapterDelegate> delegate = VideoAdapter.videoDelegate;
        if (delegate) {
            NSString* player = @(playerId.c_str());
            NSMutableDictionary* info = [Utils mapToDictionary:playerInfo];
            [delegate fileOpenedFor:player fileInfo:info];
        }
    }));

    registerSignalHandlers(videoHandlers);
}

#pragma mark -

- (std::shared_ptr<Renderer>)findRenderer:(const std::string&)rendererId {
    std::lock_guard<std::mutex> lock(renderersMutex);
    auto value = renderers.find(rendererId);
    return value == renderers.end() ? nullptr : value->second;
}

-(CGSize)getRenderSize:(NSString* )sinkId {
    auto renderer = [self findRenderer:std::string([sinkId UTF8String])];
    if (!renderer) {
        return CGSizeZero;
    }
    auto size = renderer->size();
    return CGSizeMake(size.first, size.second);
}

- (void)registerSinkTargetWithSinkId:sinkId
                           withWidth:(NSInteger)w
                          withHeight:(NSInteger)h
                         hasListeners:(BOOL)hasListeners {
    auto rendererId = std::string([sinkId UTF8String]);
    std::lock_guard<std::mutex> lifecycleLock(rendererLifecycleMutex);
    if (auto renderer = [self findRenderer:rendererId]) {
        renderer->updateSize(static_cast<int>(w), static_cast<int>(h));
        renderer->setHasListeners(hasListeners);
        return;
    }
    auto renderer = std::make_shared<Renderer>(sinkId,
                                               static_cast<int>(w),
                                               static_cast<int>(h),
                                               hasListeners);
    {
        std::lock_guard<std::mutex> lock(renderersMutex);
        renderers.emplace(rendererId, renderer);
    }
    SinkTarget target;
    target.push = [renderer](FrameBuffer frame) {
        renderer->pushFrame(std::move(frame));
    };
    if (!registerSinkTarget(rendererId, std::move(target))) {
        std::lock_guard<std::mutex> lock(renderersMutex);
        renderers.erase(rendererId);
    }
}

- (void)removeSinkTargetWithSinkId:(NSString*)sinkId {
    auto rendererId = std::string([sinkId UTF8String]);
    std::lock_guard<std::mutex> lifecycleLock(rendererLifecycleMutex);
    if (![self findRenderer:rendererId]) {
        return;
    }
    // Replacing the target is the synchronization point: the sink takes its own
    // mutex both here and around every push, so once this returns no frame is
    // in flight and no further frame can start. Dropping our entry afterwards
    // releases the last reference to the renderer.
    registerSinkTarget(rendererId, SinkTarget {});
    std::lock_guard<std::mutex> lock(renderersMutex);
    renderers.erase(rendererId);
}

- (void)setHasListeners:(BOOL)hasListeners forSinkId:(NSString*)sinkId {
    if (auto renderer = [self findRenderer:std::string([sinkId UTF8String])]) {
        renderer->setHasListeners(hasListeners);
    }
}

- (void)writeOutgoingFrameWithBuffer:(CVImageBufferRef)image
                               angle:(int)angle
                        videoInputId:(NSString*)videoInputId
{
    auto frame = getNewFrame(std::string([videoInputId UTF8String]));
    if(!frame) {
        return;
    }
    auto avframe = frame->pointer();
        [MediaUtils configureFrame:(AVFrame*)avframe
              fromImageBuffer:image
                        angle:(int) angle];

    publishFrame(std::string([videoInputId UTF8String]));
}

- (void)addVideoDeviceWithName:(NSString*)deviceName withDevInfo:(NSDictionary*)deviceInfoDict {
    std::vector<std::map<std::string, std::string>> devInfo;
    auto setting = [Utils dictionaryToMap:deviceInfoDict];
    devInfo.emplace_back(setting);
    addVideoDevice(std::string([deviceName UTF8String]), devInfo);
}

- (void)setDefaultDevice:(NSString*)deviceName {
    setDefaultDevice(std::string([deviceName UTF8String]));
}
- (NSString*)getDefaultDevice {
    return @(getDefaultDevice().c_str());
}

- (void)setDecodingAccelerated:(BOOL)state {
    setDecodingAccelerated(state);
}

- (BOOL)getDecodingAccelerated {
    return getDecodingAccelerated();
}

- (void)setEncodingAccelerated:(BOOL)state {
    setEncodingAccelerated(state);
}

- (BOOL)getEncodingAccelerated {
    return getEncodingAccelerated();
}

- (void)stopAudioDevice {
    stopAudioDevice();
}

- (NSString*)startLocalRecording:(NSString*)videoInputId path:(NSString*)path {
    return @(startLocalMediaRecorder(std::string([videoInputId UTF8String]), std::string([path UTF8String])).c_str());
}

- (void)stopLocalRecording:(NSString*) path {
    stopLocalRecorder(std::string([path UTF8String]));
}
- (NSString*)createMediaPlayer:(NSString*)path {
    return @(createMediaPlayer(std::string([path UTF8String])).c_str());
}

-(bool)pausePlayer:(NSString*)playerId pause:(BOOL)pause {
    return pausePlayer(std::string([playerId UTF8String]), pause);
}

-(bool)closePlayer:(NSString*)playerId {
    return closeMediaPlayer(std::string([playerId UTF8String]));
}

- (bool)mutePlayerAudio:(NSString*)playerId mute:(BOOL)mute {
    return mutePlayerAudio(std::string([playerId UTF8String]), mute);

}
- (bool)playerSeekToTime:(int)time playerId:(NSString*)playerId {
    return playerSeekToTime(std::string([playerId UTF8String]), time);
}

-(int64_t)getPlayerPosition:(NSString*)playerId {
    return getPlayerPosition(std::string([playerId UTF8String]));
}

- (void)openVideoInput:(NSString*)path {
    openVideoInput(std::string([path UTF8String]));
}

- (void)closeVideoInput:(NSString*)path {
    closeVideoInput(std::string([path UTF8String]));
}

#pragma mark VideoAdapterDelegate

+ (id <VideoAdapterDelegate>)videoDelegate {
    return _videoDelegate;
}

+ (void) setVideoDelegate:(id<VideoAdapterDelegate>)videoDelegate {
    _videoDelegate = videoDelegate;
}

#pragma mark DecodingAdapterDelegate

+ (id <DecodingAdapterDelegate>)decodingDelegate {
    return _decodingDelegate;
}

+ (void) setDecodingDelegate:(id<DecodingAdapterDelegate>)decodingDelegate {
    _decodingDelegate = decodingDelegate;
}

#pragma mark -

@end
