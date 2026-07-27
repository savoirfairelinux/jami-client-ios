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

final class CanvasLayoutTests: XCTestCase {

    private let canvas = CGSize(width: 400, height: 800)

    private func participants(_ count: Int) -> [CanvasParticipant] {
        return (0..<count).map { CanvasParticipant(id: "p\($0)") }
    }

    private func makeInput(_ participants: [CanvasParticipant],
                           mode: CanvasLayoutMode = .grid,
                           stripOffset: CGFloat = 0) -> CanvasLayout.Input {
        return CanvasLayout.Input(
            participants: participants,
            mode: mode,
            canvasSize: canvas,
            stripOffset: stripOffset)
    }

    func testSingleParticipantFillsCanvas() {
        let layout = CanvasLayout.plan(makeInput(participants(1)))
        XCTAssertEqual(layout.frames["p0"], CGRect(origin: .zero, size: canvas))
        XCTAssertEqual(layout.contentSize, canvas)
    }

    func testTwoParticipantsSplitVertically() {
        let layout = CanvasLayout.plan(makeInput(participants(2)))
        XCTAssertEqual(layout.frames["p0"], CGRect(x: 0, y: 0, width: 400, height: 400))
        XCTAssertEqual(layout.frames["p1"], CGRect(x: 0, y: 400, width: 400, height: 400))
    }

    func testThreeParticipantsOneWideTwoBelow() {
        let layout = CanvasLayout.plan(makeInput(participants(3)))
        XCTAssertEqual(layout.frames["p0"], CGRect(x: 0, y: 0, width: 400, height: 400))
        XCTAssertEqual(layout.frames["p1"], CGRect(x: 0, y: 400, width: 200, height: 400))
        XCTAssertEqual(layout.frames["p2"], CGRect(x: 200, y: 400, width: 200, height: 400))
    }

    func testFourParticipantsTwoByTwo() {
        let layout = CanvasLayout.plan(makeInput(participants(4)))
        XCTAssertEqual(layout.frames["p0"], CGRect(x: 0, y: 0, width: 200, height: 400))
        XCTAssertEqual(layout.frames["p1"], CGRect(x: 200, y: 0, width: 200, height: 400))
        XCTAssertEqual(layout.frames["p2"], CGRect(x: 0, y: 400, width: 200, height: 400))
        XCTAssertEqual(layout.frames["p3"], CGRect(x: 200, y: 400, width: 200, height: 400))
    }

    func testManyParticipantsScrollInRows() {
        let layout = CanvasLayout.plan(makeInput(participants(8)))
        let rowHeight = canvas.height / 3

        XCTAssertEqual(layout.frames["p0"], CGRect(x: 0, y: 0, width: 200, height: rowHeight))
        XCTAssertEqual(layout.frames["p7"],
                       CGRect(x: 200, y: 3 * rowHeight, width: 200, height: rowHeight))
        XCTAssertEqual(layout.contentSize, CGSize(width: 400, height: 4 * rowHeight),
                       "four rows of two -> content taller than canvas")
        XCTAssertTrue(layout.scrollEnabled)
    }

    func testOddParticipantCountLastTileIsWide() {
        let layout = CanvasLayout.plan(makeInput(participants(5)))
        let rowHeight = canvas.height / 3
        XCTAssertEqual(layout.frames["p4"],
                       CGRect(x: 0, y: 2 * rowHeight, width: 400, height: rowHeight))
    }

    func testLocalPreviewFloatsTopTrailingAboveGrid() {
        var all = participants(2)
        all.append(CanvasParticipant(id: CanvasParticipant.localId, isLocalPreview: true))
        var input = makeInput(all)
        input.safeAreaInsets = UIEdgeInsets(top: 50, left: 0, bottom: 30, right: 10)

        let layout = CanvasLayout.plan(input)

        XCTAssertEqual(layout.frames["p0"]?.height, 400)
        let preview = layout.frames[CanvasParticipant.localId]!
        XCTAssertLessThan(preview.width, 200)
        XCTAssertEqual(preview.minY, 50 + CanvasLayout.previewPadding)
        XCTAssertEqual(preview.maxX, canvas.width - 10 - CanvasLayout.previewPadding)
        XCTAssertEqual(layout.zOrder.last, CanvasParticipant.localId)
        XCTAssertFalse(layout.scrollEnabled, "no scrolling needed for two tiles")
    }

    func testLonelyLocalPreviewFillsCanvas() {
        let layout = CanvasLayout.plan(
            makeInput([CanvasParticipant(id: CanvasParticipant.localId, isLocalPreview: true)]))
        XCTAssertEqual(layout.frames[CanvasParticipant.localId], CGRect(origin: .zero, size: canvas))
    }

    func testLocalPreviewCornerIsRespected() {
        var all = participants(1)
        all.append(CanvasParticipant(id: CanvasParticipant.localId, isLocalPreview: true))
        var input = makeInput(all)
        input.previewCorner = .bottomLeading

        let layout = CanvasLayout.plan(input)

        let expected = CanvasLayout.previewOrigin(
            for: .bottomLeading,
            in: CGRect(origin: .zero, size: canvas),
            safeAreaInsets: .zero)
        XCTAssertEqual(layout.frames[CanvasParticipant.localId]?.origin, expected)
    }

    func testPreviewOriginForEachCornerStaysOnScreen() {
        let visible = CGRect(origin: .zero, size: canvas)
        let insets = UIEdgeInsets(top: 50, left: 10, bottom: 30, right: 10)
        let size = CanvasLayout.previewSize(for: canvas)
        let pad = CanvasLayout.previewPadding

        for corner in PreviewCorner.allCases {
            let origin = CanvasLayout.previewOrigin(
                for: corner, in: visible, safeAreaInsets: insets)
            let frame = CGRect(origin: origin, size: size)
            XCTAssertTrue(visible.contains(frame), "\(corner) went off-screen: \(frame)")
        }

        let topTrailing = CanvasLayout.previewOrigin(
            for: .topTrailing, in: visible, safeAreaInsets: insets)
        XCTAssertEqual(topTrailing.y, 50 + pad)
        XCTAssertEqual(topTrailing.x, canvas.width - size.width - pad - 10)

        let bottomLeading = CanvasLayout.previewOrigin(
            for: .bottomLeading, in: visible, safeAreaInsets: insets)
        XCTAssertEqual(bottomLeading.x, 10 + pad)
        XCTAssertEqual(bottomLeading.y,
                       canvas.height - size.height - pad - 30
                        - CanvasLayout.previewBottomClearance)
    }

    func testPreviewSizeSwapsAxesInLandscape() {
        let base = CanvasLayout.basePreviewSize
        XCTAssertEqual(CanvasLayout.previewSize(for: CGSize(width: 400, height: 800)),
                       base, "portrait canvas keeps the portrait footprint")
        XCTAssertEqual(CanvasLayout.previewSize(for: CGSize(width: 800, height: 400)),
                       CGSize(width: base.height, height: base.width),
                       "landscape canvas swaps to a landscape footprint")
    }

    func testLandscapePreviewFitsInLandscapeCanvasCorner() {
        let landscape = CGSize(width: 800, height: 400)
        let visible = CGRect(origin: .zero, size: landscape)
        let size = CanvasLayout.previewSize(for: landscape)
        for corner in PreviewCorner.allCases {
            let origin = CanvasLayout.previewOrigin(
                for: corner, in: visible, safeAreaInsets: .zero)
            XCTAssertTrue(visible.contains(CGRect(origin: origin, size: size)),
                          "\(corner) off-screen in landscape")
        }
    }

    func testEveryParticipantKeepsItsIdAcrossModeChanges() {
        let people = participants(6)
        let grid = CanvasLayout.plan(makeInput(people))
        let spotlight = CanvasLayout.plan(makeInput(people, mode: .spotlight("p2")))
        let fullscreen = CanvasLayout.plan(makeInput(people, mode: .fullscreen("p2")))

        for mode in [grid, spotlight, fullscreen] {
            XCTAssertEqual(Set(mode.frames.keys), Set(people.map(\.id)),
                           "every participant must have a frame in every mode")
        }
    }

    func testSpotlightSplitsCanvasIntoFocusAndStrip() {
        let people = participants(4)
        let layout = CanvasLayout.plan(makeInput(people, mode: .spotlight("p1")))

        let focusHeight = canvas.height * CanvasLayout.spotlightFocusFraction
        XCTAssertEqual(layout.frames["p1"],
                       CGRect(x: 0, y: 0, width: canvas.width, height: focusHeight),
                       "focus takes the top of the content, no viewport math")

        let side = CanvasLayout.stripTileSide(canvasSize: canvas)
        let stripY = focusHeight + CanvasLayout.stripPadding
        XCTAssertEqual(layout.frames["p0"],
                       CGRect(x: CanvasLayout.stripPadding, y: stripY,
                              width: side, height: side))
        XCTAssertEqual(layout.frames["p2"]?.minX,
                       CanvasLayout.stripPadding + side + CanvasLayout.stripSpacing)
        XCTAssertEqual(layout.contentSize, canvas)
        XCTAssertFalse(layout.scrollEnabled)
        XCTAssertTrue(layout.offstage.isEmpty)
    }

    func testSpotlightStripScrollsThroughTheOffset() {
        let people = participants(8)
        let base = CanvasLayout.plan(makeInput(people, mode: .spotlight("p0")))
        let scrolled = CanvasLayout.plan(makeInput(people, mode: .spotlight("p0"),
                                                   stripOffset: 120))

        XCTAssertEqual(scrolled.frames["p1"]!.minX, base.frames["p1"]!.minX - 120,
                       "the strip offset slides strip tiles only")
        XCTAssertEqual(scrolled.frames["p0"], base.frames["p0"],
                       "the focus tile ignores the strip offset")
        XCTAssertEqual(base.stripContentWidth,
                       CanvasLayout.stripContentWidth(tileCount: 7, canvasSize: canvas))
        XCTAssertGreaterThan(base.stripContentWidth, canvas.width,
                             "seven tiles overflow -> the strip must scroll")
    }

    func testFullscreenParksTheStripBelowTheCanvas() {
        let people = participants(4)
        let layout = CanvasLayout.plan(makeInput(people, mode: .fullscreen("p1")))

        XCTAssertEqual(layout.frames["p1"], CGRect(origin: .zero, size: canvas))
        XCTAssertEqual(layout.zOrder.last, "p1")
        XCTAssertFalse(layout.scrollEnabled)
        XCTAssertEqual(layout.offstage, ["p0", "p2", "p3"])
        for id in layout.offstage {
            let frame = layout.frames[id]!
            XCTAssertGreaterThanOrEqual(frame.minY, canvas.height,
                                        "\(id) must wait just below the canvas edge")
            XCTAssertEqual(frame.width, CanvasLayout.stripTileSide(canvasSize: canvas),
                           "parked tiles keep their strip size for the return trip")
        }
    }

    func testEveryModeStaysWithinOneCoordinateSpace() {
        let people = participants(6)
        for mode in [CanvasLayoutMode.grid, .spotlight("p2"), .fullscreen("p2")] {
            let layout = CanvasLayout.plan(makeInput(people, mode: mode))
            for (id, frame) in layout.frames where !layout.offstage.contains(id) {
                XCTAssertGreaterThanOrEqual(frame.minY, 0,
                                            "\(mode) put \(id) above the content top")
                XCTAssertLessThanOrEqual(frame.maxY, layout.contentSize.height,
                                         "\(mode) put \(id) below the content")
            }
        }
    }

    func testSpotlightForUnknownFocusFallsBackToGrid() {
        let people = participants(3)
        let layout = CanvasLayout.plan(makeInput(people, mode: .spotlight("gone")))
        XCTAssertEqual(layout.frames["p0"]?.width, canvas.width,
                       "grid fallback keeps the three-tile arrangement")
    }

    func testVideoAttachesOnlyNearTheViewport() {
        let visible = CGRect(x: 0, y: 800, width: 400, height: 800)
        let margin: CGFloat = 267

        XCTAssertTrue(CanvasLayout.shouldRenderVideo(
                        frame: CGRect(x: 0, y: 900, width: 200, height: 200),
                        visibleRect: visible, margin: margin))
        XCTAssertTrue(CanvasLayout.shouldRenderVideo(
                        frame: CGRect(x: 0, y: 550, width: 200, height: 267),
                        visibleRect: visible, margin: margin),
                      "within one row above the viewport")
        XCTAssertFalse(CanvasLayout.shouldRenderVideo(
                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                        visibleRect: visible, margin: margin),
                       "far offscreen -> detach frames (view keeps last image)")
    }

    func testSoleRemoteIsThePrimaryTile() {
        XCTAssertEqual(CanvasLayout.plan(makeInput(participants(1))).primaryTileId, "p0")
    }

    func testCrowdedGridHasNoPrimaryTile() {
        for count in 2...5 {
            XCTAssertNil(CanvasLayout.plan(makeInput(participants(count))).primaryTileId,
                         "\(count) tiles: none is prominent enough to letterbox")
        }
    }

    func testFocusIsThePrimaryTileInSpotlightAndFullscreen() {
        XCTAssertEqual(CanvasLayout.plan(makeInput(participants(4),
                                                   mode: .spotlight("p2"))).primaryTileId,
                       "p2")
        XCTAssertEqual(CanvasLayout.plan(makeInput(participants(4),
                                                   mode: .fullscreen("p2"))).primaryTileId,
                       "p2")
    }

    func testLonelyPreviewIsThePrimaryTile() {
        let preview = CanvasParticipant(id: CanvasParticipant.localId, isLocalPreview: true)
        XCTAssertEqual(CanvasLayout.plan(makeInput([preview])).primaryTileId,
                       CanvasParticipant.localId)
    }

    func testPreviewIsNotPrimaryOnceARemoteIsPresent() {
        let preview = CanvasParticipant(id: CanvasParticipant.localId, isLocalPreview: true)
        let layout = CanvasLayout.plan(makeInput(participants(1) + [preview]))
        XCTAssertEqual(layout.primaryTileId, "p0")
    }
}
