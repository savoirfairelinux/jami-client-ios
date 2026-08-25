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

@testable import Ring
import Foundation
import ImageIO
import UIKit
import XCTest

final class GifHelpersTests: XCTestCase {
    func testDelayForImageWithoutTimingMetadataUsesDefault() throws {
        let source = try makeImageSource(
            base64Encoded: "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
        )

        XCTAssertEqual(
            UIImage.delayForImageAtIndex(0, source: source),
            0.1,
            accuracy: 0.001
        )
    }

    func testDecodeFramesWhenSecondFrameFailsReturnsNil() throws {
        let source = try makeImageSource(
            base64Encoded: "R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
        )
        let decodedFrame = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var requestedIndices = [Int]()

        let frames = UIImage.decodeGIFFrames(
            count: 2,
            imageAtIndex: { index in
                requestedIndices.append(index)
                return index == 0 ? decodedFrame : nil
            },
            delayAtIndex: { _ in 0.1 }
        )

        XCTAssertNil(frames)
        XCTAssertEqual(requestedIndices, [0, 1])
    }

    func testAnimatedImageWithZeroFrameSourceReturnsNil() throws {
        let source = try makeImageSource(
            base64Encoded: "R0lGODlh"
        )

        XCTAssertEqual(CGImageSourceGetCount(source), 0)
        XCTAssertNil(UIImage.animatedImageWithSource(source, maxSize: 0))
    }

    private func makeImageSource(base64Encoded string: String) throws -> CGImageSource {
        let data = try XCTUnwrap(Data(base64Encoded: string))
        return try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    }
}
