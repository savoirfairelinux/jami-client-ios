/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import XCTest
import CoreMedia
import CoreVideo

func makeCaptureSampleBuffer(width: Int = 16, height: Int = 16) throws -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                     kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    XCTAssertEqual(status, kCVReturnSuccess)
    let buffer = try XCTUnwrap(pixelBuffer)

    var formatDescription: CMFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, buffer,
                                                 &formatDescription)
    let format = try XCTUnwrap(formatDescription)

    var timingInfo = CMSampleTimingInfo(
        duration: CMTimeMake(1, 30),
        presentationTimeStamp: CMTimeMake(123_456_789, 1_000_000_000),
        decodeTimeStamp: kCMTimeInvalid)
    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, buffer, format,
                                             &timingInfo, &sampleBuffer)
    return try XCTUnwrap(sampleBuffer)
}

func sampleBufferDisplaysImmediately(_ sampleBuffer: CMSampleBuffer) -> Bool {
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false),
          CFArrayGetCount(attachments) > 0 else {
        return false
    }
    let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                   to: CFDictionary.self)
    let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()
    guard let value = CFDictionaryGetValue(dictionary, key) else { return false }
    return CFBooleanGetValue(unsafeBitCast(value, to: CFBoolean.self))
}
