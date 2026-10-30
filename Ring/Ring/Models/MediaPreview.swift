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

struct MediaPreview: Equatable {
    let durationMicroseconds: Int64
    let hasAudio: Bool
    let hasVideo: Bool
    let size: CGSize?
    let thumbnailURL: URL?

    var isPlayable: Bool {
        durationMicroseconds > 0 && (hasAudio || hasVideo)
    }

    init(durationMicroseconds: Int64, hasAudio: Bool, hasVideo: Bool, size: CGSize?, thumbnailURL: URL?) {
        self.durationMicroseconds = durationMicroseconds
        self.hasAudio = hasAudio
        self.hasVideo = hasVideo
        self.size = size
        self.thumbnailURL = thumbnailURL
    }

    init(libJamiInfo info: [String: String], size: CGSize? = nil, thumbnailURL: URL? = nil) {
        self.init(durationMicroseconds: max(0, info["duration"].flatMap(Int64.init) ?? 0),
                  hasAudio: (info["audio_stream"].flatMap(Int.init) ?? -1) >= 0,
                  hasVideo: (info["video_stream"].flatMap(Int.init) ?? -1) >= 0,
                  size: size,
                  thumbnailURL: thumbnailURL)
    }
}
