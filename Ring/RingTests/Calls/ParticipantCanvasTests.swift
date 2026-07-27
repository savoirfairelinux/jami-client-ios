/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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

import SwiftUI
import XCTest
@testable import Ring

private struct CanvasHost: UIViewRepresentable {
    let canvas: ParticipantCanvas

    func makeUIView(context: Context) -> ParticipantCanvas { canvas }
    func updateUIView(_ uiView: ParticipantCanvas, context: Context) {}
}

final class ParticipantCanvasTests: XCTestCase {

    private let canvasSize = CGSize(width: 390, height: 844)
    private var participantIds: [String] {
        [CallTestFixtures.remoteSinkId,
         CallTestFixtures.secondaryRemoteSinkId,
         CallTestFixtures.tertiaryRemoteSinkId,
         CallTestFixtures.callId.raw].sorted()
    }

    private func makeCanvas() -> ParticipantCanvas {
        ParticipantCanvas(frame: CGRect(origin: .zero, size: canvasSize))
    }

    private func models(_ count: Int) -> [CanvasTileModel] {
        participantIds.prefix(count).map { id in
            CanvasTileModel(participant: CanvasParticipant(id: id),
                            tileState: ParticipantTileState(showsVideo: true),
                            distributor: nil,
                            fixedTransform: nil)
        }
    }

    private func tile(_ id: String, in canvas: ParticipantCanvas) -> ParticipantTileUIView? {
        Self.firstDescendant(in: canvas) { $0.participantId == id }
    }

    private static func firstDescendant<T: UIView>(
        in view: UIView, where matches: (T) -> Bool = { _ in true }) -> T? {
        for subview in view.subviews {
            if let candidate = subview as? T, matches(candidate) { return candidate }
            if let found: T = firstDescendant(in: subview, where: matches) { return found }
        }
        return nil
    }

    private func hostedWindow(_ canvas: ParticipantCanvas) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
                                    .first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: ZStack {
            Color.black.ignoresSafeArea()
            CanvasHost(canvas: canvas).ignoresSafeArea()
        })
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    func testChangingOnlyStyleUpdatesTileGeometry() throws {
        let canvas = makeCanvas()
        let models = models(1)

        canvas.apply(CanvasState(tiles: models, mode: .grid, style: .cards), animated: false)
        let card = try XCTUnwrap(tile(participantIds[0], in: canvas))
        XCTAssertEqual(card.layer.cornerRadius, CanvasLayout.tileCornerRadius)
        XCTAssertGreaterThan(card.frame.minX, 0)

        canvas.apply(CanvasState(tiles: models, mode: .grid, style: .plain), animated: false)

        XCTAssertEqual(card.layer.cornerRadius, 0)
        XCTAssertEqual(card.frame.origin, .zero)
    }

    func testResizeCancelsInFlightModeTransition() throws {
        let canvas = makeCanvas()
        let models = models(4)
        canvas.apply(CanvasState(tiles: models, mode: .grid, style: .cards), animated: false)

        canvas.apply(CanvasState(tiles: models, mode: .spotlight(participantIds[0]),
                                 style: .cards))
        let rotated = CGSize(width: canvasSize.height, height: canvasSize.width)
        canvas.frame = CGRect(origin: .zero, size: rotated)
        canvas.layoutIfNeeded()

        let expected = CanvasLayout.plan(
            CanvasLayout.Input(participants: models.map(\.participant),
                               mode: .spotlight(participantIds[0]),
                               canvasSize: rotated,
                               style: .cards))
        for id in participantIds {
            let actual = try XCTUnwrap(tile(id, in: canvas)?.frame)
            let wanted = try XCTUnwrap(expected.frames[id])
            XCTAssertEqual(actual.minX, wanted.minX, accuracy: 0.5)
            XCTAssertEqual(actual.minY, wanted.minY, accuracy: 0.5)
            XCTAssertEqual(actual.width, wanted.width, accuracy: 0.5)
            XCTAssertEqual(actual.height, wanted.height, accuracy: 0.5,
                           "\(id) retained geometry from before the resize")
        }
    }

    func testFullscreenTileReceivesSafeAreaInsets() throws {
        let canvas = ParticipantCanvas()
        let models = models(2)
        canvas.apply(CanvasState(tiles: models, mode: .fullscreen(participantIds[0]),
                                 style: .cards), animated: false)

        let window = try hostedWindow(canvas)
        defer { window.isHidden = true }
        let focused = try XCTUnwrap(tile(participantIds[0], in: canvas))
        let parked = try XCTUnwrap(tile(participantIds[1], in: canvas))

        XCTAssertEqual(focused.frame, CGRect(origin: .zero, size: canvas.bounds.size))
        XCTAssertEqual(focused.contentInsets, canvas.safeAreaInsets)
        XCTAssertEqual(parked.contentInsets, .zero)
    }
}
