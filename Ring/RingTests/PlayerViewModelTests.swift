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
@testable import Ring

final class PlayerViewModelTests: XCTestCase {

    private var harness: MediaPlaybackHarness!
    private let item = MediaPlaybackHarness.item("a")
    private var playerId: String { MediaPlaybackHarness.playerId(for: item) }

    override func setUp() {
        harness = MediaPlaybackHarness()
    }

    private func makePlayer(preview: MediaPreview = MediaPlaybackHarness.preview()) -> PlayerViewModel {
        return PlayerViewModel(path: item.url.path, preview: preview, videoService: harness.service)
    }

    private func playingPlayer() -> PlayerViewModel {
        let player = makePlayer()
        player.togglePause()
        harness.open(item, in: self)
        return player
    }

    private func closeCount() -> Int {
        return harness.video.playerOperations.filter { $0 == "close:\(playerId)" }.count
    }

    func testNothingIsOpenedBeforePlay() {
        _ = makePlayer()
        harness.settle(in: self)

        XCTAssertTrue(harness.video.playerOperations.isEmpty)
    }

    func testPlayOpensOnePlayerAndStartsWhenTheFileIsOpened() {
        let player = playingPlayer()

        XCTAssertEqual(player.state, .playing)
        XCTAssertFalse(player.isPaused.value)
        XCTAssertEqual(harness.video.openPlayerIds, [playerId])
        XCTAssertEqual(harness.operations(for: item).last, "pause:\(playerId):false")
    }

    func testPauseKeepsThePlayerOpen() {
        let player = playingPlayer()

        player.togglePause()
        harness.settle(in: self)

        XCTAssertEqual(player.state, .paused)
        XCTAssertTrue(player.isPaused.value)
        XCTAssertEqual(harness.video.openPlayerIds, [playerId])
        XCTAssertEqual(closeCount(), 0)
    }

    func testSeekWhilePausedStaysPaused() {
        let player = playingPlayer()
        player.togglePause()

        player.beginSeek()
        player.endSeek(at: 0.5)
        harness.settle(in: self)

        XCTAssertEqual(player.state, .paused)
        XCTAssertEqual(harness.operations(for: item).suffix(2),
                       ["pause:\(playerId):true", "seek:\(playerId):\(MediaPlaybackHarness.durationMicroseconds / 2)"])
    }

    func testSeekWhilePlayingResumes() {
        let player = playingPlayer()

        player.beginSeek()
        player.endSeek(at: 0.25)
        harness.settle(in: self)

        XCTAssertEqual(player.state, .playing)
        XCTAssertEqual(harness.operations(for: item).suffix(3),
                       ["pause:\(playerId):true",
                        "seek:\(playerId):\(MediaPlaybackHarness.durationMicroseconds / 4)",
                        "pause:\(playerId):false"])
    }

    func testReachingTheEndFinishesAndReplayStartsFromTheBeginning() {
        let player = playingPlayer()
        harness.video.position = MediaPlaybackHarness.durationMicroseconds

        RunLoop.main.run(until: Date().addingTimeInterval(0.45))

        XCTAssertEqual(player.state, .finished)
        XCTAssertTrue(player.isPaused.value)

        player.togglePause()
        harness.settle(in: self)

        XCTAssertEqual(player.state, .playing)
        XCTAssertEqual(harness.operations(for: item).suffix(2), ["seek:\(playerId):0", "pause:\(playerId):false"])
    }

    func testUnplayableFileFailsAndClosesOnce() {
        let player = makePlayer()
        player.togglePause()
        harness.open(item, in: self, info: MediaPlaybackHarness.info(durationMicroseconds: 0))

        player.close()
        harness.settle(in: self)

        XCTAssertEqual(player.state, .failed)
        XCTAssertTrue(player.playbackFailed.value)
        XCTAssertEqual(closeCount(), 1)
        XCTAssertTrue(harness.video.openPlayerIds.isEmpty)
    }

    func testClosingTwiceAndReleasingClosesOnce() {
        var player: PlayerViewModel? = playingPlayer()

        player?.close()
        player?.close()
        player = nil
        harness.settle(in: self)

        XCTAssertEqual(closeCount(), 1)
        XCTAssertTrue(harness.video.openPlayerIds.isEmpty)
    }

    func testPauseBeforeTheFileOpensKeepsItPausedOnceOpened() {
        let player = makePlayer()
        player.togglePause()
        player.togglePause()

        harness.open(item, in: self)

        XCTAssertEqual(player.state, .paused)
        XCTAssertFalse(harness.operations(for: item).contains("pause:\(playerId):false"))
    }
}
