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
@testable import Ring

final class FrameDistributorTests: XCTestCase {

    func testSourceDistinguishesLocalCameraFromRemoteSink() {
        let sinkId = SinkId(raw: "remote")

        XCTAssertEqual(FrameDistributor(source: .localCamera).source, .localCamera)
        XCTAssertEqual(FrameDistributor(sinkId: sinkId).source, .remote(sinkId))
    }

    func testFanOutToAllSubscribers() {
        let distributor = FrameDistributor(sinkId: SinkId(raw: "s1"))
        var first = 0
        var second = 0
        let tokenA = distributor.subscribe { _ in first += 1 }
        let tokenB = distributor.subscribe { _ in second += 1 }

        distributor.distribute(VideoFrame(sampleBuffer: nil, rotation: 0))

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
        _ = (tokenA, tokenB)
    }

    func testSubscriberChangesAreReported() {
        var notificationCount = 0
        let distributor = FrameDistributor(sinkId: SinkId(raw: "s1")) {
            notificationCount += 1
        }

        var token: FrameSubscription? = distributor.subscribe { _ in }
        let second = distributor.subscribe { _ in }
        token = nil
        _ = second

        XCTAssertEqual(notificationCount, 3)
        _ = token
    }

    func testCancelledSubscriptionReceivesNothing() {
        let distributor = FrameDistributor(sinkId: SinkId(raw: "s1"))
        var received = 0
        var token: FrameSubscription? = distributor.subscribe { _ in received += 1 }
        token = nil
        _ = token

        distributor.distribute(VideoFrame(sampleBuffer: nil, rotation: 0))

        XCTAssertEqual(received, 0)
    }

    func testLastFrameReplayedToLateSubscriber() {
        let distributor = FrameDistributor(sinkId: SinkId(raw: "s1"))
        distributor.distribute(VideoFrame(sampleBuffer: nil, rotation: 42))

        var rotations: [Int] = []
        let token = distributor.subscribe { rotations.append($0.rotation) }

        XCTAssertEqual(rotations, [42])
        _ = token
    }

    func testClearedFrameIsNotReplayedToLateSubscriber() {
        let distributor = FrameDistributor(sinkId: SinkId(raw: "s1"))
        distributor.distribute(VideoFrame(sampleBuffer: nil, rotation: 42))

        distributor.clearCachedFrame()

        var rotations: [Int] = []
        let token = distributor.subscribe { rotations.append($0.rotation) }

        XCTAssertTrue(rotations.isEmpty)
        _ = token
    }

    func testClearingFrameKeepsSubscribersAttached() {
        let distributor = FrameDistributor(sinkId: SinkId(raw: "s1"))
        var rotations: [Int] = []
        let token = distributor.subscribe { rotations.append($0.rotation) }
        distributor.distribute(VideoFrame(sampleBuffer: nil, rotation: 1))

        distributor.clearCachedFrame()
        distributor.distribute(VideoFrame(sampleBuffer: nil, rotation: 2))

        XCTAssertEqual(rotations, [1, 2])
        _ = token
    }
}

final class VideoSinkRegistryTests: XCTestCase {

    func testListenerChangesPublishCurrentState() {
        let registry = VideoSinkRegistry()
        let sinkId = SinkId(raw: "call-video")
        var states: [Bool] = []
        registry.onListenersChanged = { changedSink, hasListeners in
            XCTAssertEqual(changedSink, sinkId)
            states.append(hasListeners)
        }

        let distributor = registry.distributor(for: sinkId)
        var first: FrameSubscription? = distributor.subscribe { _ in }
        var second: FrameSubscription? = distributor.subscribe { _ in }
        first = nil
        second = nil

        XCTAssertEqual(states, [true, true, true, false])
        _ = (first, second)
    }

    func testObservedDistributorSurvivesDecoderRestart() {
        let registry = VideoSinkRegistry()
        let sinkId = SinkId(raw: "call-video")
        let distributor = registry.distributor(for: sinkId)
        let token = distributor.subscribe { _ in }

        registry.handleDecodingStopped(sinkId: sinkId)
        registry.handleDecodingStarted(sinkId: sinkId)

        XCTAssertTrue(registry.distributor(for: sinkId) === distributor,
                      "a persistent tile must keep receiving frames after decoder restart")
        _ = token
    }

    func testStoppedDistributorIsReleasedAfterLastSubscriberLeaves() {
        let registry = VideoSinkRegistry()
        let sinkId = SinkId(raw: "call-video")
        weak var releasedDistributor: FrameDistributor?
        var token: FrameSubscription?

        autoreleasepool {
            let distributor = registry.distributor(for: sinkId)
            releasedDistributor = distributor
            token = distributor.subscribe { _ in }

            registry.handleDecodingStopped(sinkId: sinkId)
            token = nil
        }

        XCTAssertNil(releasedDistributor)
        _ = token
    }
}
