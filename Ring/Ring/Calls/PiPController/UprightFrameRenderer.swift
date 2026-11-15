/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import CoreImage
import CoreMedia
import CoreVideo
import VideoToolbox

final class UprightFrameRenderer {

    private static let maximumDimension: CGFloat = 1280

    private let lock = NSLock()
    private let buffers = PixelBufferPool()
    private lazy var context = CIContext(options: [.cacheIntermediates: false])
    private lazy var rotator: AnyObject? = {
        if #available(iOS 16.0, *) { return PixelRotator() }
        return nil
    }()

    func render(_ sampleBuffer: CMSampleBuffer,
                transform: CGAffineTransform) -> CMSampleBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        let output: CVPixelBuffer?
        if #available(iOS 16.0, *), let rotator = rotator as? PixelRotator {
            output = rotator.rotate(pixelBuffer, transform: transform, buffers: buffers)
        } else {
            output = draw(pixelBuffer, transform: transform)
        }
        return output.flatMap { VideoSinkRegistry.makeSampleBuffer(from: $0) }
    }

    private func draw(_ pixelBuffer: CVPixelBuffer,
                      transform: CGAffineTransform) -> CVPixelBuffer? {
        let flip = CGAffineTransform(scaleX: 1, y: -1)
        let rotated = CIImage(cvPixelBuffer: pixelBuffer)
            .transformed(by: flip.concatenating(transform).concatenating(flip))
        let extent = rotated.extent
        let scale = min(1, Self.maximumDimension / max(extent.width, extent.height))
        let image = rotated
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let output = buffers.make(width: Int((extent.width * scale).rounded()),
                                        height: Int((extent.height * scale).rounded()),
                                        format: kCVPixelFormatType_32BGRA) else { return nil }
        context.render(image, to: output)
        return output
    }
}

/// Rotates and mirrors frames in their own pixel format on the dedicated
/// pixel transfer hardware, without converting them.
@available(iOS 16.0, *)
private final class PixelRotator {

    private var session: VTPixelRotationSession?

    deinit {
        if let session = session { VTPixelRotationSessionInvalidate(session) }
    }

    func rotate(_ pixelBuffer: CVPixelBuffer, transform: CGAffineTransform,
                buffers: PixelBufferPool) -> CVPixelBuffer? {
        guard let orientation = Orientation(transform), let session = makeSession() else {
            return nil
        }
        VTSessionSetProperty(session, key: kVTPixelRotationPropertyKey_Rotation,
                             value: orientation.rotation)
        VTSessionSetProperty(session, key: kVTPixelRotationPropertyKey_FlipHorizontalOrientation,
                             value: orientation.mirrored ? kCFBooleanTrue : kCFBooleanFalse)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let swaps = orientation.degrees % 180 != 0
        guard let output = buffers.make(width: swaps ? height : width,
                                        height: swaps ? width : height,
                                        format: CVPixelBufferGetPixelFormatType(pixelBuffer)),
              VTPixelRotationSessionRotateImage(session, pixelBuffer, output) == noErr
        else { return nil }
        return output
    }

    private func makeSession() -> VTPixelRotationSession? {
        if let session = session { return session }
        var created: VTPixelRotationSession?
        guard VTPixelRotationSessionCreate(kCFAllocatorDefault, &created) == noErr
        else { return nil }
        session = created
        return created
    }

    /// The layer transform as VideoToolbox applies it: a clockwise rotation,
    /// then a horizontal flip.
    private struct Orientation {
        let degrees: Int
        let mirrored: Bool

        var rotation: CFString {
            switch degrees {
            case 90: return kVTRotation_CW90
            case 180: return kVTRotation_180
            case 270: return kVTRotation_CCW90
            default: return kVTRotation_0
            }
        }

        init?(_ transform: CGAffineTransform) {
            for degrees in [0, 90, 180, 270] {
                for mirrored in [false, true] {
                    let candidate = CGAffineTransform(rotationAngle: CGFloat(degrees) * .pi / 180)
                        .concatenating(CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1))
                    if Self.matches(candidate, transform) {
                        self.degrees = degrees
                        self.mirrored = mirrored
                        return
                    }
                }
            }
            return nil
        }

        private static func matches(_ lhs: CGAffineTransform, _ rhs: CGAffineTransform) -> Bool {
            abs(lhs.a - rhs.a) < 0.01 && abs(lhs.b - rhs.b) < 0.01
                && abs(lhs.c - rhs.c) < 0.01 && abs(lhs.d - rhs.d) < 0.01
        }
    }
}

private final class PixelBufferPool {

    private struct PoolKey: Equatable {
        let width: Int
        let height: Int
        let format: OSType
    }

    private var pool: CVPixelBufferPool?
    private var key: PoolKey?

    func make(width: Int, height: Int, format: OSType) -> CVPixelBuffer? {
        let wanted = PoolKey(width: width, height: height, format: format)
        if pool == nil || key != wanted {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: format,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ]
            var created: CVPixelBufferPool?
            CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &created)
            pool = created
            key = wanted
        }
        guard let pool = pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        return buffer
    }
}
