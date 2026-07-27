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

final class RendererFrameGateTests: XCTestCase {

    private func feed(_ view: RendererLayerView,
                      width: Int, height: Int) throws -> FrameDistributor {
        let distributor = FrameDistributor(sinkId: SinkId(raw: "sink"))
        view.attach(to: distributor)
        let buffer = try makeCaptureSampleBuffer(width: width, height: height)
        distributor.distribute(VideoFrame(sampleBuffer: buffer, rotation: 0))
        waitForMainScheduler()
        return distributor
    }

    func testMatchingFrameIsDisplayed() throws {
        let view = RendererLayerView()
        view.expectedFrameSize = CGSize(width: 800, height: 600)

        _ = try feed(view, width: 800, height: 600)

        XCTAssertTrue(view.hasVideoContent)
    }

    func testStaleCropFrameIsDropped() throws {
        let view = RendererLayerView()
        view.expectedFrameSize = CGSize(width: 939, height: 704)

        _ = try feed(view, width: 800, height: 600)

        XCTAssertFalse(view.hasVideoContent,
                       "an old-crop frame mid-recomposition must not be shown")
    }

    func testSlightAlignmentShaveIsTolerated() throws {
        let view = RendererLayerView()
        view.expectedFrameSize = CGSize(width: 203, height: 360)

        _ = try feed(view, width: 202, height: 360)

        XCTAssertTrue(view.hasVideoContent,
                      "even-alignment can shave a pixel off the crop")
    }

    func testNoExpectationAcceptsEverything() throws {
        let view = RendererLayerView()

        _ = try feed(view, width: 640, height: 480)

        XCTAssertTrue(view.hasVideoContent, "direct calls are ungated")
    }

    func testZeroExpectationFreezesTheTileCompletely() throws {
        let view = RendererLayerView()
        view.expectedFrameSize = .zero

        _ = try feed(view, width: 800, height: 600)

        XCTAssertFalse(view.hasVideoContent,
                       "a recomposition freeze must block every frame")
    }

    func testGateReopensWhenTheExpectationCatchesUp() throws {
        let view = RendererLayerView()
        view.expectedFrameSize = CGSize(width: 800, height: 600)
        let distributor = try feed(view, width: 939, height: 704)
        XCTAssertFalse(view.hasVideoContent)

        view.expectedFrameSize = CGSize(width: 939, height: 704)
        let buffer = try makeCaptureSampleBuffer(width: 939, height: 704)
        distributor.distribute(VideoFrame(sampleBuffer: buffer, rotation: 0))
        waitForMainScheduler()

        XCTAssertTrue(view.hasVideoContent,
                      "the ConfInfo update that re-crops the sink opens the gate")
    }
}
