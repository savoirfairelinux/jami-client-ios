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

import Foundation
import CoreGraphics

struct MediaPreviewScope: Hashable {
    let accountId: String
    let conversationId: String
}

final class MediaPreviewCache {

    static let standard: MediaPreviewCache? = Constants.cachesPath.map {
        MediaPreviewCache(root: $0.appendingPathComponent("media_previews"))
    }

    private struct Entry: Codable {
        let sourceSize: Int64
        let sourceModified: Date
        let durationMicroseconds: Int64
        let hasAudio: Bool
        let hasVideo: Bool
        let width: Double?
        let height: Double?
        let hasThumbnail: Bool
    }

    private struct SourceStamp: Equatable {
        let size: Int64
        let modified: Date
    }

    private let root: URL
    private let fileManager = FileManager.default

    init(root: URL) {
        self.root = root
    }

    func thumbnailURL(for source: URL, in scope: MediaPreviewScope) -> URL {
        return directory(for: scope).appendingPathComponent(source.lastPathComponent + ".jpg")
    }

    func load(for source: URL, in scope: MediaPreviewScope) -> MediaPreview? {
        guard let stamp = stamp(of: source),
              let data = try? Data(contentsOf: sidecarURL(for: source, in: scope)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.sourceSize == stamp.size,
              entry.sourceModified == stamp.modified else { return nil }
        let thumbnail = thumbnailURL(for: source, in: scope)
        if entry.hasThumbnail && !fileManager.fileExists(atPath: thumbnail.path) {
            return nil
        }
        let size = entry.width.flatMap { width in entry.height.map { CGSize(width: width, height: $0) } }
        return MediaPreview(durationMicroseconds: entry.durationMicroseconds,
                            hasAudio: entry.hasAudio,
                            hasVideo: entry.hasVideo,
                            size: size,
                            thumbnailURL: entry.hasThumbnail ? thumbnail : nil)
    }

    func store(_ preview: MediaPreview, for source: URL, in scope: MediaPreviewScope) {
        guard let stamp = stamp(of: source) else { return }
        let entry = Entry(sourceSize: stamp.size,
                          sourceModified: stamp.modified,
                          durationMicroseconds: preview.durationMicroseconds,
                          hasAudio: preview.hasAudio,
                          hasVideo: preview.hasVideo,
                          width: preview.size.map { Double($0.width) },
                          height: preview.size.map { Double($0.height) },
                          hasThumbnail: preview.thumbnailURL?.path == thumbnailURL(for: source, in: scope).path)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? fileManager.createDirectory(at: directory(for: scope), withIntermediateDirectories: true)
        try? data.write(to: sidecarURL(for: source, in: scope), options: .atomic)
    }

    func storeThumbnail(_ data: Data, for source: URL, in scope: MediaPreviewScope) -> URL? {
        let url = thumbnailURL(for: source, in: scope)
        do {
            try fileManager.createDirectory(at: directory(for: scope), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func remove(accountId: String, conversationId: String) {
        try? fileManager.removeItem(at: directory(for: MediaPreviewScope(accountId: accountId, conversationId: conversationId)))
    }

    func remove(accountId: String) {
        try? fileManager.removeItem(at: root.appendingPathComponent(accountId))
    }

    private func directory(for scope: MediaPreviewScope) -> URL {
        return root.appendingPathComponent(scope.accountId).appendingPathComponent(scope.conversationId)
    }

    private func sidecarURL(for source: URL, in scope: MediaPreviewScope) -> URL {
        return directory(for: scope).appendingPathComponent(source.lastPathComponent + ".json")
    }

    private func stamp(of source: URL) -> SourceStamp? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: source.path),
              let size = (attributes[.size] as? NSNumber)?.int64Value,
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return SourceStamp(size: size, modified: modified)
    }
}
