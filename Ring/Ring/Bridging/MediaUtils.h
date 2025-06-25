/*
 *  Copyright (C) 2016-2025 Savoir-faire Linux Inc.
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
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
 * USA.
 */

struct AVFrame;

typedef struct {
    CVPixelBufferRef pixelBuffer;
    int rotation;
    bool ownsMemory;
} PixelBufferInfo;

@interface MediaUtils : NSObject

+(PixelBufferInfo)getCVPixelBufferFromAVFrame:(const AVFrame *)frame;
+ (AVFrame*)configureHardwareDecodedFrame:(AVFrame*)frame
                          fromImageBuffer: (CVImageBufferRef)image
                                    angle:(int) angle;
+ (AVFrame*)configureFrame:(AVFrame*)frame
           fromImageBuffer: (CVImageBufferRef)image
                     angle:(int)angle;
+(UIImageOrientation)uimageOrientationFromRotation:(double)rotation;
+(CGImagePropertyOrientation)ciimageOrientationFromRotation:(double)rotation;
@end
