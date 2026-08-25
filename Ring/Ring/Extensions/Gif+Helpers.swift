//
//  iOSDevCenters+GIF.swift
//  GIF-Swift
//
//  Created by iOSDevCenters on 11/12/15.
//  Copyright © 2016 iOSDevCenters. All rights reserved.
//

import UIKit
import ImageIO

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (varL?, varR?):
        return varL < varR
    case (nil, _?):
        return true
    default:
        return false
    }
}

extension UIImage {

    public class func gifImageWithUrl(_ url: URL, maxSize: CGFloat) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        return UIImage.animatedImageWithSource(imageSource, maxSize: maxSize)
    }

    class func delayForImageAtIndex(_ index: Int, source: CGImageSource) -> Double {
        let defaultDelay = 0.1

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as NSDictionary?,
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? NSDictionary else {
            return defaultDelay
        }

        if let delay = (gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue,
           delay > 0, delay.isFinite {
            return max(delay, defaultDelay)
        }

        guard let delay = (gifProperties[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue,
              delay.isFinite else {
            return defaultDelay
        }

        return max(delay, defaultDelay)
    }

    class func gcdForPair(_ varA: Int?, _ varB: Int?) -> Int {
        var varA = varA
        var varB = varB
        if varB == nil || varA == nil {
            if varB != nil {
                return varB!
            } else if varA != nil {
                return varA!
            } else {
                return 0
            }
        }

        if varA < varB {
            let varC = varA
            varA = varB
            varB = varC
        }

        var rest: Int
        while true {
            rest = varA! % varB!

            if rest == 0 {
                return varB!
            } else {
                varA = varB
                varB = rest
            }
        }
    }

    class func gcdForArray(_ array: [Int]) -> Int {
        if array.isEmpty {
            return 1
        }

        var gcd = array[0]

        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }

        return gcd
    }

    typealias GifFrame = (image: CGImage, delay: Int)

    class func decodeGIFFrames(count: Int,
                               imageAtIndex: (Int) -> CGImage?,
                               delayAtIndex: (Int) -> Double) -> [GifFrame]? {
        guard count >= 1 else { return nil }

        var frames = [GifFrame]()
        frames.reserveCapacity(count)

        for index in 0..<count {
            guard let image = imageAtIndex(index) else { return nil }
            let delay = Int(delayAtIndex(index) * 1000.0)
            frames.append((image: image, delay: delay))
        }

        return frames
    }

    class func animatedImageWithSource(_ source: CGImageSource, maxSize: CGFloat) -> UIImage? {
        let options: CFDictionary? = maxSize == 0 ? nil : [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ] as CFDictionary
        let count = CGImageSourceGetCount(source)
        guard let decodedFrames = decodeGIFFrames(
            count: count,
            imageAtIndex: { index in
                CGImageSourceCreateImageAtIndex(source, index, options)
            },
            delayAtIndex: { index in
                UIImage.delayForImageAtIndex(index, source: source)
            }
        ) else {
            return nil
        }

        let delays = decodedFrames.map { $0.delay }
        let duration = delays.reduce(0, +)
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()

        for decodedFrame in decodedFrames {
            let frame = UIImage(cgImage: decodedFrame.image)
            let frameCount = decodedFrame.delay / gcd

            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }

        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)

        return animation
    }
}
