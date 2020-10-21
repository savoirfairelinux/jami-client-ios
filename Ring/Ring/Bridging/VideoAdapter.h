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

#import <Foundation/Foundation.h>
#import <AVFoundation/AVCaptureOutput.h>
#import <AVFoundation/AVFoundation.h>

@protocol VideoAdapterDelegate;

@interface VideoAdapter : NSObject

@property (class, nonatomic, weak) id <VideoAdapterDelegate> delegate;

- (void)addVideoDeviceWithName:(NSString*)deviceName withDevInfo:(NSDictionary*)deviceInfoDict;
- (void)setDefaultDevice:(NSString*)deviceName;
- (NSString*)getDefaultDevice;
- (void)registerSinkTargetWithSinkId:sinkId
                           withWidth:(NSInteger)w
                          withHeight:(NSInteger)h;
- (void)removeSinkTargetWithSinkId:(NSString*)sinkId;
- (void)writeOutgoingFrameWithBuffer:(CVImageBufferRef)image
                               angle:(int)angle;
- (void)setDecodingAccelerated:(BOOL)state;
- (BOOL)getDecodingAccelerated;
- (void)switchInput:(NSString*)deviceName;
- (void)switchInput:(NSString*)deviceName forCall:(NSString*) callID;
- (void)setEncodingAccelerated:(BOOL)state;
- (BOOL)getEncodingAccelerated;
- (void)stopAudioDevice;
- (NSString*)startLocalRecording:(NSString*) path audioOnly:(BOOL)audioOnly;
- (void)stopLocalRecording:(NSString*) path;
- (void)startCamera;
- (void)stopCamera;
- (NSString*)createMediaPlayer:(NSString*)path;
- (bool)pausePlayer:(NSString*)playerId pause:(BOOL)pause;
- (bool)closePlayer:(NSString*)playerId;
- (bool)mutePlayerAudio:(NSString*)playerId mute:(BOOL)mute;
- (bool)playerSeekToTime:(int)time playerId:(NSString*)playerId;
- (int64_t)getPlayerPosition:(NSString*)playerId;
-(CGSize)getRenderSize:(NSString* )sinkId;

@end
