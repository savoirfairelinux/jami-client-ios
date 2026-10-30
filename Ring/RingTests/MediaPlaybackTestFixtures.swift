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
    let cacheRoot: URL
    let cache: MediaPreviewCache
    let service: VideoService

    init() {
        cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaPlaybackHarness-" + UUID().uuidString)
        cache = MediaPreviewCache(root: cacheRoot)
        service = VideoService(video: video, previewCache: cache)
    }

    func makeService() -> VideoService {
        return VideoService(video: video, previewCache: cache)
    }

    func removeFiles() {
        try? FileManager.default.removeItem(at: cacheRoot)
    }

    static func info(durationMicroseconds: Int64 = durationMicroseconds, hasVideo: Bool = true) -> [String: String] {
        return ["duration": String(durationMicroseconds),
                "audio_stream": "0",
                "video_stream": hasVideo ? "1" : "-1"]
    }
}
