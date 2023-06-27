//
//  SinksContainer.swift
//  Ring
//
//  Created by kateryna on 2023-05-18.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

class VideoInput: VideoInputDelegate {

    let renderId: String
    var frame = PublishSubject<CMSampleBuffer?>()
    var width: Int
    var height: Int

    init(renderId: String, width: Int, height: Int) {
        self.renderId = renderId
        self.width = width
        self.height = height
    }

    func stop() {
        self.frame.onNext(nil)
    }

    func writeFrame(withBuffer buffer: CVPixelBuffer?, forCallId: String) {
        guard let sampleBuffer = self.createSampleBufferFrom(pixelBuffer: buffer) else {
            return }
        self.setSampleBufferAttachments(sampleBuffer)
        self.frame.onNext(sampleBuffer)
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
