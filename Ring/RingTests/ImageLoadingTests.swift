/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

import XCTest
import ImageIO
@testable import Ring

class ImageLoadingTests: XCTestCase {

    private var tempImageURL: URL!

    override func setUp() {
        super.setUp()
        tempImageURL = createTempPNG(width: 200, height: 200)
    }

    override func tearDown() {
        if let url = tempImageURL {
            try? FileManager.default.removeItem(at: url)
        }
        super.tearDown()
    }

    // MARK: - createResizedImage tests

    func testCreateResizedImage_zeroSize_returnsImage() {
        guard let source = CGImageSourceCreateWithURL(tempImageURL as CFURL, nil) else {
            XCTFail("Failed to create image source from temp file")
            return
        }
        let image = UIImage.createResizedImage(imageSource: source, size: 0)
        XCTAssertNotNil(image, "createResizedImage with size=0 must return an image (iOS 14/15 regression)")
    }

    func testCreateResizedImage_positiveSize_returnsImage() {
        guard let source = CGImageSourceCreateWithURL(tempImageURL as CFURL, nil) else {
            XCTFail("Failed to create image source from temp file")
            return
        }
        let image = UIImage.createResizedImage(imageSource: source, size: 100)
        XCTAssertNotNil(image)
    }

    func testCreateResizedImage_positiveSize_respectsMaxSize() {
        let largeURL = createTempPNG(width: 1000, height: 800)!
        defer { try? FileManager.default.removeItem(at: largeURL) }

        guard let source = CGImageSourceCreateWithURL(largeURL as CFURL, nil) else {
            XCTFail("Failed to create image source")
            return
        }
        let image = UIImage.createResizedImage(imageSource: source, size: 200)
        XCTAssertNotNil(image)
        // The longest edge should be <= 200
        let maxEdge = max(image!.size.width * image!.scale, image!.size.height * image!.scale)
        XCTAssertLessThanOrEqual(maxEdge, 201, "Image should be downsampled to fit within 200px")
    }

    // MARK: - getImagefromURL tests

    func testGetImageFromURL_zeroMaxSize_returnsImage() {
        let image = UIImage.getImagefromURL(fileURL: tempImageURL, maxSize: 0)
        XCTAssertNotNil(image, "getImagefromURL with maxSize=0 must return image (preview path)")
    }

    func testGetImageFromURL_positiveMaxSize_returnsImage() {
        let image = UIImage.getImagefromURL(fileURL: tempImageURL, maxSize: 250)
        XCTAssertNotNil(image)
    }

    func testNilOptions_failsOnOlderPlatforms() {
        guard let source = CGImageSourceCreateWithURL(tempImageURL as CFURL, nil) else {
            XCTFail("Failed to create image source")
            return
        }
        let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, nil)
        if #available(iOS 16, *) {
            // On iOS 16+, nil options now succeeds (Apple behavior change)
            XCTAssertNotNil(cgImage, "nil options succeeds on iOS 16+")
        } else {
            // On iOS 14/15: no embedded thumbnail → returns nil (the bug)
            XCTAssertNil(cgImage, "nil options should fail on iOS 15 for images without embedded thumbnails")
        }
    }

    // MARK: - GIF loading

    func testGifImageWithUrl_zeroMaxSize_returnsImage() {
        guard let gifURL = createTempGIF() else {
            XCTFail("Failed to create temp GIF")
            return
        }
        defer { try? FileManager.default.removeItem(at: gifURL) }

        let image = UIImage.gifImageWithUrl(gifURL, maxSize: 0)
        XCTAssertNotNil(image, "GIF loading with maxSize=0 should work")
    }

    // MARK: - Helpers

    private func createTempPNG(width: Int, height: Int) -> URL? {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let image = image, let data = UIImagePNGRepresentation(image) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try? data.write(to: url)
        return url
    }

    private func createTempGIF() -> URL? {
        let size = CGSize(width: 50, height: 50)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gif")

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 2, nil) else {
            return nil
        }

        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.5]] as CFDictionary

        for color in [UIColor.red, UIColor.green] {
            UIGraphicsBeginImageContext(size)
            guard let ctx = UIGraphicsGetCurrentContext() else { continue }
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            guard let image = UIGraphicsGetImageFromCurrentImageContext(),
                  let cgImage = image.cgImage else {
                UIGraphicsEndImageContext()
                continue
            }
            UIGraphicsEndImageContext()
            CGImageDestinationAddImage(dest, cgImage, frameProps)
        }

        guard CGImageDestinationFinalize(dest) else { return nil }
        return url
    }
}
