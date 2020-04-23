/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

#import "Utils.h"
extern "C" {
    #include <libavutil/frame.h>
    #include <libavutil/display.h>
    #include <libavutil/time.h>
}

@implementation Utils

+ (NSArray*)vectorToArray:(const std::vector<std::string>&)vector {
  NSMutableArray* resArray = [NSMutableArray new];
  std::for_each(vector.begin(), vector.end(), ^(std::string str) {
    id nsstr = [NSString stringWithUTF8String:str.c_str()];
    [resArray addObject:nsstr];
  });
  return resArray;
}

+ (NSMutableDictionary*)mapToDictionnary:
    (const std::map<std::string, std::string>&)map {
  NSMutableDictionary* resDictionnary = [NSMutableDictionary new];

  std::for_each(
      map.begin(), map.end(), ^(std::pair<std::string, std::string> keyValue) {
        id key = [NSString stringWithUTF8String:keyValue.first.c_str()];
        id value = [NSString stringWithUTF8String:keyValue.second.c_str()];
        [resDictionnary setObject:value forKey:key];
      });

  return resDictionnary;
}

+ (std::map<std::string, std::string>)dictionnaryToMap:(NSDictionary*)dict {
  std::map<std::string, std::string> resMap;
  for (id key in dict)
    resMap.insert(std::pair<std::string, std::string>(
        std::string([key UTF8String]),
        std::string([[dict objectForKey:key] UTF8String])));
  return resMap;
}

+ (std::vector<std::map<std::string, std::string>>)arrayOfDictionnarisToVectorOfMap:(NSArray*)dictionaries {
    std::vector<std::map<std::string, std::string>> resVector;
    for (NSDictionary* dictionary in dictionaries) {
        std::map<std::string, std::string> resMap;
        for (id key in dictionary) {
            resMap.insert(std::pair<std::string,
                          std::string>(
                                       std::string([key UTF8String]),
                                       std::string([[dictionary objectForKey:key] UTF8String])));
        }
        resVector.push_back(resMap);
    }
    return resVector;
}

+ (NSArray*)vectorOfMapsToArray:
(const std::vector<std::map<std::string, std::string>>&)vectorOfMaps {
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:vectorOfMaps.size()];

    std::for_each(
                  vectorOfMaps.begin(), vectorOfMaps.end(), ^(std::map<std::string, std::string> map) {
                      NSDictionary *dictionary = [Utils mapToDictionnary:map];
                      [array addObject:dictionary];
                  });

    return [NSArray arrayWithArray:array];
}

+ (NSData*)dataFromVectorOfUInt8:(std::vector<uint8_t>)vectorOfUInt8 {

    NSMutableData* data = [[NSMutableData alloc] init];

    std::for_each(vectorOfUInt8.begin(), vectorOfUInt8.end(), ^(uint8_t byte) {
        [data appendBytes:&byte length:1];
    });

    return data;
}

+ (std::vector<uint8_t>)vectorOfUInt8FromData:(NSData*)data {

    std::vector<uint8_t> vector;
    char *bytes = (char*)data.bytes;

    for ( int i = 0; i < data.length; i++ ) {
        vector.push_back(bytes[i]);
    }
    return vector;
}

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

+ (UIImage*)convertHardwareDecodedFrameToImage:(const AVFrame*)frame {
    CIImage *image;
    if ((CVPixelBufferRef)frame->data[3]) {
        image = [CIImage imageWithCVPixelBuffer: (CVPixelBufferRef)frame->data[3]];
    } else {
        auto buffer = [Utils converCVPixelBufferRefFromAVFrame: frame];
        if (buffer == NULL) {
            return [[UIImage alloc] init];
        }
        image = [CIImage imageWithCVPixelBuffer: buffer];
        CFRelease(buffer);
    }
    if (!image) {
        return [[UIImage alloc] init];
    }
    if (auto matrix = av_frame_get_side_data(frame, AV_FRAME_DATA_DISPLAYMATRIX)) {
        const int32_t* data = reinterpret_cast<int32_t*>(matrix->data);
        auto rotation = av_display_rotation_get(data);
        auto uiImageOrientation = [Utils uimageOrientationFromRotation:rotation];
        auto ciImageOrientation = [Utils ciimageOrientationFromRotation:rotation];
        if (@available(iOS 11.0, *)) {
            image = [image imageByApplyingCGOrientation: ciImageOrientation];
        } else {
            image = [image imageByApplyingOrientation:static_cast<int>(ciImageOrientation)];
        }
        UIImage * imageUI = [UIImage imageWithCIImage:image scale:1 orientation: uiImageOrientation];
        return imageUI;
    }
    UIImage * imageUI = [UIImage imageWithCIImage:image];
    return imageUI;
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
        [Utils copyLineByLineSrc: frame->data[0]
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
            [Utils copyLineByLineSrc: frame->data[1]
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
        [Utils copyLineByLineSrc: dstData
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
    frame->format = [Utils getForrmatFromAppleFormat: pixelFormat];
    if (CVPixelBufferIsPlanar(image)) {
        int planes = static_cast<int>(CVPixelBufferGetPlaneCount(image));
        for (int i = 0; i < planes; i++) {
            frame->data[i]     = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(image, i);
            frame->linesize[i] = static_cast<int>(CVPixelBufferGetBytesPerRowOfPlane(image, i));
        }
    } else {
        frame->data[0] = (uint8_t *)CVPixelBufferGetBaseAddress(image);
        frame->linesize[0] =static_cast<int>(CVPixelBufferGetBytesPerRow(image));
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
