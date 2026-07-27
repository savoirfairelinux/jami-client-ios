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

import XCTest
import SwiftUI
@testable import Ring

private struct CanvasHost: UIViewRepresentable {
    let canvas: ParticipantCanvas

    func makeUIView(context: Context) -> ParticipantCanvas { canvas }
    func updateUIView(_ uiView: ParticipantCanvas, context: Context) {}
}

final class ParticipantCanvasTests: XCTestCase {

    private let canvasSize = CGSize(width: 390, height: 844)

    private func makeCanvas() -> ParticipantCanvas {
        let canvas = ParticipantCanvas(frame: CGRect(origin: .zero, size: canvasSize))
        canvas.layoutIfNeeded()
        return canvas
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

    private func hostedWindow<Root: View>(_ root: Root) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
                                    .first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    @MainActor
    private func makeCallModel(call: CallState) -> CallViewModel {
        let database = DBManager(profileHepler: ProfileDataHelper(),
                                 conversationHelper: ConversationDataHelper(),
                                 interactionHepler: InteractionDataHelper(),
                                 dbConnections: DBContainer())
        return CallViewModel(
            call: call,
            callService: CallService(callClient: TestLibJamiCallAPI(),
                                     callEvents: AsyncStream { _ in }),
            videoService: VideoService(video: TestLibJamiVideoAPI()),
            audio: AudioService(audio: LibJamiAudioClient(adapter: AudioAdapter())),
            profileService: ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                            dbManager: database),
            nameService: NameService(withNameRegistrationAdapter: NameRegistrationAdapter()))
    }

    private var localModel: CanvasTileModel {
        CanvasTileModel(participant: CanvasParticipant(id: CanvasParticipant.localId, isLocalPreview: true),
                        tileState: ParticipantTileState(showsVideo: true),
                        distributor: nil,
                        fixedTransform: nil)
    }

    private var remoteModel: CanvasTileModel {
        CanvasTileModel(participant: CanvasParticipant(id: "call1"),
                        tileState: ParticipantTileState(showsVideo: true),
                        distributor: nil,
                        fixedTransform: nil)
    }

    func testDialingPreviewIsFullscreen() {
        let canvas = makeCanvas()
        canvas.apply(models: [localModel], mode: .grid)
        canvas.layoutIfNeeded()

        XCTAssertEqual(tile(CanvasParticipant.localId, in: canvas)?.frame,
                       CGRect(origin: .zero, size: canvasSize))
    }

    func testAnswerTargetsPreviewToTopTrailingCornerOnScreen() {
        let canvas = makeCanvas()
        canvas.apply(models: [localModel], mode: .grid)
        canvas.layoutIfNeeded()

        canvas.apply(models: [remoteModel, localModel], mode: .grid)

        let preview = tile(CanvasParticipant.localId, in: canvas)
        let remote = tile("call1", in: canvas)
        XCTAssertNotNil(preview)
        XCTAssertNotNil(remote)

        XCTAssertEqual(remote?.frame, CGRect(origin: .zero, size: canvasSize))

        let previewSize = CanvasLayout.previewSize(for: canvasSize)
        let expected = CGRect(x: canvasSize.width - previewSize.width
                                - CanvasLayout.previewPadding,
                              y: CanvasLayout.previewPadding,
                              width: previewSize.width,
                              height: previewSize.height)
        XCTAssertEqual(preview?.frame, expected)
        XCTAssertTrue(CGRect(origin: .zero, size: canvasSize)
                        .contains(preview?.frame ?? .infinite),
                      "preview target must stay on screen, got \(String(describing: preview?.frame))")
    }

    func testPreviewCornerRoundingFollowsMode() {
        let canvas = makeCanvas()
        canvas.apply(models: [localModel], mode: .grid)
        canvas.layoutIfNeeded()
        XCTAssertEqual(tile(CanvasParticipant.localId, in: canvas)?.layer.cornerRadius, 0,
                       "fullscreen dialing preview is edge to edge")

        canvas.apply(models: [remoteModel, localModel], mode: .grid)

        XCTAssertEqual(tile(CanvasParticipant.localId, in: canvas)?.layer.cornerRadius,
                       CanvasLayout.tileCornerRadius,
                       "floating corner preview is rounded")
        XCTAssertEqual(tile("call1", in: canvas)?.layer.cornerRadius, 0,
                       "remote tiles stay edge to edge")
    }

    func testRepeatedApplyKeepsPreviewTarget() {
        let canvas = makeCanvas()
        canvas.apply(models: [localModel], mode: .grid)
        canvas.layoutIfNeeded()
        canvas.apply(models: [remoteModel, localModel], mode: .grid)
        canvas.apply(models: [remoteModel, localModel], mode: .grid)
        canvas.apply(models: [remoteModel, localModel], mode: .grid)

        let frame = tile(CanvasParticipant.localId, in: canvas)?.frame ?? .infinite
        XCTAssertTrue(CGRect(origin: .zero, size: canvasSize).contains(frame),
                      "preview drifted off screen: \(frame)")
    }

    func testCardStyleKeepsConferenceTilesClearOfTheScreenEdge() {
        let canvas = makeCanvas()
        canvas.apply(models: remoteModels(4), mode: .grid, style: .cards)
        canvas.layoutIfNeeded()

        let onScreen = CGRect(origin: .zero, size: canvasSize)
        for index in 0..<4 {
            let tile = self.tile("p\(index)", in: canvas)!
            XCTAssertTrue(onScreen.insetBy(dx: 1, dy: 1).contains(tile.frame),
                          "p\(index) reaches the display edge: \(tile.frame)")
            XCTAssertEqual(tile.layer.cornerRadius, CanvasLayout.tileCornerRadius,
                           "conference tiles are rounded cards")
        }
    }

    func testFullBleedStyleKeepsDirectCallTilesEdgeToEdge() {
        let canvas = makeCanvas()
        canvas.apply(models: [remoteModel], mode: .grid)
        canvas.layoutIfNeeded()

        let tile = self.tile("call1", in: canvas)
        XCTAssertEqual(tile?.frame, CGRect(origin: .zero, size: canvasSize))
        XCTAssertEqual(tile?.layer.cornerRadius, 0)
    }

    func testCanvasBuiltWithoutAFrameKeepsEveryTileOnScreen() {
        let canvas = ParticipantCanvas()
        canvas.apply(models: remoteModels(4), mode: .grid)
        canvas.frame = CGRect(origin: .zero, size: canvasSize)
        canvas.layoutIfNeeded()

        let onScreen = CGRect(origin: .zero, size: canvasSize)
        let scroll = canvas.subviews.compactMap { $0 as? UIScrollView }.first { !$0.isHidden }
        XCTAssertEqual(scroll?.frame, onScreen,
                       "the scroll view must fill a canvas that was built with no frame")
        for index in 0..<4 {
            let tile = self.tile("p\(index)", in: canvas)!
            XCTAssertTrue(onScreen.contains(tile.convert(tile.bounds, to: canvas)),
                          "p\(index) hangs off the canvas: \(tile.frame)")
            XCTAssertEqual(tile.videoView.frame, tile.bounds,
                           "p\(index) video surface does not fill its tile")
        }
    }

    func testCanvasHostedLikeTheCallScreenMatchesTheWindow() throws {
        let canvas = ParticipantCanvas()
        canvas.apply(models: remoteModels(4), mode: .grid)

        let window = try hostedWindow(ZStack {
            Color.black.ignoresSafeArea()
            CanvasHost(canvas: canvas).ignoresSafeArea()
        })

        XCTAssertEqual(canvas.bounds.size, window.bounds.size,
                       "the canvas must be exactly the window")
        XCTAssertEqual(canvas.safeAreaInsets, window.safeAreaInsets,
                       "the canvas must see the real safe area")
        for index in 0..<4 {
            let tile = try XCTUnwrap(self.tile("p\(index)", in: canvas))
            let inWindow = tile.convert(tile.bounds, to: window)
            XCTAssertTrue(window.bounds.contains(inWindow),
                          "p\(index) is cut by the screen edge: \(inWindow)")
        }
    }

    @MainActor
    func testCallScreenNeverLaysOutWiderThanTheWindow() throws {
        let call = CallState(id: CallId(raw: "call-1"),
                             accountId: "account",
                             direction: .incoming,
                             peerUri: "bob",
                             status: .current,
                             media: [.audio(), .video()],
                             isAudioOnly: false)
        let model = makeCallModel(call: call)

        let window = try hostedWindow(CallScreenView(model: model))
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        window.layoutIfNeeded()

        let canvas: ParticipantCanvas = try XCTUnwrap(Self.firstDescendant(in: window))
        XCTAssertEqual(canvas.bounds.width, window.bounds.width,
                       "chrome must never widen the screen past the window: "
                        + "canvas \(canvas.bounds.size) in window \(window.bounds.size)")
        XCTAssertEqual(canvas.convert(canvas.bounds, to: window).minX, 0,
                       "an over-wide canvas gets centred and hangs off both edges")
    }

    func testNearestCornerPerQuadrant() {
        let bounds = CGRect(origin: .zero, size: canvasSize)
        XCTAssertEqual(ParticipantCanvas.nearestCorner(
                        toCenter: CGPoint(x: 40, y: 40), in: bounds), .topLeading)
        XCTAssertEqual(ParticipantCanvas.nearestCorner(
                        toCenter: CGPoint(x: 340, y: 40), in: bounds), .topTrailing)
        XCTAssertEqual(ParticipantCanvas.nearestCorner(
                        toCenter: CGPoint(x: 40, y: 780), in: bounds), .bottomLeading)
        XCTAssertEqual(ParticipantCanvas.nearestCorner(
                        toCenter: CGPoint(x: 340, y: 780), in: bounds), .bottomTrailing)
    }

    func testSpringVelocityNormalisesByDistance() {
        let v = ParticipantCanvas.springVelocity(
            from: CGPoint(x: 600, y: -300),
            current: CGPoint(x: 100, y: 400),
            target: CGPoint(x: 300, y: 100))
        XCTAssertEqual(v.dx, 3, accuracy: 0.0001)
        XCTAssertEqual(v.dy, 1, accuracy: 0.0001)
    }

    func testSpringVelocityZeroSafeWhenAlreadyAtTarget() {
        let v = ParticipantCanvas.springVelocity(
            from: CGPoint(x: 500, y: 500),
            current: CGPoint(x: 200, y: 200),
            target: CGPoint(x: 200, y: 200))
        XCTAssertEqual(v, .zero)
    }

    func testApplyingIdenticalModelsSkipsRelayout() {
        let canvas = makeCanvas()
        canvas.apply(models: [remoteModel], mode: .grid)
        canvas.layoutIfNeeded()
        guard let tile = tile("call1", in: canvas) else { return XCTFail("no tile") }

        tile.frame = tile.frame.offsetBy(dx: 33, dy: 0)
        let held = tile.frame

        canvas.apply(models: [remoteModel], mode: .grid)
        XCTAssertEqual(tile.frame, held, "identical apply must not relayout")
    }

    private func remoteModels(_ count: Int,
                              distributors: [FrameDistributor?]? = nil) -> [CanvasTileModel] {
        (0..<count).map { index in
            CanvasTileModel(participant: CanvasParticipant(id: "p\(index)"),
                            tileState: ParticipantTileState(showsVideo: true),
                            distributor: distributors?[index],
                            fixedTransform: nil)
        }
    }

    func testModeSwitchKeepsTheSameTileInstances() {
        let canvas = makeCanvas()
        let models = remoteModels(4)
        canvas.apply(models: models, mode: .grid)
        canvas.layoutIfNeeded()
        let gridTiles = (0..<4).map { tile("p\($0)", in: canvas) }

        canvas.apply(models: models, mode: .spotlight("p1"))
        canvas.apply(models: models, mode: .fullscreen("p1"))
        canvas.apply(models: models, mode: .grid)

        for (index, before) in gridTiles.enumerated() {
            XCTAssertTrue(before === tile("p\(index)", in: canvas),
                          "p\(index) was recreated by a mode change")
        }
    }

    func testMaximizingFromScrolledGridKeepsEveryTileOnTheCanvas() {
        let canvas = makeCanvas()
        canvas.apply(models: remoteModels(8), mode: .grid)
        canvas.layoutIfNeeded()

        let scroll = canvas.subviews.compactMap { $0 as? UIScrollView }
            .first { !$0.isHidden }
        scroll?.contentOffset = CGPoint(x: 0, y: 200)

        canvas.apply(models: remoteModels(8), mode: .spotlight("p3"))

        let onCanvas = CGRect(origin: .zero, size: canvasSize)
        let focus = tile("p3", in: canvas)!.frame
        XCTAssertEqual(focus.minY, 0, "focus must land at the visible top")
        for index in 0..<8 where index != 3 {
            let frame = tile("p\(index)", in: canvas)!.frame
            XCTAssertTrue(onCanvas.intersects(frame) || frame.minX >= canvasSize.width,
                          "p\(index) landed nowhere visible nor in strip overflow: \(frame)")
            XCTAssertGreaterThanOrEqual(frame.minY,
                                        CanvasLayout.stripBand(CanvasLayout.Input(participants: [], canvasSize: canvasSize)).minY,
                                        "p\(index) must sit in the strip band: \(frame)")
        }
        XCTAssertEqual(scroll?.contentOffset, .zero,
                       "the grid offset must be rebased into the new scene")
    }

    func testFullscreenDetachesStripVideoAndGridReattaches() {
        let canvas = makeCanvas()
        let distributors = (0..<4).map { _ -> FrameDistributor? in
            FrameDistributor(sinkId: SinkId(raw: "sink"))
        }
        let models = remoteModels(4, distributors: distributors)

        canvas.apply(models: models, mode: .grid)
        canvas.layoutIfNeeded()
        XCTAssertTrue(distributors.allSatisfy { $0?.subscriberCount == 1 },
                      "grid: every visible tile renders")

        canvas.apply(models: models, mode: .fullscreen("p0"))
        XCTAssertEqual(distributors[0]?.subscriberCount, 1)
        for index in 1..<4 {
            XCTAssertEqual(distributors[index]?.subscriberCount, 0,
                           "fullscreen: parked strip tile p\(index) must not decode")
        }

        canvas.apply(models: models, mode: .grid)
        XCTAssertTrue(distributors.allSatisfy { $0?.subscriberCount == 1 },
                      "back to grid: everyone renders again")
    }

    func testApplyingChangedModelsRelayouts() {
        let canvas = makeCanvas()
        canvas.apply(models: [remoteModel], mode: .grid)
        canvas.layoutIfNeeded()
        guard let tile = tile("call1", in: canvas) else { return XCTFail("no tile") }
        tile.frame = tile.frame.offsetBy(dx: 33, dy: 0)

        canvas.apply(models: [remoteModel, localModel], mode: .grid)
        XCTAssertEqual(tile.frame, CGRect(origin: .zero, size: canvasSize),
                       "a changed model set must relayout")
    }

    func testOnlyPrimaryTileUsesAutomaticVideoScaling() {
        let canvas = makeCanvas()
        let models = (0..<4).map { index in
            CanvasTileModel(participant: CanvasParticipant(id: "p\(index)"),
                            tileState: ParticipantTileState(showsVideo: true),
                            distributor: nil,
                            fixedTransform: nil)
        }
        canvas.apply(models: models, mode: .spotlight("p1"))
        canvas.layoutIfNeeded()

        XCTAssertEqual(tile("p1", in: canvas)?.videoView.scalingPolicy, .automatic)
        for index in [0, 2, 3] {
            XCTAssertEqual(tile("p\(index)", in: canvas)?.videoView.scalingPolicy, .aspectFill,
                           "strip tiles stay uniform")
        }
    }

    func testDirectCallAutomaticallyScalesRemoteVideoAndFillsPreview() {
        let canvas = makeCanvas()
        canvas.apply(models: [remoteModel, localModel], mode: .grid)
        canvas.layoutIfNeeded()

        XCTAssertEqual(tile("call1", in: canvas)?.videoView.scalingPolicy, .automatic)
        XCTAssertEqual(tile(CanvasParticipant.localId, in: canvas)?.videoView.scalingPolicy,
                       .aspectFill)
    }

    func testDesktopFrameOnDirectCallTileIsShownWhole() throws {
        let canvas = makeCanvas()
        let distributor = FrameDistributor(sinkId: SinkId(raw: "call1"))
        var model = remoteModel
        model.distributor = distributor

        canvas.apply(models: [model, localModel], mode: .grid)
        canvas.layoutIfNeeded()
        distributor.distribute(VideoFrame(sampleBuffer: try makeCaptureSampleBuffer(
                                            width: 1280, height: 720), rotation: 0))
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 1)

        XCTAssertEqual(tile("call1", in: canvas)?.videoView.showsWholeFrame, true,
                       "a 16:9 desktop sender must be shown whole on a portrait canvas")
    }

    func testEveryVideoTileOffersVideoScalingActionToVoiceOver() {
        let canvas = makeCanvas()
        let models = remoteModels(4)
        canvas.apply(models: models, mode: .grid)
        canvas.layoutIfNeeded()

        for index in models.indices {
            XCTAssertEqual(tile("p\(index)", in: canvas)?.accessibilityCustomActions?.count, 1,
                           "VoiceOver must be able to toggle every pinchable video tile")
        }
    }

    func testAudioOnlyPrimaryDoesNotOfferVideoScalingActionToVoiceOver() {
        let canvas = makeCanvas()
        var audioOnly = remoteModel
        audioOnly.tileState.showsVideo = false
        canvas.apply(models: [audioOnly], mode: .grid)
        canvas.layoutIfNeeded()

        XCTAssertNil(tile("call1", in: canvas)?.accessibilityCustomActions,
                     "video scaling has no effect when the tile has no video")
    }
}
