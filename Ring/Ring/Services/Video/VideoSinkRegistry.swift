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
import CoreMedia
import CoreVideo

/// Maps libjami sinks to their `FrameDistributor`s and converts incoming
/// CVPixelBuffers into displayable CMSampleBuffers. Renderers ask for a
/// distributor by typed `SinkId` — no string aliasing.
final class VideoSinkRegistry: @unchecked Sendable {

    private final class WeakDistributor {
        weak var value: FrameDistributor?

        init(_ value: FrameDistributor) {
            self.value = value
        }
    }

    private let lock = NSLock()
    private var distributors: [SinkId: FrameDistributor] = [:]

    private var stoppedDistributors: [SinkId: WeakDistributor] = [:]

    var onListenersChanged: ((SinkId, Bool) -> Void)?

    func distributor(for sinkId: SinkId) -> FrameDistributor {
        lock.lock()
        if let existing = distributors[sinkId] {
            lock.unlock()
            return existing
        }
        if let stopped = stoppedDistributors.removeValue(forKey: sinkId)?.value {
            distributors[sinkId] = stopped
            lock.unlock()
            return stopped
        }
        let distributor = FrameDistributor(sinkId: sinkId) { [weak self] subscriberCount in
            self?.onListenersChanged?(sinkId, subscriberCount >= 1)
        }
        distributors[sinkId] = distributor
        lock.unlock()
        return distributor
    }

    func hasListeners(_ sinkId: SinkId) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let distributor = distributors[sinkId] ?? stoppedDistributors[sinkId]?.value
        return (distributor?.subscriberCount ?? 0) > 0
    }

    /// Promotes a distributor retained by a persistent tile back to the active
    /// registry before libjami registers the restarted sink target.
    func handleDecodingStarted(sinkId: SinkId) {
        lock.lock()
        if distributors[sinkId] == nil,
           let stopped = stoppedDistributors[sinkId]?.value {
            distributors[sinkId] = stopped
        }
        stoppedDistributors[sinkId] = nil
        lock.unlock()
    }

    /// Routes a decoded libjami frame to its distributor.
    func handleFrame(buffer: CVPixelBuffer?, sinkId: SinkId, rotation: Int) {
        guard let sampleBuffer = Self.makeSampleBuffer(from: buffer) else { return }
        distributor(for: sinkId)
            .distribute(VideoFrame(sampleBuffer: sampleBuffer, rotation: rotation))
    }

    /// Signals end-of-stream to renderers. The active registry releases its
    /// strong reference, while persistent tiles can keep the distributor alive
    func handleDecodingStopped(sinkId: SinkId) {
        lock.lock()
        let distributor = distributors.removeValue(forKey: sinkId)
            ?? stoppedDistributors[sinkId]?.value
        if let distributor = distributor {
            stoppedDistributors[sinkId] = WeakDistributor(distributor)
        } else {
            stoppedDistributors[sinkId] = nil
        }
        lock.unlock()
        distributor?.distribute(VideoFrame(sampleBuffer: nil, rotation: 0))
    }

    // MARK: - Buffer conversion

    static func makeSampleBuffer(from pixelBuffer: CVPixelBuffer?) -> CMSampleBuffer? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                     imageBuffer: pixelBuffer,
                                                     formatDescriptionOut: &formatDescription)
        guard let format = formatDescription else { return nil }

        var timingInfo = CMSampleTimingInfo()
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer,
                                                 formatDescription: format,
                                                 sampleTiming: &timingInfo,
                                                 sampleBufferOut: &sampleBuffer)
        guard let buffer = sampleBuffer else { return nil }
        buffer.markForImmediateDisplay()
        return buffer
    }
}
