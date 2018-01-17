//
//  UIImage+Helpers.swift
//  Ring
//
//  Created by Hadrien De Sousa on 17-07-19.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation
import UIKit

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
        guard let imageData = UIImageJPEGRepresentation(self, 1) else {
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
}
