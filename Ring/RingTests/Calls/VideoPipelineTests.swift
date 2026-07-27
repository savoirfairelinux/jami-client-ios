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
import AVFoundation
@testable import Ring

final class VideoPipelineTests: XCTestCase {

    func testCaptureOwnershipAndLatestIntentDetermineRunningState() {
        var state = CameraCaptureState()
        state.setPreview(active: true, quality: .high)
        state.setDaemon(device: CameraDevice.medium, active: true, quality: .medium)

        state.setPreview(active: false, quality: nil)
        XCTAssertTrue(state.shouldRun)
        XCTAssertEqual(state.quality, .medium)

        state.setPreview(active: true, quality: .high)
        state.setDaemon(device: CameraDevice.medium, active: false, quality: nil)
        XCTAssertTrue(state.shouldRun)
        XCTAssertEqual(state.quality, .high)

        state.setPreview(active: false, quality: nil)
        state.setDaemon(device: CameraDevice.medium, active: true, quality: .medium)
        state.setDaemon(device: CameraDevice.medium, active: false, quality: nil)
        XCTAssertFalse(state.shouldRun)
    }

    func testStoppingOneDaemonDeviceKeepsTheOtherActive() {
        var state = CameraCaptureState()
        state.setDaemon(device: CameraDevice.high, active: true, quality: .high)
        state.setDaemon(device: CameraDevice.medium, active: true, quality: .medium)

        state.setDaemon(device: CameraDevice.high, active: false, quality: nil)

        XCTAssertTrue(state.shouldRun)
        XCTAssertEqual(state.quality, .medium)

        state.setDaemon(device: CameraDevice.medium, active: false, quality: nil)
        XCTAssertFalse(state.shouldRun)
    }

    func testStaleVideoStateCannotReserveCaptureDowngrade() throws {
        var state = VideoDowngradeState(currentDeviceId: CameraDevice.high)
        state.setCodec("VP8", forCallId: "call-1")
        let stoppedSink = try XCTUnwrap(state.decodingStarted(SinkId(raw: "call-1")).first)

        state.decodingStopped(stoppedSink)
        XCTAssertFalse(state.reserveDowngrade(stoppedSink, cameraQuality: .high))

        state = VideoDowngradeState(currentDeviceId: CameraDevice.high)
        state.setCodec("VP8", forCallId: "call-1")
        let changedCodec = try XCTUnwrap(state.decodingStarted(SinkId(raw: "call-1")).first)

        state.setCodec("H264", forCallId: "call-1")
        XCTAssertFalse(state.reserveDowngrade(changedCodec, cameraQuality: .high))

        state = VideoDowngradeState(currentDeviceId: CameraDevice.high)
        state.setCodec("VP8", forCallId: "call-1")
        let duplicate = try XCTUnwrap(state.decodingStarted(SinkId(raw: "call-1")).first)

        XCTAssertTrue(state.reserveDowngrade(duplicate, cameraQuality: .high))
        XCTAssertFalse(state.reserveDowngrade(duplicate, cameraQuality: .high))
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
