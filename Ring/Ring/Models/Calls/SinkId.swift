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

/// A libjami video-sink identifier. The libjami uses the bare call id for a
/// 1:1 call's decoder and "<baseId>_<media>_<index>" for per-participant
/// conference streams. This type is the only place that string is built
/// or taken apart.
struct SinkId: Hashable, Sendable {
    let raw: String

    init(raw: String) {
        self.raw = raw
    }

    init(baseId: String, label: MediaLabel) {
        self.raw = baseId + "_" + label.libJamiString
    }

    /// The call/participant part of the sink id ("abc" in "abc_video_0";
    /// the whole string when no media suffix is recognized).
    var baseId: String {
        guard let (base, _) = splitMediaSuffix() else { return raw }
        return base
    }

    var mediaLabel: MediaLabel? {
        return splitMediaSuffix()?.1
    }

    /// Splits "..._<media>_<index>" into (base, label); nil when the last
    /// two components don't form a valid media label.
    private func splitMediaSuffix() -> (String, MediaLabel)? {
        let parts = raw.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let candidate = parts.suffix(2).joined(separator: "_")
        let label = MediaLabel(candidate)
        guard !label.libJamiString.isEmpty, label.isAudio || label.isVideo else { return nil }
        let base = parts.dropLast(2).joined(separator: "_")
        return (base, label)
    }
}
