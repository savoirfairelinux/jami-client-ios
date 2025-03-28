/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import Foundation
import RxSwift

struct VideoFrameInfo {
    let sampleBuffer: CMSampleBuffer?
    let rotation: Int
    let sinkId: String
}

class VideoInputsManager {

    var listeners = [String: Int]()

    var frameSubject = PublishSubject<VideoFrameInfo>()

    func stop(sinkId: String) {
        let frameInfo = VideoFrameInfo(sampleBuffer: nil, rotation: 0, sinkId: sinkId)
        frameSubject.onNext(frameInfo)
    }

    func addListener(sinkId: String) {
        if let count = listeners[sinkId] {
            listeners[sinkId] = count + 1
        } else {
            listeners[sinkId] = 1
        }
    }

    func removeListener(sinkId: String) {
        if let count = listeners[sinkId] {
            if count > 1 {
                listeners[sinkId] = count - 1
            } else {
                listeners.removeValue(forKey: sinkId)
            }
        }
    }

    func hasListener(sinkId: String) -> Bool {
        return listeners[sinkId] != nil
    }

    func writeFrame(withBuffer buffer: CVPixelBuffer?, sinkId: String, rotation: Int) {
        guard let sampleBuffer = self.createSampleBufferFrom(pixelBuffer: buffer) else {
            print("VIDEO DEBUG: Failed to create sample buffer for sinkId: \(sinkId)")
            return 
        }
        self.setSampleBufferAttachments(sampleBuffer)
        let frameInfo = VideoFrameInfo(sampleBuffer: sampleBuffer, rotation: rotation, sinkId: sinkId)
        frameSubject.onNext(frameInfo)
    }

    func createSampleBufferFrom(pixelBuffer: CVPixelBuffer?) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?

        var timimgInfo = CMSampleTimingInfo()
        var formatDescription: CMFormatDescription?
        guard let pixelBuffer = pixelBuffer else { return nil }
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)

        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription!,
            sampleTiming: &timimgInfo,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }

    func setSampleBufferAttachments(_ sampleBuffer: CMSampleBuffer) {
        guard let attachments: CFArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) else { return }
        let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                       to: CFMutableDictionary.self)
        let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()
        let value = Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        CFDictionarySetValue(dictionary, key, value)
    }
}
