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
import UIKit
import CoreVideo
import ImageIO
import RxSwift
@testable import Ring

final class VideoServicePreviewTests: XCTestCase {

    private var harness: MediaPlaybackHarness!
    private var source: URL!
    private let scope = MediaPreviewScope(accountId: "account", conversationId: "conversation")
    private let disposeBag = DisposeBag()

    override func setUpWithError() throws {
        harness = MediaPlaybackHarness()
        let sources = harness.cacheRoot.appendingPathComponent("sources")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        source = sources.appendingPathComponent("clip.mp4")
        try Data(repeating: 1, count: 16).write(to: source)
    }

    override func tearDown() {
        harness.removeFiles()
    }

    private func pixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                         [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(buffer)
    }

    private func scriptVideo(width: Int = 2048, height: Int = 1152, orientation: CGImagePropertyOrientation = .up) throws {
        harness.video.previewResult = LibJamiMediaPreview(info: MediaPlaybackHarness.info(),
                                                          pixelBuffer: try pixelBuffer(width: width, height: height),
                                                          orientation: orientation)
    }

    private func preview(_ service: VideoService, scope: MediaPreviewScope?) throws -> MediaPreview {
        let received = expectation(description: "preview")
        var result: MediaPreview?
        service.mediaPreview(for: source, in: scope)
            .subscribe(onSuccess: { preview in
                result = preview
                received.fulfill()
            })
            .disposed(by: disposeBag)
        wait(for: [received], timeout: 5)
        return try XCTUnwrap(result)
    }

    func testScopedPreviewStoresADownsampledThumbnailInTheCache() throws {
        try scriptVideo()

        let result = try preview(harness.service, scope: scope)

        let thumbnail = try XCTUnwrap(result.thumbnailURL)
        XCTAssertEqual(thumbnail.path, harness.cache.thumbnailURL(for: source, in: scope).path)
        let image = try XCTUnwrap(UIImage(contentsOfFile: thumbnail.path)?.cgImage)
        XCTAssertEqual(max(image.width, image.height), VideoService.thumbnailMaxPixelSize)
        XCTAssertEqual(result.size, CGSize(width: 2048, height: 1152))
        XCTAssertEqual(result.durationMicroseconds, MediaPlaybackHarness.durationMicroseconds)
    }

    func testRotatedFrameGivesAnUprightSizeAndThumbnail() throws {
        try scriptVideo(width: 1920, height: 1080, orientation: .right)

        let result = try preview(harness.service, scope: scope)

        XCTAssertEqual(result.size, CGSize(width: 1080, height: 1920))
        let image = try XCTUnwrap(UIImage(contentsOfFile: try XCTUnwrap(result.thumbnailURL).path)?.cgImage)
        XCTAssertLessThan(image.width, image.height)
    }

    func testStoredPreviewIsServedWithoutTheDaemon() throws {
        try scriptVideo()
        _ = try preview(harness.service, scope: scope)

        let fresh = harness.makeService()
        let again = try preview(fresh, scope: scope)

        XCTAssertEqual(harness.video.previewRequests.count, 1)
        XCTAssertNotNil(again.thumbnailURL)
    }

    func testRepeatedRequestsForTheSameFileAskTheDaemonOnce() throws {
        try scriptVideo()
        let first = expectation(description: "first")
        let second = expectation(description: "second")
        harness.service.mediaPreview(for: source, in: scope)
            .subscribe(onSuccess: { _ in first.fulfill() })
            .disposed(by: disposeBag)
        harness.service.mediaPreview(for: source, in: scope)
            .subscribe(onSuccess: { _ in second.fulfill() })
            .disposed(by: disposeBag)

        wait(for: [first, second], timeout: 5)

        XCTAssertEqual(harness.video.previewRequests.count, 1)
    }

    func testUnscopedPreviewStoresNothingInTheCache() throws {
        try scriptVideo()

        let result = try preview(harness.service, scope: nil)

        let thumbnail = try XCTUnwrap(result.thumbnailURL)
        XCTAssertFalse(thumbnail.path.hasPrefix(harness.cacheRoot.path))
        XCTAssertNil(harness.cache.load(for: source, in: scope))
        try? FileManager.default.removeItem(at: thumbnail)
    }

    func testRequestDisposedBeforeItRunsDoesNotAskTheDaemon() throws {
        try scriptVideo()
        let sources = source.deletingLastPathComponent()
        let blocked = sources.appendingPathComponent("blocked.mp4")
        let dropped = sources.appendingPathComponent("dropped.mp4")
        let release = DispatchSemaphore(value: 0)
        let started = expectation(description: "first request started")
        harness.video.onMediaPreview = {
            started.fulfill()
            _ = release.wait(timeout: .now() + 2)
        }
        let first = expectation(description: "first request")
        harness.service.mediaPreview(for: blocked, in: scope)
            .subscribe(onSuccess: { _ in first.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [started], timeout: 2)
        harness.video.onMediaPreview = nil

        harness.service.mediaPreview(for: dropped, in: scope).subscribe().dispose()
        release.signal()
        wait(for: [first], timeout: 2)
        _ = try preview(harness.service, scope: scope)

        XCTAssertEqual(harness.video.previewRequests, [blocked.path, source.path])
    }

    func testStartingTheServiceRemovesTemporaryThumbnails() throws {
        let directory = VideoService.temporaryThumbnailDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stale = directory.appendingPathComponent("stale.jpg")
        try Data([1]).write(to: stale)
        harness.video.previewResult = LibJamiMediaPreview(info: MediaPlaybackHarness.info(hasVideo: false),
                                                          pixelBuffer: nil, orientation: .up)

        _ = try preview(harness.makeService(), scope: nil)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }

    func testAudioFileHasNoThumbnail() throws {
        harness.video.previewResult = LibJamiMediaPreview(info: MediaPlaybackHarness.info(hasVideo: false),
                                                          pixelBuffer: nil, orientation: .up)

        let result = try preview(harness.service, scope: scope)

        XCTAssertNil(result.thumbnailURL)
        XCTAssertNil(result.size)
        XCTAssertFalse(result.hasVideo)
    }
}

final class VideoServicePlayerOrderingTests: XCTestCase {

    private var harness: MediaPlaybackHarness!
    private let disposeBag = DisposeBag()

    override func setUp() {
        harness = MediaPlaybackHarness()
    }

    private func open(_ path: String) {
        harness.service.openPlayer(path: path)
            .subscribe()
            .disposed(by: disposeBag)
    }

    func testReopeningAClosedFileLeavesItOpen() {
        let path = "file:///media/a.mp4"
        open(path)
        harness.service.closePlayer(playerId: path)
        open(path)
        harness.settle(in: self)

        XCTAssertEqual(harness.video.playerOperations, ["create:\(path)", "close:\(path)", "create:\(path)"])
        XCTAssertEqual(harness.video.openPlayerIds, [path])
    }

    func testCommandsIssuedAfterOpenRunAfterTheCreate() {
        let path = "file:///media/a.mp4"
        open(path)
        harness.service.pausePlayer(playerId: path, pause: false)
        harness.service.seekPlayer(playerId: path, to: 5)
        harness.service.mutePlayerAudio(playerId: path, mute: true)
        harness.settle(in: self)

        XCTAssertEqual(harness.video.playerOperations, ["create:\(path)", "pause:\(path):false",
                                                        "seek:\(path):5", "mute:\(path):true"])
    }

    func testPlayerCommandsDoNotRunOnTheMainThread() {
        let path = "file:///media/a.mp4"
        open(path)
        harness.service.pausePlayer(playerId: path, pause: true)
        harness.service.closePlayer(playerId: path)
        harness.settle(in: self)

        XCTAssertEqual(harness.video.playerOperations.count, 3)
        XCTAssertEqual(harness.video.playerCommandsOnMainThread, 0)
    }
}
