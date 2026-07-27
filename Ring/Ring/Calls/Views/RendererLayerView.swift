/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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

import UIKit
import AVFoundation

private final class VideoSurfaceView: UIView {

    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    var displayLayer: AVSampleBufferDisplayLayer {
        guard let layer = layer as? AVSampleBufferDisplayLayer else {
            fatalError("layerClass mismatch")
        }
        return layer
    }
}

final class RendererLayerView: UIView {

    private let surface: VideoSurfaceView

    let displayLayer: AVSampleBufferDisplayLayer

    private(set) var hasVideoContent = false
    var onVideoContentChanged: ((Bool) -> Void)?
    var onWholeFrameDisplayChanged: ((Bool) -> Void)?

    private(set) var showsWholeFrame = false

    private var subscription: FrameSubscription?
    private weak var attachedDistributor: FrameDistributor?

    private let renderStateLock = NSLock()
    private var lockedFixedTransform: CGAffineTransform?
    private var currentTransform = CGAffineTransform.identity
    private var lockedHasContent = false
    private var lockedExpectedFrameSize: CGSize?
    private var lockedVideoSize: CGSize?
    private var lockedScalingPolicy = VideoScalingPolicy.aspectFill
    private var pendingAnimatedSync = false

    var renderedVideoRect: CGRect { surface.frame }

    private static let expectedSizeTolerance: CGFloat = 16

    /// When set, frames that don't match this size are dropped. Conference
    /// sinks are moving crops of the daemon's mixed frame — during a layout
    /// recomposition the crop rect and the freshly composed frame are briefly
    /// out of sync, and those transitional frames contain fragments of other
    /// participants. The expected size comes from the same ConfInfo update
    /// that will re-crop the sink, so the gate opens exactly when real
    /// content arrives; until then the last good image stays up.
    var expectedFrameSize: CGSize? {
        get { locked { lockedExpectedFrameSize } }
        set { locked { lockedExpectedFrameSize = newValue } }
    }

    var scalingPolicy: VideoScalingPolicy {
        get { locked { lockedScalingPolicy } }
        set {
            let changed: Bool = locked {
                guard lockedScalingPolicy != newValue else { return false }
                lockedScalingPolicy = newValue
                return true
            }
            guard changed else { return }
            syncSurfaceGeometry()
        }
    }

    private func acceptsFrame(ofSize size: CGSize?) -> Bool {
        guard let expected = locked({ lockedExpectedFrameSize }) else { return true }
        guard expected != .zero else { return false }
        guard let size = size else { return false }
        func matches(_ width: CGFloat, _ height: CGFloat) -> Bool {
            abs(size.width - width) <= Self.expectedSizeTolerance
                && abs(size.height - height) <= Self.expectedSizeTolerance
        }
        return matches(expected.width, expected.height)
            || matches(expected.height, expected.width)
    }

    override init(frame: CGRect) {
        let surfaceView = VideoSurfaceView()
        surface = surfaceView
        displayLayer = surfaceView.displayLayer
        super.init(frame: frame)
        clipsToBounds = true
        displayLayer.videoGravity = .resizeAspectFill
        addSubview(surface)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncSurfaceGeometry()
    }

    func attach(to distributor: FrameDistributor?) {
        guard distributor !== attachedDistributor else { return }
        attachedDistributor = distributor
        guard let distributor = distributor else {
            subscription = nil
            return
        }
        subscription = distributor.subscribe { [weak self] frame in
            self?.render(frame)
        }
    }

    func markVideoContent() {
        locked { lockedHasContent = true }
        guard !hasVideoContent else { return }
        hasVideoContent = true
        onVideoContentChanged?(true)
    }

    func clearVideoContent() {
        locked { lockedHasContent = false }
        guard hasVideoContent else { return }
        hasVideoContent = false
        onVideoContentChanged?(false)
    }

    var fixedTransform: CGAffineTransform? {
        get { locked { lockedFixedTransform } }
        set {
            let changed: Bool = locked {
                guard let transform = newValue, transform != currentTransform else {
                    lockedFixedTransform = newValue
                    return false
                }
                lockedFixedTransform = newValue
                currentTransform = transform
                return true
            }
            guard changed else { return }
            syncSurfaceGeometry()
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        renderStateLock.lock()
        defer { renderStateLock.unlock() }
        return body()
    }

    private func render(_ frame: VideoFrame) {
        guard let sampleBuffer = frame.sampleBuffer else {
            locked { lockedHasContent = false }
            DispatchQueue.main.async { [weak self] in
                self?.displayLayer.flushAndRemoveImage()
                self?.clearVideoContent()
            }
            return
        }
        let videoSize = sampleBuffer.presentationVideoSize
        guard acceptsFrame(ofSize: videoSize) else { return }
        let changed: Bool = locked {
            let transform = lockedFixedTransform
                ?? CGAffineTransform.rotation(degrees: frame.rotation)
            let sourceChanged = videoSize != lockedVideoSize
            lockedVideoSize = videoSize
            guard transform != currentTransform else { return sourceChanged }
            currentTransform = transform
            return true
        }
        if changed {
            DispatchQueue.main.async { [weak self] in
                self?.syncSurfaceGeometry()
            }
        }
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
        let isFirstFrame: Bool = locked {
            guard !lockedHasContent else { return false }
            lockedHasContent = true
            return true
        }
        if isFirstFrame {
            DispatchQueue.main.async { [weak self] in
                self?.markVideoContent()
            }
        }
    }

    private func syncSurfaceGeometry() {
        let (transform, videoSize, scalingPolicy) = locked {
            (currentTransform, lockedVideoSize, lockedScalingPolicy)
        }
        guard let video = videoSize, video.width > 0, video.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }

        let showsWholeFrame = VideoScaling.shouldShowWholeFrame(
            videoSize: video, transform: transform,
            tileSize: bounds.size, policy: scalingPolicy)
        updateWholeFrameDisplay(showsWholeFrame)

        if UIView.inheritedAnimationDuration == 0 {
            surface.bounds = CGRect(origin: .zero, size: video)
        } else {
            scheduleAnimatedSyncReconciliation()
        }
        let displayed = transform.isQuarterTurn
            ? CGSize(width: video.height, height: video.width)
            : video
        let widthScale = bounds.width / displayed.width
        let heightScale = bounds.height / displayed.height
        let scale = showsWholeFrame
            ? min(widthScale, heightScale) : max(widthScale, heightScale)
        surface.transform = transform.scaledBy(x: scale, y: scale)
        surface.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func updateWholeFrameDisplay(_ showsWholeFrame: Bool) {
        guard self.showsWholeFrame != showsWholeFrame else { return }
        self.showsWholeFrame = showsWholeFrame
        onWholeFrameDisplayChanged?(showsWholeFrame)
    }

    private func scheduleAnimatedSyncReconciliation() {
        guard !pendingAnimatedSync else { return }
        pendingAnimatedSync = true
        let duration = UIView.inheritedAnimationDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            self.pendingAnimatedSync = false
            self.syncSurfaceGeometry()
        }
    }
}
