/*
 *  Copyright (C) 2025 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import AVFoundation

/// Bundles a captured camera frame with pre-computed orientation data.
/// Published once from `VideoService` so every consumer gets correctly
/// oriented data without duplicating transform logic.
struct LocalFrameInfo {
    let sampleBuffer: CMSampleBuffer
    /// Transform for `AVSampleBufferDisplayLayer.setAffineTransform(_:)`.
    let layerTransform: CGAffineTransform
    /// Orientation metadata for creating a correctly-rotated `UIImage`.
    let imageOrientation: UIImage.Orientation
}

extension AVCaptureVideoOrientation {
    init(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .unknown:
            self = .portrait
        @unknown default:
            self = .portrait
        }
    }

    /// Returns the affine transform needed to orient a local camera preview
    /// whose capture connection is fixed at `.landscapeLeft`.
    /// - Parameter mirrored: `true` for front camera (applies horizontal flip).
    func localPreviewTransform(mirrored: Bool) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        if mirrored {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        switch self {
        case .portrait:
            transform = transform.rotated(by: .pi / 2)
        case .portraitUpsideDown:
            transform = transform.rotated(by: -.pi / 2)
        case .landscapeRight:
            break
        case .landscapeLeft:
            transform = transform.rotated(by: .pi)
        @unknown default:
            break
        }
        return transform
    }

    /// Returns the `UIImage.Orientation` that compensates for the capture
    /// connection being locked at `.landscapeLeft`.
    func imageOrientation(mirrored: Bool) -> UIImage.Orientation {
        switch self {
        case .portrait:
            return mirrored ? .leftMirrored : .left
        case .portraitUpsideDown:
            return mirrored ? .rightMirrored : .right
        case .landscapeRight:
            return mirrored ? .upMirrored : .up
        case .landscapeLeft:
            return mirrored ? .downMirrored : .down
        @unknown default:
            return .up
        }
    }
}

// MARK: - Display Layer Helpers

extension CGAffineTransform {
    /// Creates a rotation transform from a degree value (typically received
    /// from the daemon alongside remote video frames).
    static func rotation(degrees: Int) -> CGAffineTransform {
        let radians = CGFloat(degrees) * .pi / 180.0
        return CGAffineTransform(rotationAngle: radians)
    }
}

extension AVSampleBufferDisplayLayer {
    /// Enqueues a sample buffer, flushing if the layer is in a failed state.
    /// Optionally applies a new affine transform only when it differs from
    /// `currentTransform`, and writes the updated value back.
    func enqueue(_ sampleBuffer: CMSampleBuffer, transform: CGAffineTransform, currentTransform: inout CGAffineTransform) {
        if currentTransform != transform {
            currentTransform = transform
            setAffineTransform(transform)
        }
        if status == .failed {
            flush()
        }
        enqueue(sampleBuffer)
    }
}
