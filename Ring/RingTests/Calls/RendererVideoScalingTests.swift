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
import AVFoundation
@testable import Ring

final class RendererVideoScalingTests: XCTestCase {

    private let portraitFrame = CGRect(x: 0, y: 0, width: 390, height: 844)

    private func makeView(_ policy: VideoScalingPolicy) -> RendererLayerView {
        let view = RendererLayerView(frame: portraitFrame)
        view.scalingPolicy = policy
        view.layoutIfNeeded()
        return view
    }

    private func sendFrame(to view: RendererLayerView, width: Int, height: Int,
                           rotation: Int = 0) throws {
        let distributor = FrameDistributor(sinkId: SinkId(raw: "sink"))
        view.attach(to: distributor)
        let buffer = try makeCaptureSampleBuffer(width: width, height: height)
        distributor.distribute(VideoFrame(sampleBuffer: buffer, rotation: rotation))
        waitForMainScheduler()
    }

    private func assertShowsWholeFrame(_ view: RendererLayerView,
                                       file: StaticString = #filePath, line: UInt = #line) {
        let rendered = view.renderedVideoRect
        XCTAssertTrue(view.showsWholeFrame, file: file, line: line)
        XCTAssertLessThanOrEqual(rendered.width, view.bounds.width + 0.5,
                                 "video must not overflow the tile width", file: file, line: line)
        XCTAssertLessThanOrEqual(rendered.height, view.bounds.height + 0.5,
                                 "video must not overflow the tile height", file: file, line: line)
        XCTAssertTrue(rendered.width < view.bounds.width - 0.5
                        || rendered.height < view.bounds.height - 0.5,
                      "the whole frame must leave space on at least one axis",
                      file: file, line: line)
        XCTAssertEqual(rendered.midX, view.bounds.midX, accuracy: 0.5,
                       "video is centered horizontally", file: file, line: line)
        XCTAssertEqual(rendered.midY, view.bounds.midY, accuracy: 0.5,
                       "video is centered vertically", file: file, line: line)
    }

    private func assertFillsTile(_ view: RendererLayerView,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let rendered = view.renderedVideoRect
        XCTAssertFalse(view.showsWholeFrame, file: file, line: line)
        XCTAssertGreaterThanOrEqual(rendered.width, view.bounds.width - 0.5,
                                    "video must cover the tile width", file: file, line: line)
        XCTAssertGreaterThanOrEqual(rendered.height, view.bounds.height - 0.5,
                                    "video must cover the tile height", file: file, line: line)
    }

    func testDesktopFrameIsCenteredAndShownWhole() throws {
        let view = makeView(.automatic)

        try sendFrame(to: view, width: 640, height: 480)

        assertShowsWholeFrame(view)
    }

    func testPhoneFrameStillFillsAutomaticallyScaledTile() throws {
        let view = makeView(.automatic)

        try sendFrame(to: view, width: 720, height: 1280)

        assertFillsTile(view)
    }

    func testSwitchingPolicyReevaluatesCurrentFrame() throws {
        let view = makeView(.aspectFill)
        try sendFrame(to: view, width: 1280, height: 720)
        assertFillsTile(view)

        view.scalingPolicy = .automatic

        assertShowsWholeFrame(view)
    }

    func testResizingTileReevaluatesCurrentFrame() throws {
        let view = makeView(.automatic)
        try sendFrame(to: view, width: 1280, height: 720)
        assertShowsWholeFrame(view)

        view.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
        view.layoutIfNeeded()

        assertFillsTile(view)
    }

    func testUprightLocalPreviewStillFillsDespiteLandscapeBuffer() throws {
        let view = makeView(.automatic)
        view.fixedTransform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2)

        try sendFrame(to: view, width: 1920, height: 1080)

        assertFillsTile(view)
    }
}
