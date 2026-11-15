/*
 * Copyright (C) 2022-2026 Savoir-faire Linux Inc.
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

final class PiPSourceLayerView: UIView {

    let displayLayer = AVSampleBufferDisplayLayer()

    private var subscription: FrameSubscription?
    private weak var attachedDistributor: FrameDistributor?
    private let transformLock = NSLock()
    private var currentTransform = CGAffineTransform.identity
    private var lockedFixedTransform: CGAffineTransform?
    private var videoSize: CGSize?
    private var rendersUpright = false
    private var lastFrame: VideoFrame?
    private var pendingUpright: (buffer: CMSampleBuffer, transform: CGAffineTransform)?
    private var uprightScheduled = false
    private let uprightQueue = DispatchQueue(label: "com.savoirfairelinux.jami.pip.upright")
    private lazy var uprightRenderer = UprightFrameRenderer()

    var videoTileId: String?
    var videoFrameProvider: ((String) -> CGRect?)?

    var fixedTransform: CGAffineTransform? {
        get { locked { lockedFixedTransform } }
        set {
            let changed: Bool = locked {
                guard lockedFixedTransform != newValue else { return false }
                lockedFixedTransform = newValue
                currentTransform = newValue ?? .identity
                return true
            }
            if changed { syncGeometry() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        displayLayer.videoGravity = .resizeAspect
        layer.addSublayer(displayLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncGeometry()
    }

    func attach(to distributor: FrameDistributor?) {
        guard distributor !== attachedDistributor else { return }
        attachedDistributor = distributor
        dropCachedFrames()
        guard let distributor = distributor else {
            subscription = nil
            return
        }
        subscription = distributor.subscribe { [weak self] frame in
            self?.render(frame)
        }
    }

    func clear() {
        dropCachedFrames()
        displayLayer.flushAndRemoveImage()
    }

    func alignToVideo() {
        syncGeometry()
    }

    func setRendersUpright(_ upright: Bool) {
        let catchUp: Bool = locked {
            guard rendersUpright != upright else { return false }
            rendersUpright = upright
            guard upright, let buffer = lastFrame?.sampleBuffer,
                  !currentTransform.isIdentity else { return false }
            pendingUpright = (buffer, currentTransform)
            return true
        }
        syncGeometry()
        if catchUp {
            uprightQueue.sync { drainUpright() }
        }
    }

    private func dropCachedFrames() {
        locked {
            lastFrame = nil
            pendingUpright = nil
        }
    }

    private func render(_ frame: VideoFrame) {
        guard let sampleBuffer = frame.sampleBuffer else {
            dropCachedFrames()
            DispatchQueue.main.async { [weak self] in
                self?.displayLayer.flushAndRemoveImage()
            }
            return
        }
        let size = Self.videoSize(of: sampleBuffer)
        var transform = CGAffineTransform.identity
        var upright = false
        let changed: Bool = locked {
            lastFrame = frame
            transform = lockedFixedTransform
                ?? CGAffineTransform.rotation(degrees: frame.rotation)
            upright = rendersUpright
            guard transform != currentTransform || size != videoSize else { return false }
            currentTransform = transform
            videoSize = size
            return true
        }
        if changed {
            DispatchQueue.main.async { [weak self] in
                self?.syncGeometry()
            }
        }
        if upright && !transform.isIdentity {
            scheduleUpright(sampleBuffer, transform: transform)
        } else {
            enqueue(sampleBuffer)
        }
    }

    private func scheduleUpright(_ buffer: CMSampleBuffer, transform: CGAffineTransform) {
        let schedules: Bool = locked {
            pendingUpright = (buffer, transform)
            guard !uprightScheduled else { return false }
            uprightScheduled = true
            return true
        }
        guard schedules else { return }
        uprightQueue.async { [weak self] in
            self?.drainUpright()
        }
    }

    private func drainUpright() {
        let next = locked { () -> (buffer: CMSampleBuffer, transform: CGAffineTransform)? in
            let next = pendingUpright
            pendingUpright = nil
            uprightScheduled = false
            return next
        }
        guard let next = next else { return }
        enqueue(uprightRenderer.render(next.buffer, transform: next.transform) ?? next.buffer)
    }

    private func enqueue(_ buffer: CMSampleBuffer) {
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    private func syncGeometry() {
        var transform = CGAffineTransform.identity
        var decoded: CGSize?
        var upright = false
        locked {
            transform = currentTransform
            decoded = videoSize
            upright = rendersUpright
        }
        let source = decoded ?? bounds.size
        guard source.width > 0, source.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }
        let footprint = transform.isQuarterTurn
            ? CGSize(width: source.height, height: source.width)
            : source
        let target = drawnVideoFrame() ?? fallbackVideoFrame(source: source,
                                                             footprint: footprint,
                                                             transform: transform)
        let scale = target.width / footprint.width
        let layerSize = upright ? footprint : source
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.bounds = CGRect(origin: .zero,
                                     size: CGSize(width: layerSize.width * scale,
                                                  height: layerSize.height * scale))
        displayLayer.position = CGPoint(x: target.midX, y: target.midY)
        displayLayer.setAffineTransform(upright ? .identity : transform)
        CATransaction.commit()
    }

    private func drawnVideoFrame() -> CGRect? {
        guard window != nil, let id = videoTileId,
              let frame = videoFrameProvider?(id), !frame.isEmpty else { return nil }
        return convert(frame, from: nil)
    }

    private func fallbackVideoFrame(source: CGSize, footprint: CGSize,
                                    transform: CGAffineTransform) -> CGRect {
        let showsWholeFrame = VideoScaling.shouldShowWholeFrame(
            videoSize: source, transform: transform,
            tileSize: bounds.size, policy: .automatic)
        let widthScale = bounds.width / footprint.width
        let heightScale = bounds.height / footprint.height
        let scale = showsWholeFrame
            ? min(widthScale, heightScale) : max(widthScale, heightScale)
        let size = CGSize(width: footprint.width * scale, height: footprint.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private static func videoSize(of sampleBuffer: CMSampleBuffer) -> CGSize? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        let dimensions = CMVideoFormatDescriptionGetPresentationDimensions(
            format, usePixelAspectRatio: true, useCleanAperture: true)
        guard dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGSize(width: dimensions.width, height: dimensions.height)
    }

    private func locked<T>(_ body: () -> T) -> T {
        transformLock.lock()
        defer { transformLock.unlock() }
        return body()
    }
}
