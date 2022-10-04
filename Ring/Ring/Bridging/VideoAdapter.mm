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

using namespace DRing;

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
                //remove CVPixelBufferRef if CMSampleBufferRef is working
                CVPixelBufferRef buffer = nullptr;
                //CVPixelBufferRef buffer1 = nullptr;
                UIImage *image;
                if (@available(iOS 15.0, *)) {
                    buffer = [Utils getCVPixelBufferFromAVFrame:std::move(frame.get())];
 //                   buffer = [Utils converCVPixelBufferRefFromAVFrame:std::move(frame.get())];
//                    buffer1 = [Utils rotateBuffer:buffer];
                   // RotatePixelBufferToAngle(buffer, radians(90.0));
                }else {
                    image = [Utils convertHardwareDecodedFrameToImage: std::move(frame.get())];
                }
                isRendering = true;
                [VideoAdapter.videoDelegate writeFrameWithImage: image forCallId: rendererId forbuffer: buffer];
                isRendering = false;
            }
        };
    }
    
   /* static double radians (double degrees) {return degrees * M_PI/180;}

    static double ScalingFactorForAngle(double angle, CGSize originalSize) {
        double oriWidth = originalSize.height;
        double oriHeight = originalSize.width;
        double horizontalSpace = fabs( oriWidth*cos(angle) ) + fabs( oriHeight*sin(angle) );
        double scalingFactor = oriWidth / horizontalSpace ;
        return scalingFactor;
    }

    
    static inline void RotatePixelBufferToAngle(CVPixelBufferRef thePixelBuffer, double theAngle) {
        CIContext *context = nil;
        CGColorSpaceRef rgbColorSpace = NULL;
        CIImage *ci_originalImage = nil;
        CIImage *ci_transformedImage = nil;

        CIImage *ci_userTempImage = nil;

        @autoreleasepool {

            if (context==nil) {
                rgbColorSpace = CGColorSpaceCreateDeviceRGB();
                context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace: (__bridge id)rgbColorSpace,
                                                           kCIContextOutputColorSpace : (__bridge id)rgbColorSpace}];
            }

            long int w = CVPixelBufferGetWidth(thePixelBuffer);
            long int h = CVPixelBufferGetHeight(thePixelBuffer);

            ci_originalImage = [CIImage imageWithCVPixelBuffer:thePixelBuffer];
            ci_userTempImage = [ci_originalImage imageByApplyingTransform:CGAffineTransformMakeScale(0.6, 0.6)];
            //        CGImageRef UICG_image = [context createCGImage:ci_userTempImage fromRect:[ci_userTempImage extent]];

            double angle = theAngle;
            angle = angle+M_PI;
            double scalingFact = ScalingFactorForAngle(angle, CGSizeMake(w, h));


            CGAffineTransform transform =  CGAffineTransformMakeTranslation(w/2.0, h/2.0);
            transform = CGAffineTransformRotate(transform, angle);
            transform = CGAffineTransformTranslate(transform, -w/2.0, -h/2.0);

            //rotate it by applying a transform
            ci_transformedImage = [ci_originalImage imageByApplyingTransform:transform];

            CVPixelBufferLockBaseAddress(thePixelBuffer, 0);

            CGRect extentR = [ci_transformedImage extent];
            CGPoint centerP = CGPointMake(extentR.size.width/2.0+extentR.origin.x,
                                          extentR.size.height/2.0+extentR.origin.y);
            CGSize scaledSize = CGSizeMake(w*scalingFact, h*scalingFact);
            CGRect cropRect = CGRectMake(centerP.x-scaledSize.width/2.0, centerP.y-scaledSize.height/2.0,
                                         scaledSize.width, scaledSize.height);


            CGImageRef cg_img = [context createCGImage:ci_transformedImage fromRect:cropRect];
            ci_transformedImage = [CIImage imageWithCGImage:cg_img];

            ci_transformedImage = [ci_transformedImage imageByApplyingTransform:CGAffineTransformMakeScale(1.0/scalingFact, 1.0/scalingFact)];
            [context render:ci_transformedImage toCVPixelBuffer:thePixelBuffer bounds:CGRectMake(0, 0, w, h) colorSpace:NULL];

            CGImageRelease(cg_img);
            CVPixelBufferUnlockBaseAddress(thePixelBuffer, 0);

        }
    }*/
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
    DRing::registerSinkTarget(_sinkId, newRenderer->target);
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
    auto frame = DRing::getNewFrame(std::string([videoInputId UTF8String]));
    if(!frame) {
        return;
    }
    auto avframe = frame->pointer();
        [Utils configureFrame:(AVFrame*)avframe
              fromImageBuffer:image
                        angle:(int) angle];

    DRing::publishFrame(std::string([videoInputId UTF8String]));
}

- (void)addVideoDeviceWithName:(NSString*)deviceName withDevInfo:(NSDictionary*)deviceInfoDict {
    std::vector<std::map<std::string, std::string>> devInfo;
    auto setting = [Utils dictionnaryToMap:deviceInfoDict];
    devInfo.emplace_back(setting);
    DRing::addVideoDevice(std::string([deviceName UTF8String]), devInfo);
}

- (void)setDefaultDevice:(NSString*)deviceName {
    DRing::setDefaultDevice(std::string([deviceName UTF8String]));
}
- (NSString*)getDefaultDevice {
    return @(DRing::getDefaultDevice().c_str());
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

- (void)switchInput:(NSString*)videoInputId accountId:(NSString*)accountId forCall:(NSString*)callID {
    DRing::switchInput(std::string([accountId UTF8String]), std::string([callID UTF8String]), std::string([videoInputId UTF8String]));
}

- (void)stopAudioDevice {
    DRing::stopAudioDevice();
}

- (NSString*)startLocalRecording:(NSString*)videoInputId path:(NSString*)path {
    return @(DRing::startLocalMediaRecorder(std::string([videoInputId UTF8String]), std::string([path UTF8String])).c_str());
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

-(bool)closePlayer:(NSString*)playerId {
    return DRing::closeMediaPlayer(std::string([playerId UTF8String]));
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

- (void)openVideoInput:(NSString*)path {
    DRing::openVideoInput(std::string([path UTF8String]));
}

- (void)closeVideoInput:(NSString*)path {
    DRing::closeVideoInput(std::string([path UTF8String]));
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
