/*
 * Copyright (C) 2018-2026 Savoir-faire Linux Inc.
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
import CoreMedia

/// One decoded (or locally captured) video frame ready for display.
struct VideoFrame {
    let sampleBuffer: CMSampleBuffer?
    let rotation: Int
}

/// Identifies where a distributor's frames originate without assigning the
/// synthetic local-camera feed a libjami sink identifier.
enum FrameSource: Hashable, Sendable {
    case localCamera
    case remote(SinkId)
}

final class FrameSubscription {
    private let cancelHandler: () -> Void

    fileprivate init(cancel: @escaping () -> Void) {
        self.cancelHandler = cancel
    }

    deinit {
        cancelHandler()
    }
}

/// Fans one frame source out to its renderers (call tile, PiP, preview).
/// Frames are delivered synchronously on the decoding thread —
/// `AVSampleBufferDisplayLayer.enqueue` is thread-safe, so renderers
/// enqueue directly. The last frame is kept and
/// replayed to late subscribers (a tile scrolling back into view shows
/// content immediately).
final class FrameDistributor: @unchecked Sendable {

    let source: FrameSource

    private let onSubscriberCountChanged: ((Int) -> Void)?

    private let lock = NSLock()
    private var handlers: [UUID: (VideoFrame) -> Void] = [:]
    private var lastFrame: VideoFrame?

    init(source: FrameSource, onSubscriberCountChanged: ((Int) -> Void)? = nil) {
        self.source = source
        self.onSubscriberCountChanged = onSubscriberCountChanged
    }

    convenience init(sinkId: SinkId,
                     onSubscriberCountChanged: ((Int) -> Void)? = nil) {
        self.init(source: .remote(sinkId),
                  onSubscriberCountChanged: onSubscriberCountChanged)
    }

    func subscribe(_ handler: @escaping (VideoFrame) -> Void) -> FrameSubscription {
        let id = UUID()
        lock.lock()
        handlers[id] = handler
        let count = handlers.count
        let replay = lastFrame
        lock.unlock()

        onSubscriberCountChanged?(count)
        if let replay = replay {
            handler(replay)
        }
        return FrameSubscription { [weak self] in
            self?.remove(id)
        }
    }

    func distribute(_ frame: VideoFrame) {
        lock.lock()
        lastFrame = frame
        let current = Array(handlers.values)
        lock.unlock()
        for handler in current {
            handler(frame)
        }
    }

    func clearCachedFrame() {
        lock.lock()
        lastFrame = nil
        lock.unlock()
    }

    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return handlers.count
    }

    private func remove(_ id: UUID) {
        lock.lock()
        handlers[id] = nil
        let count = handlers.count
        lock.unlock()
        onSubscriberCountChanged?(count)
    }
}
