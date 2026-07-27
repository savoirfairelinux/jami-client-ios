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

import XCTest
@testable import Ring

final class VideoScalingTests: XCTestCase {

    private let portraitTile = CGSize(width: 390, height: 844)
    private let landscapeTile = CGSize(width: 844, height: 390)

    private func shouldShowWholeFrame(
        _ videoSize: CGSize,
        rotation: Int = 0,
        tile: CGSize,
        policy: VideoScalingPolicy = .automatic
    ) -> Bool {
        VideoScaling.shouldShowWholeFrame(
            videoSize: videoSize,
            transform: .rotation(degrees: rotation),
            tileSize: tile,
            policy: policy)
    }

    func testPhonePortraitSenderStillFillsPortraitTile() {
        XCTAssertFalse(shouldShowWholeFrame(CGSize(width: 720, height: 1280),
                                            tile: portraitTile))
    }

    func testDesktopSenderIsShownWholeInPortraitTile() {
        XCTAssertTrue(shouldShowWholeFrame(CGSize(width: 1280, height: 720),
                                           tile: portraitTile))
    }

    func testWebcamFourByThreeIsShownWholeInPortraitTile() {
        XCTAssertTrue(shouldShowWholeFrame(CGSize(width: 640, height: 480),
                                           tile: portraitTile))
    }

    func testDesktopSenderFillsLandscapeTile() {
        XCTAssertFalse(shouldShowWholeFrame(CGSize(width: 1280, height: 720),
                                            tile: landscapeTile))
    }

    func testQuarterTurnRotationSwapsTheOutcome() {
        let upright = CGSize(width: 1280, height: 720)
        XCTAssertFalse(shouldShowWholeFrame(upright, rotation: 90, tile: portraitTile),
                       "rotated, the frame is portrait and matches a portrait tile")
        XCTAssertTrue(shouldShowWholeFrame(upright, rotation: 90, tile: landscapeTile))
        XCTAssertFalse(shouldShowWholeFrame(upright, rotation: 180, tile: landscapeTile),
                       "a half turn leaves the frame landscape")
    }

    func testExplicitPoliciesOverrideAutomaticScaling() {
        let landscapeVideo = CGSize(width: 1280, height: 720)
        let portraitVideo = CGSize(width: 720, height: 1280)

        XCTAssertFalse(shouldShowWholeFrame(landscapeVideo, tile: portraitTile,
                                            policy: .aspectFill))
        XCTAssertTrue(shouldShowWholeFrame(portraitVideo, tile: portraitTile,
                                           policy: .aspectFit))
    }

    func testUnknownVideoSizeFallsBackToAspectFill() {
        XCTAssertFalse(shouldShowWholeFrame(.zero, tile: portraitTile))
        XCTAssertFalse(shouldShowWholeFrame(CGSize(width: 1280, height: 720), tile: .zero))
    }

    func testLocalPreviewUsesItsAppliedTransformInsteadOfFrameRotation() {
        let sensorFrame = CGSize(width: 1920, height: 1080)
        let uprightMirrored = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2)

        XCTAssertFalse(VideoScaling.shouldShowWholeFrame(
                        videoSize: sensorFrame,
                        transform: uprightMirrored,
                        tileSize: portraitTile,
                        policy: .automatic),
                       "the camera buffer is landscape but the preview shows it upright")
    }
}
