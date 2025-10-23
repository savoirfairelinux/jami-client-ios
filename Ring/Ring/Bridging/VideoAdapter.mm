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

#include <pthread.h>
#include <functional>
#include <mutex>
#include <atomic>

#import "jami/videomanager_interface.h"
#import "jami/callmanager_interface.h"

using namespace libjami;

struct Renderer
{
    std::condition_variable frameCv;
    std::atomic<bool> isRendering = {false};
    std::mutex renderMutex;
    SinkTarget target;
    int width;
    int height;
    bool hasListeners = false;
    NSString* sinkId;

    void bindAVSinkFunctions() {
        target.push = [this](FrameBuffer frame) {
            if(!VideoAdapter.videoDelegate || !hasListeners) {
                return;
            }
            @autoreleasepool {
                PixelBufferInfo info = [MediaUtils getCVPixelBufferFromAVFrame:std::move(frame.get())];
                if (info.pixelBuffer == NULL) {
                    return;
                }
                isRendering.store(true);
                [VideoAdapter.videoDelegate writeFrameWithBuffer: info.pixelBuffer sinkId: sinkId rotation: info.rotation];
                if (info.ownsMemory) {
                    CFRelease(info.pixelBuffer);
                }
                isRendering.store(false);
            }
        };
    }
};

@implementation VideoAdapter {
    std::map<std::string, std::shared_ptr<Renderer>> renderers;
}

// Static delegates that will receive the propagated daemon events
static id <VideoAdapterDelegate> _videoDelegate;
static id <DecodingAdapterDelegate> _decodingDelegate;

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

    videoHandlers.insert(exportable_callback<VideoSignal::DecodingStarted>([&](const std::string& renderer_id,
                                                                               const std::string& shm_path,
                                                                               int w,
                                                                               int h,
                                                                               bool is_mixer) {
        if(VideoAdapter.decodingDelegate) {
            NSString* sinkId = [NSString stringWithUTF8String:renderer_id.c_str()];
            [VideoAdapter.decodingDelegate decodingStartedWithSinkId:sinkId withWidth:(NSInteger)w withHeight:(NSInteger)h];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::DecodingStopped>([&](const std::string& renderer_id,
                                                                               const std::string& shm_path,
                                                                               bool is_mixer) {
        if(VideoAdapter.decodingDelegate) {
            NSString* sinkId = [NSString stringWithUTF8String:renderer_id.c_str()];
            [VideoAdapter.decodingDelegate decodingStoppedWithSinkId:sinkId];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StartCapture>([&](const std::string& device) {
        if(VideoAdapter.videoDelegate) {
            NSString* deviceString = [NSString stringWithUTF8String:device.c_str()];
            [VideoAdapter.videoDelegate startCaptureWithDevice:deviceString];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StopCapture>([&](const std::string& deviceId) {
        if(VideoAdapter.videoDelegate) {
            NSString* deviceString = @(deviceId.c_str());
            [VideoAdapter.videoDelegate stopCaptureWithDevice: deviceString];
        }
    }));

    videoHandlers.insert(exportable_callback<MediaPlayerSignal::FileOpened>([&](const std::string& playerId, std::map<std::string, std::string> playerInfo) {
        if(VideoAdapter.videoDelegate) {
            NSString* player = @(playerId.c_str());
            NSMutableDictionary* info = [Utils mapToDictionnary:playerInfo];
            [VideoAdapter.videoDelegate fileOpenedFor:player fileInfo:info];
        }
    }));

    registerSignalHandlers(videoHandlers);
}

#pragma mark -

-(CGSize)getRenderSize:(NSString* )sinkId {
    auto renderer = renderers.find(std::string([sinkId UTF8String]));
    if (renderer != renderers.end()) {
        std::unique_lock<std::mutex> lk(renderer->second->renderMutex);
        return CGSizeMake(renderer->second->width, renderer->second->height);
    }
    return CGSizeZero;
}

- (void)registerSinkTargetWithSinkId:sinkId
                           withWidth:(NSInteger)w
                          withHeight:(NSInteger)h
                         hasListeners:(BOOL)hasListeners {
    auto _sinkId = std::string([sinkId UTF8String]);
    auto renderer = renderers.find(_sinkId);
    if (renderer != renderers.end()) {
        renderer->second->width = static_cast<int>(w);
        renderer->second->height = static_cast<int>(h);
        renderer->second->hasListeners = hasListeners;
        return;
    }
    auto newRenderer = std::make_shared<Renderer>();
    newRenderer->width = static_cast<int>(w);
    newRenderer->height = static_cast<int>(h);
    newRenderer->sinkId = sinkId;
    newRenderer->hasListeners = hasListeners;
    newRenderer->bindAVSinkFunctions();
    registerSinkTarget(_sinkId, newRenderer->target);
    renderers.insert(std::make_pair(_sinkId, newRenderer));
}

- (void)removeSinkTargetWithSinkId:(NSString*)sinkId {
    auto renderer = renderers.find(std::string([sinkId UTF8String]));
    if (renderer != renderers.end()) {
        std::unique_lock<std::mutex> lk(renderer->second->renderMutex);
        renderer->second->frameCv.wait(lk, [=] {
            return !renderer->second->isRendering.load();
        });
        renderers.erase(renderer);
    }
}

- (void)setHasListeners:(BOOL)hasListeners forSinkId:(NSString*)sinkId {
    auto renderer = renderers.find(std::string([sinkId UTF8String]));
    if (renderer != renderers.end()) {
        renderer->second->hasListeners = hasListeners;
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
    auto setting = [Utils dictionnaryToMap:deviceInfoDict];
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

- (BOOL)requestMediaChange:(NSString*)callId accountId:(NSString*)accountId withMedia:(NSArray*)mediaList {
    requestMediaChange(std::string([accountId UTF8String]), std::string([callId UTF8String]), [Utils arrayOfDictionnarisToVectorOfMap: mediaList]);
    return false;
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
