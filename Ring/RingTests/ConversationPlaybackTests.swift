/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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
import RxSwift
@testable import Ring

final class ConversationPlaybackTests: XCTestCase {

    private var harness: MediaPlaybackHarness!
    private var playback: ConversationPlayback!
    private let first = MediaPlaybackHarness.item("a")
    private let second = MediaPlaybackHarness.item("b")
    private let disposeBag = DisposeBag()

    override func setUp() {
        harness = MediaPlaybackHarness()
        playback = ConversationPlayback(videoService: harness.service)
    }

    private func play(_ item: PlaybackItem) {
        playback.togglePlay(item)
        harness.open(item, in: self)
    }

    func testShowingPreviewsCreatesNoPlayers() {
        let coordinators = (0..<20).map { index -> PlayerCoordinator in
            let coordinator = PlayerCoordinator()
            coordinator.bind(to: MessageMedia(item: MediaPlaybackHarness.item("row\(index)"), playback: playback))
            return coordinator
        }
        harness.settle(in: self)

        XCTAssertEqual(coordinators.count, 20)
        XCTAssertTrue(harness.video.playerOperations.isEmpty)
        XCTAssertNil(playback.active.value)
    }

    func testPlayingAnItemOpensOnePlayer() {
        play(first)

        XCTAssertEqual(playback.active.value?.itemId, first.id)
        XCTAssertEqual(harness.video.openPlayerIds, [MediaPlaybackHarness.playerId(for: first)])
    }

    func testPlayingAnotherItemClosesTheFirstBeforeOpeningTheSecond() throws {
        play(first)
        play(second)

        let operations = harness.video.playerOperations
        let closeFirst = try XCTUnwrap(operations.firstIndex(of: "close:\(MediaPlaybackHarness.playerId(for: first))"))
        let createSecond = try XCTUnwrap(operations.firstIndex(of: "create:\(MediaPlaybackHarness.playerId(for: second))"))
        XCTAssertLessThan(closeFirst, createSecond)
        XCTAssertEqual(harness.video.openPlayerIds, [MediaPlaybackHarness.playerId(for: second)])
        XCTAssertEqual(harness.video.maxConcurrentPlayers, 1)
        XCTAssertEqual(playback.active.value?.itemId, second.id)
    }

    func testTogglingTheActiveItemPausesInsteadOfClosing() {
        play(first)

        playback.togglePlay(first)
        harness.settle(in: self)

        XCTAssertEqual(playback.active.value?.player.state, .paused)
        XCTAssertEqual(harness.video.openPlayerIds, [MediaPlaybackHarness.playerId(for: first)])
    }

    func testStopClosesTheSession() {
        play(first)

        playback.stop()
        harness.settle(in: self)

        XCTAssertNil(playback.active.value)
        XCTAssertTrue(harness.video.openPlayerIds.isEmpty)
    }

    func testPlaybackStartedFiresOnPlayButNotOnPause() {
        var started = 0
        playback.playbackStarted
            .subscribe(onNext: { started += 1 })
            .disposed(by: disposeBag)

        play(first)
        XCTAssertEqual(started, 1)

        playback.togglePlay(first)
        harness.settle(in: self)
        XCTAssertEqual(started, 1)

        playback.togglePlay(first)
        harness.settle(in: self)
        XCTAssertEqual(started, 2)
    }
}

final class PlayerCoordinatorTests: XCTestCase {

    private var harness: MediaPlaybackHarness!
    private var playback: ConversationPlayback!
    private let item = MediaPlaybackHarness.item("a")
    private let other = MediaPlaybackHarness.item("b")

    override func setUp() {
        harness = MediaPlaybackHarness()
        playback = ConversationPlayback(videoService: harness.service)
    }

    private func boundCoordinator(_ item: PlaybackItem) -> PlayerCoordinator {
        let coordinator = PlayerCoordinator()
        coordinator.bind(to: MessageMedia(item: item, playback: playback))
        waitForMainScheduler()
        return coordinator
    }

    func testInactiveItemShowsThePreviewAndCannotSeek() {
        let coordinator = boundCoordinator(item)

        coordinator.beginSeek()
        coordinator.changeSeek(to: 0.5)
        coordinator.endSeek()
        harness.settle(in: self)

        XCTAssertFalse(coordinator.isActive)
        XCTAssertTrue(coordinator.isPaused)
        XCTAssertEqual(coordinator.duration, Float(MediaPlaybackHarness.durationMicroseconds))
        XCTAssertEqual(coordinator.progress, 0)
        XCTAssertTrue(harness.video.playerOperations.isEmpty)
    }

    func testActiveItemReflectsTheSessionAndCanSeek() {
        let coordinator = boundCoordinator(item)

        coordinator.togglePlay()
        harness.open(item, in: self)
        waitForMainScheduler()

        XCTAssertTrue(coordinator.isActive)
        XCTAssertFalse(coordinator.isPaused)

        coordinator.beginSeek()
        coordinator.changeSeek(to: 0.5)
        coordinator.endSeek()
        harness.settle(in: self)

        XCTAssertTrue(harness.video.playerOperations.contains(
                        "seek:\(MediaPlaybackHarness.playerId(for: item)):\(MediaPlaybackHarness.durationMicroseconds / 2)"))
    }

    func testAnotherActiveItemReturnsThisOneToItsPreview() {
        let coordinator = boundCoordinator(item)
        coordinator.togglePlay()
        harness.open(item, in: self)

        playback.togglePlay(other)
        harness.open(other, in: self)
        waitForMainScheduler()

        XCTAssertFalse(coordinator.isActive)
        XCTAssertTrue(coordinator.isPaused)
        XCTAssertEqual(coordinator.progress, 0)
    }

    func testUnplayablePreviewShowsFailureAndDoesNotOpen() {
        let broken = MediaPlaybackHarness.item("broken", preview: MediaPlaybackHarness.preview(durationMicroseconds: 0))
        let coordinator = boundCoordinator(broken)

        coordinator.togglePlay()
        harness.settle(in: self)

        XCTAssertTrue(coordinator.playbackFailed)
        XCTAssertTrue(harness.video.playerOperations.isEmpty)
    }
}
