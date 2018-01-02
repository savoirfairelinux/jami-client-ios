/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
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
#import "Ring-Swift.h"
#include <pthread.h>
#include <functional>
#include <AVFoundation/AVFoundation.h>
#include <mutex>

using namespace DRing;

struct Renderer
{
    std::mutex frameMutex;
    std::condition_variable frameCv;
    bool isRendering;
    std::mutex renderMutex;
    SinkTarget target;
    SinkTarget::FrameBufferPtr daemonFramePtr_;
    int width;
    int height;

    void bindSinkFunctions() {
        target.pull = [this](std::size_t bytes) {
            std::lock_guard<std::mutex> lk(renderMutex);
            if (!daemonFramePtr_)
                daemonFramePtr_.reset(new DRing::FrameBuffer);
            daemonFramePtr_->storage.resize(bytes);
            daemonFramePtr_->ptr = daemonFramePtr_->storage.data();
            daemonFramePtr_->ptrSize = bytes;
            //NSLog(@"pull");
            return std::move(daemonFramePtr_);
        };

        target.push = [this](DRing::SinkTarget::FrameBufferPtr buf) {
            std::lock_guard<std::mutex> lk(renderMutex);
            daemonFramePtr_ = std::move(buf);
            if(VideoAdapter.delegate) {
                NSInteger width = daemonFramePtr_->width;
                NSInteger height = daemonFramePtr_->height;
                //NSInteger depth = sizeof(daemonFramePtr_->ptr);
                //NSInteger bufferLength = (width * height * depth);
                //NSLog(@"push: w:%ld, h:%ld, depth:%ld", (long)width, (long)height, (long)depth);
                @autoreleasepool {
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    CGContextRef bitmapContext = CGBitmapContextCreate((void *)daemonFramePtr_->ptr, width, height, 8, 4*width, colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
                    CFRelease(colorSpace);
                    CGImageRef cgImage=CGBitmapContextCreateImage(bitmapContext);
                    CGContextRelease(bitmapContext);
                    UIImage* image = [UIImage imageWithCGImage:cgImage];
                    CGImageRelease(cgImage);
                    isRendering = true;
                    [VideoAdapter.delegate writeFrameWithWidth:width withHeight:height withImage: image];
                    isRendering = false;
                }
            }

        };
    }
};

@implementation VideoAdapter {
    // render
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
            NSString* rendererId = [NSString stringWithUTF8String:renderer_id.c_str()];;
            [VideoAdapter.delegate decodingStartedWithRendererId:rendererId withWidth:(NSInteger)w withHeight:(NSInteger)h];
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

    registerVideoHandlers(videoHandlers);
}

#pragma mark -

- (void)registerSinkTargetWithSinkId:sinkId withWidth:(NSInteger)w withHeight:(NSInteger)h {
    auto _sinkId = std::string([sinkId UTF8String]);
    auto renderer = std::make_shared<Renderer>();
    renderer->width = static_cast<int>(w);
    renderer->height = static_cast<int>(h);
    renderer->bindSinkFunctions();
    DRing::registerSinkTarget(_sinkId, renderer->target);
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

- (void)addVideoDeviceWithName:(NSString*)deviceName withDevInfo:(NSDictionary*)deviceInfoDict {
    std::vector<std::map<std::string, std::string>> devInfo;
    auto setting = [Utils dictionnaryToMap:deviceInfoDict];
    devInfo.emplace_back(setting);
    DRing::addVideoDevice(std::string([deviceName UTF8String]), &devInfo);
    DRing::setDefaultDevice(std::string([deviceName UTF8String]));
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
