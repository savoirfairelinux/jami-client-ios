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
    var buffer = PublishSubject<CMSampleBuffer?>() // from iOS 15
    let frame = PublishSubject<UIImage?>() // prior to iOS 15
    let width: Int
    let height: Int

    init(renderId: String, width: Int, height: Int, videoAdapter: VideoAdapter) {
        self.renderId = renderId
        self.width = width
        self.height = height
        videoAdapter.registerSinkTarget(withSinkId: self.renderId, withWidth: self.width, withHeight: self.height, with: self)
    }

    func stop(videoAdapter: VideoAdapter) {
        self.buffer.onNext(nil)
        self.frame.onNext(nil)
        videoAdapter.removeSinkTarget(withSinkId: self.renderId)
    }

    func writeFrame(withImage image: UIImage?, forCallId: String) {
        self.frame.onNext(image)
    }

    func createSampleBufferFrom(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var timimgInfo = CMSampleTimingInfo()
        var formatDescription: CMFormatDescription?
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

}
