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

final class MediaPlaybackHarness {
    static let durationMicroseconds: Int64 = 10_000_000

    let video = TestLibJamiVideoAPI()
    let playerQueue = DispatchQueue(label: "MediaPlaybackHarness.player")
    let cacheRoot: URL
    let cache: MediaPreviewCache
    let service: VideoService

    init() {
        cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaPlaybackHarness-" + UUID().uuidString)
        cache = MediaPreviewCache(root: cacheRoot)
        service = VideoService(video: video, playerQueue: playerQueue, previewCache: cache)
    }

    func makeService() -> VideoService {
        return VideoService(video: video, playerQueue: playerQueue, previewCache: cache)
    }

    func removeFiles() {
        try? FileManager.default.removeItem(at: cacheRoot)
    }

    static func preview(hasVideo: Bool = true,
                        durationMicroseconds: Int64 = durationMicroseconds) -> MediaPreview {
        return MediaPreview(durationMicroseconds: durationMicroseconds,
                            hasAudio: true,
                            hasVideo: hasVideo,
                            size: hasVideo ? CGSize(width: 640, height: 360) : nil,
                            thumbnailURL: nil)
    }

    static func item(_ id: String, preview: MediaPreview = preview()) -> PlaybackItem {
        return PlaybackItem(id: id, url: URL(fileURLWithPath: "/media/\(id).mp4"), preview: preview)
    }

    static func playerId(for item: PlaybackItem) -> String {
        return "file://" + item.url.path
    }

    static func info(durationMicroseconds: Int64 = durationMicroseconds, hasVideo: Bool = true) -> [String: String] {
        return ["duration": String(durationMicroseconds),
                "audio_stream": "0",
                "video_stream": hasVideo ? "1" : "-1"]
    }

    func open(_ item: PlaybackItem, in test: XCTestCase, info: [String: String] = MediaPlaybackHarness.info()) {
        settle(in: test)
        service.pipeline.fileOpened(for: item.url.path, fileInfo: info)
        settle(in: test)
    }

    func settle(in test: XCTestCase) {
        playerQueue.sync {}
        test.waitForMainScheduler()
        playerQueue.sync {}
    }

    func operations(for item: PlaybackItem) -> [String] {
        let playerId = Self.playerId(for: item)
        return video.playerOperations.filter { $0.contains(playerId) }
    }
}
