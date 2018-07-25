/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Hadrien De Sousa <hadrien.desousa@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import UIKit
import CoreImage

// swiftlint:disable identifier_name

extension UIImage {
    var circleMasked: UIImage? {
        let newSize = self.size

        let minEdge = min(newSize.height, newSize.width)
        let size = CGSize(width: minEdge, height: minEdge)

        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()

        self.draw(in: CGRect(origin: CGPoint.zero, size: size), blendMode: .copy, alpha: 1.0)

        context!.setBlendMode(.copy)
        context!.setFillColor(UIColor.clear.cgColor)

        let rectPath = UIBezierPath(rect: CGRect(origin: CGPoint.zero, size: size))
        let circlePath = UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: size))
        rectPath.append(circlePath)
        rectPath.usesEvenOddFillRule = true
        rectPath.fill()

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result
    }

    func setRoundCorner(radius: CGFloat, offset: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        let bounds = CGRect(origin: .zero, size: self.size)
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: offset, dy: offset), cornerRadius: radius)
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        path.addClip()
        self.draw(in: bounds)
        UIColor.ringMsgBackground.setStroke()
        path.lineWidth = offset * 2
        path.stroke()
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return roundedImage
    }

    // convenience function in UIImage extension to resize a given image
    func convert(toSize size: CGSize, scale: CGFloat) -> UIImage {
        let imgRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        self.draw(in: imgRect)
        let copied = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return copied!
    }

    func convertToData(ofMaxSize maxSize: Int) -> Data? {
        guard let imageData = UIImageJPEGRepresentation(self, 0.9) else {
            return nil
        }
        var fileSize = imageData.count
        var i = 10
        while fileSize > maxSize && i >= 0 {
            guard let imageData = UIImageJPEGRepresentation(self, CGFloat(0.1 * Double(i))) else {
                return nil
            }
            fileSize = imageData.count
            i -= 1
        }
        return imageData
    }

    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
	let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }

    func resizeIntoRectangle(of size: CGSize) -> UIImage? {
        if self.size.width < size.width && self.size.height < size.height {
            return self
        }
        if self.size.height == 0 {
            return nil
        }
        var newWidth = size.width
        var newHeight = size.height

        let ratio = self.size.width / self.size.height
        if ratio > 1 {
            newHeight = newWidth / ratio
        } else if ratio < 1, ratio != 0 {
            // android image orientation bug?
            if  self.imageOrientation == UIImageOrientation.right ||
                self.imageOrientation == UIImageOrientation.left ||
                self.imageOrientation == UIImageOrientation.rightMirrored ||
                self.imageOrientation == UIImageOrientation.leftMirrored {
                newHeight *= ratio
            } else {
                newWidth = newHeight * ratio
            }
        }

        let newSize = CGSize(width: newWidth, height: newHeight)
        guard let cgImage = self.cgImage else {return self.resizeImageWith(newSize: newSize)}
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        guard let colorSpace = cgImage.colorSpace else {return self.resizeImageWith(newSize: newSize)}
        let bitmapInfo = cgImage.bitmapInfo

        guard let context = CGContext(data: nil,
                                      width: Int(newWidth),
                                      height: Int(newHeight),
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else {return self.resizeImageWith(newSize: newSize)}

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: newWidth, height: newHeight)))
        let image = context.makeImage().flatMap { UIImage(cgImage: $0, scale: self.scale, orientation: self.imageOrientation) }
        if let newImage: UIImage = image {
            return newImage
        }
        return self.resizeImageWith(newSize: newSize)
    }

    func resizeImageWith(newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
        draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}
