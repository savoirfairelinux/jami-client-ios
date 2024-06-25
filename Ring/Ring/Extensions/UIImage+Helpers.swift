/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Hadrien De Sousa <hadrien.desousa@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

import CoreImage
import Foundation
import UIKit

// swiftlint:disable identifier_name

extension UIImage {
    var circleMasked: UIImage? {
        let newSize = self.size

        let minEdge = min(newSize.height, newSize.width)
        let size = CGSize(width: minEdge, height: minEdge)

        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        draw(in: CGRect(origin: CGPoint.zero, size: size), blendMode: .copy, alpha: 1.0)

        context.setBlendMode(.copy)
        context.setFillColor(UIColor.clear.cgColor)

        let rectPath = UIBezierPath(rect: CGRect(origin: CGPoint.zero, size: size))
        let circlePath = UIBezierPath(ovalIn: CGRect(origin: CGPoint.zero, size: size))
        rectPath.append(circlePath)
        rectPath.usesEvenOddFillRule = true
        rectPath.fill()

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result
    }

    public class func getImagefromURL(fileURL: URL, maxSize: CGFloat) -> UIImage? {
        let options: CFDictionary? = maxSize == 0 ? nil : [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ] as CFDictionary

        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0,
                                                                       nil) as? [CFString: Any],
              let orientationRawValue = imageProperties[kCGImagePropertyOrientation] as? UInt32
        else {
            return nil
        }
        let orientation = getImageOrientation(from: orientationRawValue)

        return UIImage(
            cgImage: downsampledImage,
            scale: UIScreen.main.scale,
            orientation: orientation
        )
    }

    func setRoundCorner(radius: CGFloat, offset: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let bounds = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: offset, dy: offset),
            cornerRadius: radius
        )
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        path.addClip()
        draw(in: bounds)
        UIColor.jamiMsgBackground.setStroke()
        path.lineWidth = offset * 2
        path.stroke()
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return roundedImage
    }

    // convenience function in UIImage extension to resize a given image
    func convert(toSize targetSize: CGSize, scale: CGFloat) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let imgRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: newSize)
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        draw(in: imgRect)
        guard let copied = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        UIGraphicsEndImageContext()

        return copied
    }

    func convertToData(ofMaxSize maxSize: Int) -> Data? {
        var imageData = jpegData(compressionQuality: 1)
        var fileSize = imageData?.count ?? maxSize
        var i = 10
        while fileSize > maxSize, i >= 0 {
            imageData = jpegData(compressionQuality: CGFloat(0.1 * Double(i)))
            fileSize = imageData?.count ?? maxSize
            i -= 1
        }
        return imageData
    }

    func convertToDataForSwarm() -> Data? {
        let maxSize: CGFloat = 1000
        let image = (size.width > maxSize || size.height > maxSize) ? convert(
            toSize: CGSize(width: 1000, height: 1000),
            scale: 1
        ) : self
        return image.convertToData(ofMaxSize: 40000)
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
        if self.size.width < size.width, self.size.height < size.height {
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
            if imageOrientation == UIImage.Orientation.right ||
                imageOrientation == UIImage.Orientation.left ||
                imageOrientation == UIImage.Orientation.rightMirrored ||
                imageOrientation == UIImage.Orientation.leftMirrored {
                newHeight *= ratio
            } else {
                newWidth = newHeight * ratio
            }
        }

        let newSize = CGSize(width: newWidth, height: newHeight)
        guard let cgImage = cgImage else { return resizeImageWith(newSize: newSize) }
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        guard let colorSpace = cgImage.colorSpace else { return resizeImageWith(newSize: newSize) }
        let bitmapInfo = cgImage.bitmapInfo

        guard let context = CGContext(data: nil,
                                      width: Int(newWidth),
                                      height: Int(newHeight),
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue)
        else { return resizeImageWith(newSize: newSize) }

        context.interpolationQuality = .high
        context.draw(
            cgImage,
            in: CGRect(origin: .zero, size: CGSize(width: newWidth, height: newHeight))
        )
        let image = context.makeImage().flatMap { UIImage(
            cgImage: $0,
            scale: self.scale,
            orientation: self.imageOrientation
        )
        }
        if let newImage: UIImage = image {
            return newImage
        }
        return resizeImageWith(newSize: newSize)
    }

    func getNewSize(of size: CGSize) -> CGSize? {
        if self.size.height == 0 {
            return nil
        }
        var newWidth = size.width
        var newHeight = size.height

        let ratio = self.size.width / self.size.height
        if ratio > 1 {
            newHeight = newWidth / ratio
        } else if ratio < 1, ratio != 0 {
            newWidth = newHeight * ratio
        }

        let newSize = CGSize(width: newWidth, height: newHeight)
        return newSize
    }

    func resizeImageWith(newSize: CGSize, opaque: Bool = true) -> UIImage? {
        let aspectWidth = newSize.width / size.width
        let aspectHeight = newSize.height / size.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let scaledSize = CGSize(width: size.width * aspectRatio, height: size.height * aspectRatio)

        UIGraphicsBeginImageContextWithOptions(scaledSize, opaque, 0)
        draw(in: CGRect(origin: .zero, size: scaledSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    func drawText(
        text: String,
        backgroundColor: UIColor,
        textColor: UIColor,
        size: CGSize,
        textFontSize: CGFloat? = nil
    ) -> UIImage? {
        // Setups up the font attributes that will be later used to dictate how the text should be
        // drawn
        let textFontSize = textFontSize == nil ? 20 : textFontSize
        let textFont = UIFont.systemFont(ofSize: textFontSize!, weight: .semibold)
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor
        ]
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        backgroundColor.setFill()
        UIRectFill(rect)
        // Put the image into a rectangle as large as the original image.
        draw(in: rect)
        // Our drawing bounds
        let textSize = text.size(withAttributes: [NSAttributedString.Key.font: textFont])
        let textRect = CGRect(
            x: rect.size.width / 2 - textSize.width / 2,
            y: rect.size.height / 2 - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: textFontAttributes)
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func drawBackground(color: UIColor, size: CGSize) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func fillJamiBackgroundColor(inset: CGFloat) -> UIImage {
        let color = UIColor.jamiMain
        return fillBackgroundColor(color: color, inset: inset)
    }

    func fillBackgroundColor(color: UIColor, inset: CGFloat) -> UIImage {
        let newSize = CGSize(width: size.width + 2 * inset, height: size.height + 2 * inset)
        let drawingRect = CGRect(x: inset, y: inset, width: size.width, height: size.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)

        let context = UIGraphicsGetCurrentContext()

        color.setFill()
        context?.fill(CGRect(origin: CGPoint.zero, size: newSize))

        UIColor.white.setFill()

        withRenderingMode(.alwaysTemplate).draw(in: drawingRect)

        let imageWithBackground = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return imageWithBackground ?? self
    }

    class func defaultJamiAvatarFor(
        profileName: String?,
        account: AccountModel?,
        size: CGFloat,
        withFontSize fontSize: CGFloat = 14,
        inset: CGFloat = 4
    ) -> UIImage {
        func generateDefaultImage() -> UIImage {
            let configuration = UIImage.SymbolConfiguration(
                pointSize: size,
                weight: .regular,
                scale: .medium
            )
            let defaultImage = UIImage(systemName: "person.fill", withConfiguration: configuration)
            return defaultImage?.fillJamiBackgroundColor(inset: inset).circleMasked ?? defaultImage!
                .fillJamiBackgroundColor(inset: inset)
        }

        func extractUsername(from profileName: String?, and account: AccountModel?) -> String? {
            if let profileName = profileName, !profileName.isEmpty {
                return profileName
            } else if let accountName = account?.registeredName, !accountName.isEmpty {
                return accountName
            } else if let accountID = account?.id,
                      let userNameData = UserDefaults.standard
                        .dictionary(forKey: registeredNamesKey),
                      let accountName = userNameData[accountID] as? String, !accountName.isEmpty {
                return accountName
            }
            return nil
        }

        func generateAvatar(from username: String) -> UIImage? {
            let scanner = Scanner(string: username.toMD5HexString().prefixString())
            var index: UInt64 = 0

            guard scanner.scanHexInt64(&index) else { return nil }
            let fbaBGColor = avatarColors[Int(index)]

            if !username.isSHA1() && !username.isEmpty {
                return UIImage().drawText(
                    text: username.prefixString().capitalized,
                    backgroundColor: fbaBGColor,
                    textColor: .white,
                    size: CGSize(width: size + 8, height: size + 8),
                    textFontSize: fontSize
                )?.circleMasked
            }
            return nil
        }

        let defaultImage = generateDefaultImage()
        guard let account = account else { return defaultImage }
        guard let username = extractUsername(from: profileName, and: account)
        else { return defaultImage }
        return generateAvatar(from: username) ?? defaultImage
    }

    class func mergeImages(image1: UIImage, image2: UIImage, spacing: CGFloat = 6,
                           height _: CGFloat) -> UIImage {
        let leftImage = image1.splitImage(keepLeft: true)
        let rightImage = image2.splitImage(keepLeft: false)

        let height = max(leftImage.size.height, rightImage.size.height)
        let width = spacing + leftImage.size.width + rightImage.size.width

        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)

        leftImage.draw(in: CGRect(x: 0, y: 0, width: leftImage.size.width, height: height))
        rightImage.draw(in: CGRect(
            x: spacing + leftImage.size.width,
            y: 0,
            width: rightImage.size.width,
            height: height
        ))

        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return newImage
    }

    func splitImage(keepLeft: Bool) -> UIImage {
        let imgWidth = size.width / 2
        let imgHeight = size.height

        let left = CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight)
        let right = CGRect(x: imgWidth, y: 0, width: imgWidth, height: imgHeight)

        if keepLeft {
            return UIImage(cgImage: cgImage!.cropping(to: left)!)
        } else {
            return UIImage(cgImage: cgImage!.cropping(to: right)!)
        }
    }

    class func createContactAvatar(username: String, size: CGSize) -> UIImage {
        let config = UIImage.SymbolConfiguration(scale: .large)
        let image = UIImage(systemName: "person", withConfiguration: config)!
        let scanner = Scanner(string: username.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            let fbaBGColor = avatarColors[Int(index)]
            if !username.isSHA1() && !username.isEmpty {
                if let avatar = UIImage().drawText(
                    text: username.prefixString().capitalized,
                    backgroundColor: fbaBGColor,
                    textColor: UIColor.white,
                    size: size
                ) {
                    return avatar
                }
            } else {
                return image.fillBackgroundColor(color: fbaBGColor, inset: 10)
            }
        }
        return image
    }

    class func createSwarmAvatar(convId: String, size _: CGSize) -> UIImage {
        let image = UIImage(systemName: "person.2")!
        let scanner = Scanner(string: convId.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            let fbaBGColor = avatarColors[Int(index)]
            return image.fillBackgroundColor(color: fbaBGColor, inset: 10)
        }
        return image
    }

    class func createGroupAvatar(username: String, size: CGSize) -> UIImage {
        let scanner = Scanner(string: username.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            let fbaBGColor = avatarColors[Int(index)]
            if !username.isSHA1() && !username.isEmpty {
                if let avatar = UIImage().drawText(
                    text: username.prefixString().capitalized,
                    backgroundColor: fbaBGColor,
                    textColor: UIColor.white,
                    size: size
                ) {
                    return avatar
                }
            } else {
                if let image = UIImage(asset: Asset.fallbackAvatar)?.withColor(.white),
                   let masked = image.maskWithColor(color: fbaBGColor, size: size) {
                    return masked
                }
            }
        }
        return UIImage()
    }

    func withColor(_ color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let drawRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        color.setFill()
        UIRectFill(drawRect)
        draw(in: drawRect, blendMode: .destinationIn, alpha: 1)

        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage!
    }

    func maskWithColor(color: UIColor, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, scale)

        guard let ctx = UIGraphicsGetCurrentContext(), let image = cgImage else { return self }
        defer { UIGraphicsEndImageContext() }

        let rect = CGRect(origin: .zero, size: size)
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
        ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height))
        ctx.draw(image, in: rect)

        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }

    class func makeSnapshot(from view: UIView) -> UIImage? {
        let currentSnapshot: UIImage?
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        if let currentGraphicsContext = UIGraphicsGetCurrentContext() {
            view.layer.render(in: currentGraphicsContext)
            currentSnapshot = UIGraphicsGetImageFromCurrentImageContext()
        } else {
            currentSnapshot = nil
        }
        UIGraphicsEndImageContext()
        return currentSnapshot
    }

    func fillPartOfImage(frame: CGRect, with color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        if let context = UIGraphicsGetCurrentContext() {
            let rect = CGRect(origin: .zero, size: size)
            draw(in: rect)
            context.setBlendMode(CGBlendMode.normal)
            context.setFillColor(color.cgColor)
            context.fill(frame)
        }
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    class func createFrom(sampleBuffer: CMSampleBuffer) -> UIImage? {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let ciimage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciimage, from: ciimage.extent)!
        let image = UIImage(cgImage: cgImage)
        return image
    }

    func resizeProfileImage() -> UIImage? {
        // Crop to square based on the smallest dimension
        let sideLength = min(size.width, size.height)
        let squareRect = CGRect(
            x: (size.width - sideLength) / 2,
            y: (size.height - sideLength) / 2,
            width: sideLength,
            height: sideLength
        )
        let squareImage = cropImage(to: squareRect) ?? self
        // Resize if the cropped square is larger than the max size
        if sideLength > Constants.MAX_PROFILE_IMAGE_SIZE {
            return resizeImageWith(newSize: CGSize(
                width: Constants.MAX_PROFILE_IMAGE_SIZE,
                height: Constants.MAX_PROFILE_IMAGE_SIZE
            ))
        }
        return squareImage
    }

    func cropImage(to rect: CGRect) -> UIImage? {
        guard let cgImage = cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

func getImageOrientation(from orientationRawValue: UInt32) -> UIImage.Orientation {
    switch orientationRawValue {
    case 1:
        return .up
    case 2:
        return .upMirrored
    case 3:
        return .down
    case 4:
        return .downMirrored
    case 5:
        return .leftMirrored
    case 6:
        return .right
    case 7:
        return .rightMirrored
    case 8:
        return .left
    default:
        return .up
    }
}
