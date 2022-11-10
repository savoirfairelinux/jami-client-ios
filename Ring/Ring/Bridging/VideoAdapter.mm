/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

#import "VideoAdapter.h"
#import "Utils.h"
#import "jami/videomanager_interface.h"
#import "jami/callmanager_interface.h"
#import "Ring-Swift.h"
#include <pthread.h>
#include <functional>
#include <AVFoundation/AVFoundation.h>
#include <mutex>
#import "Utils.h"

using namespace libjami;

struct Renderer
{
    std::mutex frameMutex;
    std::condition_variable frameCv;
    bool isRendering;
    std::mutex renderMutex;
    SinkTarget target;
    int width;
    int height;
    NSString* rendererId;

    void bindAVSinkFunctions() {
        target.push = [this](FrameBuffer frame) {
            if(!VideoAdapter.videoDelegate) {
                return;
            }
            @autoreleasepool {
                UIImage *image = [Utils
                                  convertHardwareDecodedFrameToImage: std::move(frame.get())];
                isRendering = true;
                [VideoAdapter.videoDelegate writeFrameWithImage: image forCallId: rendererId];
                isRendering = false;
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
            NSString* rendererId = [NSString stringWithUTF8String:renderer_id.c_str()];
            [VideoAdapter.decodingDelegate decodingStartedWithRendererId:rendererId withWidth:(NSInteger)w withHeight:(NSInteger)h];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::DecodingStopped>([&](const std::string& renderer_id,
                                                                               const std::string& shm_path,
                                                                               bool is_mixer) {
        if(VideoAdapter.decodingDelegate) {
            NSString* rendererId = [NSString stringWithUTF8String:renderer_id.c_str()];
            [VideoAdapter.decodingDelegate decodingStoppedWithRendererId:rendererId];
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
            [VideoAdapter.videoDelegate stopCapture];
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
         withHeight:(NSInteger)h{
    auto _sinkId = std::string([sinkId UTF8String]);
    auto renderer = renderers.find(_sinkId);
    if (renderer != renderers.end()) {
        renderer->second->width = static_cast<int>(w);
        renderer->second->height = static_cast<int>(h);
        return;
    }
    auto newRenderer = std::make_shared<Renderer>();
    newRenderer->width = static_cast<int>(w);
    newRenderer->height = static_cast<int>(h);
    newRenderer->rendererId = sinkId;
    newRenderer->bindAVSinkFunctions();
    registerSinkTarget(_sinkId, newRenderer->target);
    renderers.insert(std::make_pair(_sinkId, newRenderer));
}

- (void)removeSinkTargetWithSinkId:(NSString*)sinkId {
    auto renderer = renderers.find(std::string([sinkId UTF8String]));
    if (renderer != renderers.end()) {
        std::unique_lock<std::mutex> lk(renderer->second->renderMutex);
        renderer->second->frameCv.wait(lk, [=] {
            return !renderer->second->isRendering;
        });
        renderers.erase(renderer);
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
        [Utils configureFrame:(AVFrame*)avframe
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

- (void)switchInput:(NSString*)videoInputId accountId:(NSString*)accountId forCall:(NSString*)callID {
    switchInput(std::string([accountId UTF8String]), std::string([callID UTF8String]), std::string([videoInputId UTF8String]));
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
