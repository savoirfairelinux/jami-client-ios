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
#import "dring/videomanager_interface.h"
#import "dring/callmanager_interface.h"
#import "Ring-Swift.h"
#include <pthread.h>
#include <functional>
#include <AVFoundation/AVFoundation.h>
#include <mutex>
#import "Utils.h"

using namespace DRing;

struct Renderer
{
    std::mutex frameMutex;
    std::condition_variable frameCv;
    bool isRendering;
    std::mutex renderMutex;
    AVSinkTarget avtarget;
    SinkTarget target;
    SinkTarget::FrameBufferPtr daemonFramePtr_;
    int width;
    int height;
    NSString* rendererId;

    void bindAVSinkFunctions() {
        avtarget.push = [this](std::unique_ptr<DRing::VideoFrame> frame) {
            if(!VideoAdapter.delegate) {
                return;
            }
            @autoreleasepool {
                UIImage *image = [Utils
                                  convertHardwareDecodedFrameToImage: std::move(frame->pointer())];
                isRendering = true;
                [VideoAdapter.delegate writeFrameWithImage: image forCallId: rendererId];
                isRendering = false;
            }
        };
    }
    void bindSinkFunctions() {
        target.pull = [this](std::size_t bytes) {
            std::lock_guard<std::mutex> lk(renderMutex);
            if (!daemonFramePtr_)
                daemonFramePtr_.reset(new DRing::FrameBuffer);
            daemonFramePtr_->storage.resize(bytes);
            daemonFramePtr_->ptr = daemonFramePtr_->storage.data();
            daemonFramePtr_->ptrSize = bytes;
            return std::move(daemonFramePtr_);
        };

        target.push = [this](DRing::SinkTarget::FrameBufferPtr buf) {
            std::lock_guard<std::mutex> lk(renderMutex);
            daemonFramePtr_ = std::move(buf);
            if(VideoAdapter.delegate) {
                @autoreleasepool {
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    CGContextRef bitmapContext = CGBitmapContextCreate((void *)daemonFramePtr_->ptr,
                                                                       daemonFramePtr_->width,
                                                                       daemonFramePtr_->height,
                                                                       8,
                                                                       4 * width,
                                                                       colorSpace,
                                                                       kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
                    CFRelease(colorSpace);
                    CGImageRef cgImage=CGBitmapContextCreateImage(bitmapContext);
                    CGContextRelease(bitmapContext);
                    UIImage* image = [UIImage imageWithCGImage:cgImage];
                    CGImageRelease(cgImage);
                    isRendering = true;
                    [VideoAdapter.delegate writeFrameWithImage: image forCallId: rendererId];
                    isRendering = false;
                }
            }

        };
    }
};

@implementation VideoAdapter {
    std::map<std::string, std::shared_ptr<Renderer>> renderers;
}

// Static delegate that will receive the propagated daemon events
static id <VideoAdapterDelegate> _delegate;

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
        if(VideoAdapter.delegate) {
            NSString* rendererId = [NSString stringWithUTF8String:renderer_id.c_str()];
            NSString* codecName = @"";
            std::map<std::string, std::string> callDetails = getCallDetails(renderer_id);
            if (callDetails.find("VIDEO_CODEC") != callDetails.end()) {
                codecName = [NSString stringWithUTF8String: callDetails["VIDEO_CODEC"].c_str()];
            }
            [VideoAdapter.delegate decodingStartedWithRendererId:rendererId withWidth:(NSInteger)w withHeight:(NSInteger)h withCodec: codecName];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::DecodingStopped>([&](const std::string& renderer_id,
                                                                               const std::string& shm_path,
                                                                               bool is_mixer) {
        if(VideoAdapter.delegate) {
            NSString* rendererId = [NSString stringWithUTF8String:renderer_id.c_str()];
            [VideoAdapter.delegate decodingStoppedWithRendererId:rendererId];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StartCapture>([&](const std::string& device) {
        if(VideoAdapter.delegate) {
            NSString* deviceString = [NSString stringWithUTF8String:device.c_str()];
            [VideoAdapter.delegate startCaptureWithDevice:deviceString];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StopCapture>([&]() {
        if(VideoAdapter.delegate) {
            [VideoAdapter.delegate stopCapture];
        }
    }));

    videoHandlers.insert(exportable_callback<MediaPlayerSignal::FileOpened>([&](const std::string& playerId, std::map<std::string, std::string> playerInfo) {
        if(VideoAdapter.delegate) {
            NSString* player = @(playerId.c_str());
            NSMutableDictionary* info = [Utils mapToDictionnary:playerInfo];
            [VideoAdapter.delegate fileOpenedFor:player fileInfo:info];
        }
    }));

    registerSignalHandlers(videoHandlers);
}

#pragma mark -

- (void)registerSinkTargetWithSinkId:sinkId
          withWidth:(NSInteger)w
         withHeight:(NSInteger)h
withHardwareSupport:(BOOL)hardwareSupport {
    auto _sinkId = std::string([sinkId UTF8String]);
    auto renderer = std::make_shared<Renderer>();
    renderer->width = static_cast<int>(w);
    renderer->height = static_cast<int>(h);
    renderer->rendererId = sinkId;
    if(self.getDecodingAccelerated && hardwareSupport) {
        renderer->bindAVSinkFunctions();
        DRing::registerAVSinkTarget(_sinkId, renderer->avtarget);
    } else {
        renderer->bindSinkFunctions();
        DRing::registerSinkTarget(_sinkId, renderer->target);
    }
    renderers.insert(std::make_pair(_sinkId, renderer));
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
             useHardwareAcceleration:(BOOL)hardwareAccelerated
                           recording:(BOOL)recording {
    auto frame = DRing::getNewFrame();
    if(!frame) {
        return;
    }
    auto avframe = frame->pointer();
    if(hardwareAccelerated && !recording) {
        [Utils configureHardwareDecodedFrame:(AVFrame*)avframe
                             fromImageBuffer:image
                                       angle:(int) angle];
    } else {
        [Utils configureFrame:(AVFrame*)avframe
              fromImageBuffer:image
                        angle:(int) angle];

    }
    DRing::publishFrame();
}

- (void)addVideoDeviceWithName:(NSString*)deviceName withDevInfo:(NSDictionary*)deviceInfoDict {
    std::vector<std::map<std::string, std::string>> devInfo;
    auto setting = [Utils dictionnaryToMap:deviceInfoDict];
    devInfo.emplace_back(setting);
    DRing::addVideoDevice(std::string([deviceName UTF8String]), devInfo);
    DRing::setDefaultDevice(std::string([deviceName UTF8String]));
}

- (void)setDefaultDevice:(NSString*)deviceName {
    DRing::setDefaultDevice(std::string([deviceName UTF8String]));
}

- (void)setDecodingAccelerated:(BOOL)state {
    DRing::setDecodingAccelerated(state);
}

- (BOOL)getDecodingAccelerated {
    return DRing::getDecodingAccelerated();
}

- (void)setEncodingAccelerated:(BOOL)state {
    DRing::setEncodingAccelerated(state);
}

- (BOOL)getEncodingAccelerated {
    return DRing::getEncodingAccelerated();
}

- (void)switchInput:(NSString*)deviceName {
    DRing::switchInput(std::string([deviceName UTF8String]));
}

- (void)switchInput:(NSString*)deviceName forCall:(NSString*) callID {
    DRing::switchInput(std::string([callID UTF8String]), std::string([deviceName UTF8String]));
}

- (void)stopAudioDevice {
    DRing::stopAudioDevice();
}

- (NSString* )startLocalRecording:(NSString*) path audioOnly:(BOOL)audioOnly {
    return @(DRing::startLocalRecorder(audioOnly, std::string([path UTF8String])).c_str());
}

- (void)stopLocalRecording:(NSString*) path {
    DRing::stopLocalRecorder(std::string([path UTF8String]));
}
- (NSString*)createMediaPlayer:(NSString*)path {
    return @(DRing::createMediaPlayer(std::string([path UTF8String])).c_str());
}

-(bool)pausePlayer:(NSString*)playerId pause:(BOOL)pause {
    return DRing::pausePlayer(std::string([playerId UTF8String]), pause);
}

- (bool)closePlayer:(NSString*)playerId {
    return DRing::closePlayer(std::string([playerId UTF8String]));
}

- (bool)mutePlayerAudio:(NSString*)playerId mute:(BOOL)mute {
    return DRing::mutePlayerAudio(std::string([playerId UTF8String]), mute);

}
- (bool)playerSeekToTime:(int)time playerId:(NSString*)playerId {
    return DRing::playerSeekToTime(std::string([playerId UTF8String]), time);
}

-(int64_t)getPlayerPosition:(NSString*)playerId {
    return DRing::getPlayerPosition(std::string([playerId UTF8String]));
}

- (void)startCamera {
    DRing::startCamera();
}

- (void)stopCamera {
    DRing::stopCamera();
}

#pragma mark PresenceAdapterDelegate

+ (id <VideoAdapterDelegate>)delegate {
    return _delegate;
}

+ (void) setDelegate:(id<VideoAdapterDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -

@end
