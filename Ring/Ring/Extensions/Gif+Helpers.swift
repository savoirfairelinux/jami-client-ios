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

    public class func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("image doesn't exist")
            return nil
        }

        return UIImage.animatedImageWithSource(source)
    }

    public class func gifImageWithUrl(_ url: URL) -> UIImage? {

        guard let imageData = try? Data(contentsOf: url) else {
            print("SwiftGif: Cannot turn image named \"\(url.path)\" into NSData")
            return nil
        }

        return gifImageWithData(imageData)
    }

    class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1

        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties: CFDictionary = unsafeBitCast(
            CFDictionaryGetValue(cfProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
            to: CFDictionary.self)

        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }

        guard let delayDouble = delayObject as? Double else { return delay }

        delay = delayDouble

        if delay < 0.1 {
            delay = 0.1
        }

        return delay
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

    class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [CGImage]()
        var delays = [Int]()

        for rang in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, rang, nil) {
                images.append(image)
            }

            let delaySeconds = UIImage.delayForImageAtIndex(Int(rang),
                                                            source: source)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }

        let duration: Int = {
            var sum = 0

            for val: Int in delays {
                sum += val
            }

            return sum
        }()

        let gcd = gcdForArray(delays)
        var frames = [UIImage]()

        var frame: UIImage
        var frameCount: Int
        for rang in 0..<count {
            frame = UIImage(cgImage: images[Int(rang)])
            frameCount = Int(delays[Int(rang)] / gcd)

            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }

        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)

        return animation
    }
}
