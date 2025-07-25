//
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

#import "MediaUtils.h"

#import <Foundation/Foundation.h>

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/display.h>
#include <libavutil/time.h>
}

@implementation MediaUtils

+(UIImageOrientation)uimageOrientationFromRotation:(double)rotation {
    UIImageOrientation orientation = UIImageOrientationUp;
    switch ((int)rotation) {
        case 90:
            orientation = UIImageOrientationRight;
            break;
        case 270:
        case -90:
            orientation = UIImageOrientationLeft;
            break;
        case -180:
            orientation = UIImageOrientationDown;
        default:
            orientation = UIImageOrientationUp;
            break;
    }
    return orientation;
}
+(CGImagePropertyOrientation)ciimageOrientationFromRotation:(double)rotation {
    CGImagePropertyOrientation orientation = kCGImagePropertyOrientationUp;
    switch ((int)rotation) {
        case 90:
            orientation = kCGImagePropertyOrientationRight;
            break;
        case 270:
        case -90:
            orientation = kCGImagePropertyOrientationLeft;
            break;
        case -180:
            orientation = kCGImagePropertyOrientationDown;
            break;
        default:
            orientation = kCGImagePropertyOrientationUp;
            break;
    }
    return orientation;
}

+(PixelBufferInfo)getCVPixelBufferFromAVFrame:(const AVFrame *)frame {
    PixelBufferInfo info;
    info.rotation = 0;

    if ((CVPixelBufferRef)frame->data[3]) {
        info.pixelBuffer = (CVPixelBufferRef)frame->data[3];
        info.ownsMemory = false;
    } else {
        info.pixelBuffer = [MediaUtils converCVPixelBufferRefFromAVFrame: frame];
        info.ownsMemory = true;
    }

    if (auto matrix = av_frame_get_side_data(frame, AV_FRAME_DATA_DISPLAYMATRIX)) {
        const int32_t* data = reinterpret_cast<int32_t*>(matrix->data);
        info.rotation = av_display_rotation_get(data);
    }
    return info;
}

+(CVPixelBufferRef)converCVPixelBufferRefFromAVFrame:(const AVFrame *)frame {
    if (!frame || !frame->data[0]) {
        return NULL;
    }
    if ((AVPixelFormat)frame->format != AV_PIX_FMT_YUV420P &&
        (AVPixelFormat)frame->format != AV_PIX_FMT_NV12) {
        return NULL;
    }

    CVPixelBufferRef pixelBuffer = NULL;

    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             @(frame->linesize[0]), kCVPixelBufferBytesPerRowAlignmentKey,
                             [NSDictionary dictionary], kCVPixelBufferIOSurfacePropertiesKey,
                             nil];
    int ret = CVPixelBufferCreate(kCFAllocatorDefault,
                                  frame->width,
                                  frame->height,
                                  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                  (__bridge CFDictionaryRef)(options),
                                  &pixelBuffer);

    if (ret < 0) {
        return nil;
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    uint8_t*  base = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
    if (bytePerRowY == frame->linesize[0]) {
        memcpy(base, frame->data[0], bytePerRowY * frame->height);
    } else {
        [MediaUtils copyLineByLineSrc: frame->data[0]
                          toDest: base
                     srcLinesize: frame->linesize[0]
                    destLinesize: bytePerRowY
                          height: frame->height];
    }
    if ((AVPixelFormat)frame->format == AV_PIX_FMT_NV12) {
        base = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
        if (bytesPerRowUV == frame->linesize[0]) {
            memcpy(base, frame->data[1], bytesPerRowUV * frame->height/2);
        } else {
            [MediaUtils copyLineByLineSrc: frame->data[1]
                              toDest: base
                         srcLinesize: frame->linesize[0]
                        destLinesize: bytesPerRowUV
                              height: frame->height/2];
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return pixelBuffer;
    }
    base = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
    // pixelbuffer does not have a padding
    if (bytesPerRowUV == frame->linesize[1] * 2) {
        for(size_t i = 0; i < frame->height / 2 * bytesPerRowUV / 2; i++ ) {
            *base++ = frame->data[1][i];
            *base++ = frame->data[2][i];
        }
    } else {
        uint32_t size = frame->linesize[1] * frame->height / 2;
        uint8_t* dstData = new uint8_t[2 * size];
        for (int i = 0; i < 2 * size; i++){
            if (i % 2 == 0){
                dstData[i] = frame->data[1][i/2];
            }else {
                dstData[i] = frame->data[2][i/2];
            }
        }
        [MediaUtils copyLineByLineSrc: dstData
                          toDest: base
                     srcLinesize: frame->linesize[1] * 2
                    destLinesize: bytesPerRowUV
                          height: frame->height/2];
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        free(dstData);
        return pixelBuffer;
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return pixelBuffer;
}

+ (void)copyLineByLineSrc:(uint8_t*)src
                   toDest:(uint8_t*)dest
              srcLinesize:(size_t)srcLinesize
             destLinesize:(size_t)destLinesize
                   height:(size_t)height {
    for (size_t i = 0; i < height ; i++) {
        memcpy(dest, src, srcLinesize);
        dest = dest + destLinesize;
        src = src + srcLinesize;
    }
}

+ (AVFrame*)configureHardwareDecodedFrame:(AVFrame*)frame
                          fromImageBuffer:(CVImageBufferRef)image
                                    angle:(int)angle {
    CVPixelBufferLockBaseAddress(image,0);
    size_t width = CVPixelBufferGetWidth(image);
    size_t height = CVPixelBufferGetHeight(image);
    CVPixelBufferUnlockBaseAddress(image,0);
    frame->data[3] = (uint8_t *)image;
    frame->format = AV_PIX_FMT_VIDEOTOOLBOX;
    frame->width = static_cast<int>(width);
    frame->height = static_cast<int>(height);
    AVBufferRef* localFrameDataBuffer = angle == 0 ? nullptr : av_buffer_alloc(sizeof(int32_t) * 9);
    if (!localFrameDataBuffer) {
        return frame;
    }
    av_display_rotation_set(reinterpret_cast<int32_t*>(localFrameDataBuffer->data), angle);
    av_frame_new_side_data_from_buf(frame, AV_FRAME_DATA_DISPLAYMATRIX, localFrameDataBuffer);
    return frame;
}

+ (int)getForrmatFromAppleFormat:(OSType)format {
    switch (format) {
        case kCVPixelFormatType_420YpCbCr8Planar:
            return AV_PIX_FMT_YUV420P;
        case kCVPixelFormatType_422YpCbCr8_yuvs:
            return AV_PIX_FMT_YUYV422;
        case kCVPixelFormatType_422YpCbCr8:
            return AV_PIX_FMT_UYVY422;
        case kCVPixelFormatType_32BGRA:
            return AV_PIX_FMT_BGR0;
        case kCVPixelFormatType_24RGB:
            return AV_PIX_FMT_RGB24;
        case kCVPixelFormatType_24BGR:
            return AV_PIX_FMT_BGR24;
        case kCVPixelFormatType_32ARGB:
            return AV_PIX_FMT_0RGB;
        case kCVPixelFormatType_32ABGR:
            return AV_PIX_FMT_0BGR;
        case kCVPixelFormatType_32RGBA:
            return AV_PIX_FMT_RGB0;
        case kCVPixelFormatType_48RGB:
            return AV_PIX_FMT_BGR48BE;
        case kCVPixelFormatType_444YpCbCr8:
            return AV_PIX_FMT_YUV444P;
        case kCVPixelFormatType_4444AYpCbCr16:
            return AV_PIX_FMT_YUVA444P16LE;
        case kCVPixelFormatType_4444YpCbCrA8R:
            return AV_PIX_FMT_YUVA444P;
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
        default:
            return AV_PIX_FMT_NV12;
    }
}

+ (AVFrame*)configureFrame:(AVFrame*)frame
           fromImageBuffer: (CVImageBufferRef)image
                     angle:(int) angle {
    CVPixelBufferLockBaseAddress(image, 0);
    int width = static_cast<int>(CVPixelBufferGetWidth(image));
    int height = static_cast<int>(CVPixelBufferGetHeight(image));
    const OSType pixelFormat = CVPixelBufferGetPixelFormatType(image);
    frame->width = width;
    frame->height = height;
    frame->format = [MediaUtils getForrmatFromAppleFormat: pixelFormat];
    if (CVPixelBufferIsPlanar(image)) {
        int planes = static_cast<int>(CVPixelBufferGetPlaneCount(image));
        for (int i = 0; i < planes; i++) {
            frame->data[i] = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(image, i);
            frame->linesize[i] = static_cast<int>(CVPixelBufferGetBytesPerRowOfPlane(image, i));
        }
    } else {
        frame->data[0] = (uint8_t *)CVPixelBufferGetBaseAddress(image);
        frame->linesize[0] = static_cast<int>(CVPixelBufferGetBytesPerRow(image));
    }
    CVPixelBufferUnlockBaseAddress(image, 0);
    AVBufferRef* localFrameDataBuffer = angle == 0 ? nullptr : av_buffer_alloc(sizeof(int32_t) * 9);
    if (!localFrameDataBuffer) {
        return frame;
    }
    av_display_rotation_set(reinterpret_cast<int32_t*>(localFrameDataBuffer->data), angle);
    av_frame_new_side_data_from_buf(frame, AV_FRAME_DATA_DISPLAYMATRIX, localFrameDataBuffer);
    return frame;
}

@end
