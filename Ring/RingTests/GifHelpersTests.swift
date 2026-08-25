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

    func testAnimatedImageWithUndecodableFrameReturnsNil() throws {
        let source = try makeImageSource(
            base64Encoded: "R0lGODlhAAABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
        )

        XCTAssertEqual(CGImageSourceGetCount(source), 1)
        XCTAssertNil(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertNil(UIImage.animatedImageWithSource(source, maxSize: 0))
    }

    private func makeImageSource(base64Encoded string: String) throws -> CGImageSource {
        let data = try XCTUnwrap(Data(base64Encoded: string))
        return try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    }
}
