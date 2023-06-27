//
//  SinksContainer.swift
//  Ring
//
//  Created by kateryna on 2023-05-18.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

// VideoInputsManager: Manages synchronous access to videoInputs
actor VideoInputsManager {
    private var videoInputs: [String: VideoInput] = [:]

    func addVideoInput(videoInput: VideoInput, renderId: String) {
        videoInputs[renderId] = videoInput
    }

    func videoInputCouldBeAdded(renderId: String) -> Bool {
        /*
         To determine if a video input can be added:
         1. If videoInputs is empty, it is a simple call, and the video input could be added.
         2. If not, to avoid adding video input for mixed renderId during the conference,
         we check if renderId contains "video_0".
         */
        return videoInputs.isEmpty || (renderId.contains("video_0"))
    }

    func removeVideoInput(renderId: String) -> Bool {
        if let videoInput = videoInputs.removeValue(forKey: renderId) {
            videoInput.stop()
            return true
        }
        return false
    }

    func getVideoInput(renderId: String) -> VideoInput? {
        return videoInputs[renderId]
    }
}

class VideoInput: VideoInputDelegate {

    let renderId: String
    var frame = PublishSubject<(CMSampleBuffer?, Int)>()
    var width: Int
    var height: Int

    init(renderId: String, width: Int, height: Int) {
        self.renderId = renderId
        self.width = width
        self.height = height
        print("^^^^^^^^^^ init video input \(renderId)")
    }

    deinit {
        print("^^^^^^^^^^ deinit video input \(renderId)")
    }

    func stop() {
        self.frame.onNext((nil, 0))
    }

    func writeFrame(withBuffer buffer: CVPixelBuffer?, renderId: String, rotation: Int) {
        guard let sampleBuffer = self.createSampleBufferFrom(pixelBuffer: buffer) else {
            return }
        self.setSampleBufferAttachments(sampleBuffer)
        self.frame.onNext((sampleBuffer, rotation))
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
