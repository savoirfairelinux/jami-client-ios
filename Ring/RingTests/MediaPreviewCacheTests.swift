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

final class MediaPreviewCacheTests: XCTestCase {

    private var root: URL!
    private var sources: URL!
    private var cache: MediaPreviewCache!
    private let scope = MediaPreviewScope(accountId: "account", conversationId: "conversation")

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("MediaPreviewCacheTests-" + UUID().uuidString)
        root = base.appendingPathComponent("cache")
        sources = base.appendingPathComponent("sources")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        cache = MediaPreviewCache(root: root)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }

    private func makeSource(_ name: String = "clip.mp4", bytes: Int = 16) throws -> URL {
        let url = sources.appendingPathComponent(name)
        try Data(repeating: 1, count: bytes).write(to: url)
        return url
    }

    private func previewWithThumbnail(for source: URL) throws -> MediaPreview {
        let thumbnail = cache.thumbnailURL(for: source, in: scope)
        try FileManager.default.createDirectory(at: thumbnail.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xFF, 0xD8]).write(to: thumbnail)
        return MediaPreview(durationMicroseconds: 4_000_000, hasAudio: true, hasVideo: true,
                            size: CGSize(width: 640, height: 360), thumbnailURL: thumbnail)
    }

    func testStoredPreviewIsReadBack() throws {
        let source = try makeSource()
        let preview = try previewWithThumbnail(for: source)

        cache.store(preview, for: source, in: scope)

        XCTAssertEqual(cache.load(for: source, in: scope), preview)
    }

    func testChangedSourceSizeIsAMiss() throws {
        let source = try makeSource()
        cache.store(try previewWithThumbnail(for: source), for: source, in: scope)

        try Data(repeating: 2, count: 32).write(to: source)

        XCTAssertNil(cache.load(for: source, in: scope))
    }

    func testChangedModificationDateIsAMiss() throws {
        let source = try makeSource()
        cache.store(try previewWithThumbnail(for: source), for: source, in: scope)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: source.path)

        XCTAssertNil(cache.load(for: source, in: scope))
    }

    func testMissingThumbnailIsAMiss() throws {
        let source = try makeSource()
        let preview = try previewWithThumbnail(for: source)
        cache.store(preview, for: source, in: scope)

        try FileManager.default.removeItem(at: cache.thumbnailURL(for: source, in: scope))

        XCTAssertNil(cache.load(for: source, in: scope))
    }

    func testCorruptSidecarIsAMiss() throws {
        let source = try makeSource()
        cache.store(try previewWithThumbnail(for: source), for: source, in: scope)
        let sidecar = cache.thumbnailURL(for: source, in: scope).deletingPathExtension().appendingPathExtension("json")

        try Data("{\"duration".utf8).write(to: sidecar)

        XCTAssertNil(cache.load(for: source, in: scope))
    }

    func testRemovingAConversationKeepsTheOthers() throws {
        let source = try makeSource()
        let other = MediaPreviewScope(accountId: "account", conversationId: "other")
        let audio = MediaPreview(durationMicroseconds: 1_000_000, hasAudio: true, hasVideo: false, size: nil, thumbnailURL: nil)
        cache.store(audio, for: source, in: scope)
        cache.store(audio, for: source, in: other)

        cache.remove(accountId: "account", conversationId: "conversation")

        XCTAssertNil(cache.load(for: source, in: scope))
        XCTAssertEqual(cache.load(for: source, in: other), audio)
    }

    func testRemovingAnAccountRemovesAllItsConversations() throws {
        let source = try makeSource()
        let other = MediaPreviewScope(accountId: "account", conversationId: "other")
        let otherAccount = MediaPreviewScope(accountId: "second", conversationId: "conversation")
        let audio = MediaPreview(durationMicroseconds: 1_000_000, hasAudio: true, hasVideo: false, size: nil, thumbnailURL: nil)
        [scope, other, otherAccount].forEach { cache.store(audio, for: source, in: $0) }

        cache.remove(accountId: "account")

        XCTAssertNil(cache.load(for: source, in: scope))
        XCTAssertNil(cache.load(for: source, in: other))
        XCTAssertEqual(cache.load(for: source, in: otherAccount), audio)
    }
}
