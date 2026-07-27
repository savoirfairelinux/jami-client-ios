/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

/// One media descriptor of a call's media list. libjami identifies streams by
/// `label`; `muted`/`enabled` reflect libjami-confirmed state, not local intent.
struct MediaItem: Hashable, Sendable {
    var type: MediaType
    var enabled: Bool = true
    var muted: Bool = false
    var source: String = ""
    var label: MediaLabel
    var onHold: Bool = false
}

extension MediaItem {

    init?(_ dict: [String: String]) {
        guard let rawType = dict[MediaKey.mediaType.rawValue],
              let type = MediaType(rawValue: rawType) else {
            return nil
        }
        self.type = type
        self.enabled = Bool(libJamiString: dict[MediaKey.enabled.rawValue]) ?? false
        self.muted = Bool(libJamiString: dict[MediaKey.muted.rawValue]) ?? false
        self.source = dict[MediaKey.source.rawValue] ?? ""
        self.label = MediaLabel(dict[MediaKey.label.rawValue] ?? "")
        self.onHold = Bool(libJamiString: dict[MediaKey.onHold.rawValue]) ?? false
    }

    func toDictionary() -> [String: String] {
        return [
            MediaKey.mediaType.rawValue: type.rawValue,
            MediaKey.enabled.rawValue: enabled.libJamiString,
            MediaKey.muted.rawValue: muted.libJamiString,
            MediaKey.source.rawValue: source,
            MediaKey.label.rawValue: label.libJamiString,
            MediaKey.onHold.rawValue: onHold.libJamiString
        ]
    }

    // MARK: - Factories

    static func audio(muted: Bool = false, label: MediaLabel = .defaultAudio) -> MediaItem {
        return MediaItem(type: .audio, muted: muted, label: label)
    }

    static func video(muted: Bool = false, label: MediaLabel = .defaultVideo) -> MediaItem {
        return MediaItem(type: .video, muted: muted, label: label)
    }
}

extension Array where Element == MediaItem {
    init(libJamiMediaList: [[String: String]]) {
        self = libJamiMediaList.compactMap { MediaItem($0) }
    }

    func toDictionaries() -> [[String: String]] {
        return map { $0.toDictionary() }
    }

    var isAudioMuted: Bool {
        first(where: { $0.label == .defaultAudio })?.muted ?? false
    }

    var isVideoMuted: Bool {
        guard let video = first(where: { $0.label == .defaultVideo }) else { return true }
        return video.muted || !video.enabled
    }

    var hasVideo: Bool {
        contains { $0.type == .video && $0.enabled && !$0.muted }
    }

    var hasNegotiatedVideo: Bool {
        contains { $0.type == .video && $0.enabled }
    }
}

/// A media stream label as used in libjami media lists ("audio_0",
/// "video_0", …). Labels identify a stream across renegotiations.
enum MediaLabel: Hashable, Sendable {
    case audio(Int)
    case video(Int)
    case custom(String)

    static let defaultAudio = MediaLabel.audio(0)
    static let defaultVideo = MediaLabel.video(0)

    init(_ raw: String) {
        let parts = raw.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2, let index = Int(parts[1]) {
            switch parts[0] {
            case "audio":
                self = .audio(index)
                return
            case "video":
                self = .video(index)
                return
            default:
                break
            }
        }
        self = .custom(raw)
    }

    var libJamiString: String {
        switch self {
        case .audio(let index):
            return "audio_\(index)"
        case .video(let index):
            return "video_\(index)"
        case .custom(let raw):
            return raw
        }
    }

    var isAudio: Bool {
        if case .audio = self { return true }
        return false
    }

    var isVideo: Bool {
        if case .video = self { return true }
        return false
    }
}
