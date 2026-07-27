/*
 * Copyright (C) 2014-2026 Savoir-faire Linux Inc.
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

/// Pure media-list construction. Two libjami contracts live here:
/// the answer to a media-change request must mirror the request's size
/// and order, and video mute is signalled by swapping the source between
/// the camera URI and the "mutedCamera" sentinel.
enum MediaNegotiator {

    static let mutedCameraSource = "mutedCamera"

    static func answer(forRequest requested: [MediaItem],
                       current: [MediaItem]) -> [MediaItem] {
        return requested.map { request in
            var answer = request
            if let existing = current.first(where: {
                $0.label == request.label && $0.type == request.type
            }) {
                answer.muted = existing.muted
                answer.enabled = existing.enabled
            } else {
                answer.muted = request.type == .video
                answer.enabled = true
            }
            return answer
        }
    }

    /// Returns the media list to send in a re-invite that toggles the
    /// mute state of `label`. Toggling a missing default video stream
    /// appends one (audio→video upgrade); a missing audio label is a
    /// no-op (caller sends nothing when the list is unchanged).
    static func togglingMute(in media: [MediaItem],
                             label: MediaLabel,
                             cameraSource: String) -> [MediaItem] {
        var result = media
        if let index = result.firstIndex(where: { $0.label == label }) {
            let wasMuted = result[index].muted
            result[index].enabled = true
            result[index].muted = !wasMuted
            if result[index].type == .video {
                result[index].source = wasMuted ? cameraSource : mutedCameraSource
            }
            return result
        }
        if label == .defaultVideo {
            result.append(MediaItem(type: .video, enabled: true, muted: false,
                                    source: cameraSource, label: label))
        }
        return result
    }

    /// Media list for placing/accepting a regular call.
    static func defaultMediaList(audioOnly: Bool, videoSource: String) -> [MediaItem] {
        var list: [MediaItem] = [.audio()]
        if !audioOnly {
            list.append(MediaItem(type: .video, enabled: true, muted: false,
                                  source: videoSource, label: .defaultVideo))
        }
        return list
    }

    /// Media list for swarm/rendezvous calls: always audio+video, with
    /// video muted (empty source) when joining audio-only.
    static func completeMediaList(videoMuted: Bool, videoSource: String) -> [MediaItem] {
        return [
            .audio(),
            MediaItem(type: .video, enabled: true, muted: videoMuted,
                      source: videoMuted ? "" : videoSource, label: .defaultVideo)
        ]
    }
}
