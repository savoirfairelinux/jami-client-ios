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

using namespace DRing;

@implementation VideoAdapter {
    // render
    pthread_mutex_t renderMutex;
    std::string rendererId;
    SinkTarget target;
    SinkTarget::FrameBufferPtr daemonFramePtr_;
    int width;
    int height;

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
            NSLog(@"VideoSignal::DecodingStarted id: %@, id: %i, id: %i", rendererId, w, h);
            [VideoAdapter.delegate decodingStartedWithRendererId:rendererId withWidth:(NSInteger)w withHeight:(NSInteger)h];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::DecodingStopped>([&](const std::string& renderer_id,
                                                                               const std::string& shm_path,
                                                                               bool is_mixer) {
        if(VideoAdapter.delegate) {
            NSString* rendererId = [NSString stringWithUTF8String:renderer_id.c_str()];
            NSLog(@"VideoSignal::DecodingStarted id: %@", rendererId);
            [VideoAdapter.delegate decodingStoppedWithRendererId:rendererId];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StartCapture>([&](const std::string& device) {
        if(VideoAdapter.delegate) {
            NSString* deviceString = [NSString stringWithUTF8String:device.c_str()];
            NSLog(@"VideoSignal::StopCapture device: %@", deviceString);
            [VideoAdapter.delegate startCaptureWithDevice:deviceString];
        }
    }));

    videoHandlers.insert(exportable_callback<VideoSignal::StopCapture>([&]() {
        if(VideoAdapter.delegate) {
            NSLog(@"VideoSignal::StopCapture");
            [VideoAdapter.delegate stopCapture];
        }
    }));

    registerVideoHandlers(videoHandlers);
}

#pragma mark -

- (void)onNewFrame {
}

- (void)bindSinkFunctions {
    using namespace std::placeholders;

    target.pull = [self](std::size_t bytes) {
        pthread_mutex_lock(&renderMutex);
        if (!daemonFramePtr_)
            daemonFramePtr_.reset(new DRing::FrameBuffer);
        daemonFramePtr_->storage.resize(bytes);
        daemonFramePtr_->ptr = daemonFramePtr_->storage.data();
        daemonFramePtr_->ptrSize = bytes;
        pthread_mutex_unlock(&renderMutex);
        return std::move(daemonFramePtr_);
    };

    target.push = [self](DRing::SinkTarget::FrameBufferPtr buf) {
        pthread_mutex_lock(&renderMutex);
        daemonFramePtr_ = std::move(buf);
        if(VideoAdapter.delegate) {
            NSString* rendererId = [NSString stringWithUTF8String:self->rendererId.c_str()];
            NSInteger bufferLength = (sizeof(buf->ptr)* buf->width * buf->height);
            NSData* data = [NSData dataWithBytesNoCopy:buf->ptr length:bufferLength];
            NSLog(@"WriteFrame buf: %lld", (long long)bufferLength);
            [VideoAdapter.delegate writeFrameWithRendererId:rendererId
                                                  withWidth:(NSInteger)buf->width
                                                 withHeight:(NSInteger)buf->height
                                                 withBuffer:data];
        }
        pthread_mutex_unlock(&renderMutex);
    };
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
