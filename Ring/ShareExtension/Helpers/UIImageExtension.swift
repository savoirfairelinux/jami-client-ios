//
//  UIImageExtension.swift
//  ShareExtension
//
//  Created by Alireza Toghiani on 7/26/23.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import UIKit

extension UIImage {
    func splitImage(keepLeft: Bool) -> UIImage {
        let imgWidth = self.size.width / 2
        let imgHeight = self.size.height

        let left = CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight)
        let right = CGRect(x: imgWidth, y: 0, width: imgWidth, height: imgHeight)

        if keepLeft {
            return UIImage(cgImage: self.cgImage!.cropping(to: left)!)
        } else {
            return UIImage(cgImage: self.cgImage!.cropping(to: right)!)
        }
    }

    class func mergeImages(image1: UIImage, image2: UIImage, spacing: CGFloat = 6, height: CGFloat) -> UIImage {
        let leftImage = image1.splitImage(keepLeft: true)
        let rightImage = image2.splitImage(keepLeft: false)

        let height = max(leftImage.size.height, rightImage.size.height)
        let width = spacing + leftImage.size.width + rightImage.size.width

        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)

        leftImage.draw(in: CGRect(x: 0, y: 0, width: leftImage.size.width, height: height))
        rightImage.draw(in: CGRect(x: spacing + leftImage.size.width, y: 0, width: rightImage.size.width, height: height))

        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return newImage
    }

    class func createContactAvatar(username: String, size: CGSize) -> UIImage {
        let image = UIImage(asset: Asset.fallbackAvatar)!
        let scanner = Scanner(string: username.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            let fbaBGColor = avatarColors[Int(index)]
            if !username.isSHA1() && !username.isEmpty {
                if let avatar = UIImage().drawText(text: username.prefixString().capitalized, backgroundColor: fbaBGColor, textColor: UIColor.white, size: size) {
                    return avatar
                }
            } else {
                if let masked = image.maskWithColor(color: fbaBGColor, size: size) {
                    return masked
                }
            }
        }
        return image
    }

    class func createGroupAvatar(username: String, size: CGSize) -> UIImage {
        let scanner = Scanner(string: username.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            let fbaBGColor = avatarColors[Int(index)]
            if !username.isSHA1() && !username.isEmpty {
                if let avatar = UIImage().drawText(text: username.prefixString().capitalized, backgroundColor: fbaBGColor, textColor: UIColor.white, size: size) {
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

    func drawText(text: String, backgroundColor: UIColor, textColor: UIColor, size: CGSize) -> UIImage? {
        // Setups up the font attributes that will be later used to dictate how the text should be drawn
        let textFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor]
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        backgroundColor.setFill()
        UIRectFill(rect)
        // Put the image into a rectangle as large as the original image.
        self.draw(in: rect)
        // Our drawing bounds
        let textSize = text.size(withAttributes: [NSAttributedString.Key.font: textFont])
        let textRect = CGRect(x: rect.size.width / 2 - textSize.width / 2, y: rect.size.height / 2 - textSize.height / 2,
                              width: textSize.width, height: textSize.height)
        text.draw(in: textRect, withAttributes: textFontAttributes)
        let image: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
