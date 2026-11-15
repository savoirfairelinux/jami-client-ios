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

final class UprightFrameRenderer {

    private static let maximumDimension: CGFloat = 1280

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let lock = NSLock()
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero

    func render(_ sampleBuffer: CMSampleBuffer,
                transform: CGAffineTransform) -> CMSampleBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let flip = CGAffineTransform(scaleX: 1, y: -1)
        let rotated = CIImage(cvPixelBuffer: pixelBuffer)
            .transformed(by: flip.concatenating(transform).concatenating(flip))
        let extent = rotated.extent
        let scale = min(1, Self.maximumDimension / max(extent.width, extent.height))
        let image = rotated
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let size = CGSize(width: (extent.width * scale).rounded(),
                          height: (extent.height * scale).rounded())
        lock.lock()
        defer { lock.unlock() }
        guard let output = makeBuffer(size: size) else { return nil }
        context.render(image, to: output)
        return VideoSinkRegistry.makeSampleBuffer(from: output)
    }

    private func makeBuffer(size: CGSize) -> CVPixelBuffer? {
        if pool == nil || poolSize != size {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ]
            var newPool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(kCFAllocatorDefault, nil,
                                    attributes as CFDictionary, &newPool)
            pool = newPool
            poolSize = size
        }
        guard let pool = pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        return buffer
    }
}
