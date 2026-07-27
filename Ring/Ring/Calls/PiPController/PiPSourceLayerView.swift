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
    private var videoSize: CGSize?

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
        guard let distributor = distributor else {
            subscription = nil
            return
        }
        subscription = distributor.subscribe { [weak self] frame in
            self?.render(frame)
        }
    }

    func clear() {
        displayLayer.flushAndRemoveImage()
    }

    private func render(_ frame: VideoFrame) {
        guard let sampleBuffer = frame.sampleBuffer else {
            DispatchQueue.main.async { [weak self] in
                self?.displayLayer.flushAndRemoveImage()
            }
            return
        }
        let transform = CGAffineTransform.rotation(degrees: frame.rotation)
        let size = Self.videoSize(of: sampleBuffer)
        let changed: Bool = locked {
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
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    private func syncGeometry() {
        var transform = CGAffineTransform.identity
        var decoded: CGSize?
        locked {
            transform = currentTransform
            decoded = videoSize
        }
        let source = decoded ?? bounds.size
        guard source.width > 0, source.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }
        let footprint = transform.isQuarterTurn
            ? CGSize(width: source.height, height: source.width)
            : source
        let scale = min(bounds.width / footprint.width, bounds.height / footprint.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.bounds = CGRect(origin: .zero,
                                     size: CGSize(width: source.width * scale,
                                                  height: source.height * scale))
        displayLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        displayLayer.setAffineTransform(transform)
        CATransaction.commit()
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
