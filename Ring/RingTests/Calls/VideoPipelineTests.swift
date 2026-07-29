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
@testable import Ring

final class VideoPipelineTests: XCTestCase {

    func testListenerArrivingDuringSinkRegistrationReachesTheSink() {
        let video = TestLibJamiVideoAPI()
        let pipeline = VideoPipeline(video: video)
        let sink = SinkId(baseId: CallTestFixtures.callId.raw, label: .video(0))
        var subscription: FrameSubscription?
        video.onSinkRegistrationStarted = { [weak pipeline] sinkId in
            subscription = pipeline?.sinkRegistry.distributor(for: sinkId).subscribe { _ in }
        }

        pipeline.decodingStarted(withSinkId: sink.raw, withWidth: 640, withHeight: 480)

        XCTAssertEqual(video.listenerStates[sink], true,
                       "a listener that appeared before the renderer existed must be republished")
        _ = subscription
    }

    func testCapturedFrameIsMarkedForImmediateDisplay() throws {
        let pipeline = VideoPipeline(video: TestLibJamiVideoAPI())
        let captured = try makeCaptureSampleBuffer()
        XCTAssertFalse(sampleBufferDisplaysImmediately(captured),
                       "precondition: capture buffers arrive without the attachment")

        var received: CMSampleBuffer?
        let subscription = pipeline.localFrames.subscribe { frame in
            received = frame.sampleBuffer
        }
        pipeline.capturer.onFrame?(nil, captured)
        _ = subscription

        let frame = try XCTUnwrap(received)
        XCTAssertTrue(sampleBufferDisplaysImmediately(frame))
    }

    func testStoppingPreviewCaptureClearsLocalFrameReplay() throws {
        let pipeline = VideoPipeline(video: TestLibJamiVideoAPI())
        pipeline.capturer.onFrame?(nil, try makeCaptureSampleBuffer())

        pipeline.stopPreviewCapture()

        var receivedFrame = false
        let subscription = pipeline.localFrames.subscribe { _ in receivedFrame = true }

        XCTAssertFalse(receivedFrame,
                       "the next call must not receive the previous preview frame")
        _ = subscription
    }
}
