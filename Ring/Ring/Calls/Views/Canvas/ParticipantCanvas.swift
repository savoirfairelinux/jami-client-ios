/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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

import UIKit

struct CanvasTileModel {
    let participant: CanvasParticipant
    let tileState: ParticipantTileState
    let distributor: FrameDistributor?
    let fixedTransform: CGAffineTransform?
    let avatarProvider: AvatarProvider?
    let expectedVideoSize: CGSize?

    init(participant: CanvasParticipant,
         tileState: ParticipantTileState,
         distributor: FrameDistributor? = nil,
         fixedTransform: CGAffineTransform? = nil,
         avatarProvider: AvatarProvider? = nil,
         expectedVideoSize: CGSize? = nil) {
        self.participant = participant
        self.tileState = tileState
        self.distributor = distributor
        self.fixedTransform = fixedTransform
        self.avatarProvider = avatarProvider
        self.expectedVideoSize = expectedVideoSize
    }
}

extension CanvasTileModel: Equatable {
    static func == (lhs: CanvasTileModel, rhs: CanvasTileModel) -> Bool {
        return lhs.participant == rhs.participant
            && lhs.tileState == rhs.tileState
            && lhs.fixedTransform == rhs.fixedTransform
            && lhs.distributor === rhs.distributor
            && lhs.avatarProvider === rhs.avatarProvider
            && lhs.expectedVideoSize == rhs.expectedVideoSize
    }
}

// swiftlint:disable:next type_body_length
final class ParticipantCanvas: UIView {

    var onCanvasTapped: (() -> Void)?
    var onTileLongPressed: ((String) -> Void)?

    static let modeSwitchDuration: TimeInterval = 0.35
    static let answerTransitionDuration: TimeInterval = 0.5
    static let tileFadeDuration: TimeInterval = 0.25

    private let scrollView = UIScrollView()
    private let stripDriver = UIScrollView()
    private let previewDockHandle = PreviewDockHandleView()
    private var tiles: [String: ParticipantTileUIView] = [:]
    private var models: [String: CanvasTileModel] = [:]
    private var lastAppliedModels: [CanvasTileModel] = []
    private var mode = CanvasLayoutMode.grid
    private var style = CanvasTileStyle.plain
    private var previewCorner = PreviewCorner.topTrailing
    private var lastLayoutSize = CGSize.zero
    private var layoutAnimator: UIViewPropertyAnimator?
    private var orderedParticipants: [CanvasParticipant] = []
    private var suppressesStripCallback = false
    private var isDraggingPreview = false
    private var previewPresentation = PreviewPresentationState.visible
    private var previewDragRawOrigin: CGPoint?
    private var isDockTransitioning = false
    private var dockAnimator: UIViewPropertyAnimator?
    private var previewBody: PreviewMotion.Body?
    private var previewSpring = PreviewMotion.settle
    private var previewWalls = PreviewMotion.WallTravel.settled(.zero)
    private var previewMotionLink: CADisplayLink?
    private var previewMotionTimestamp: CFTimeInterval = 0
    private var videoScalingPolicyOverrides: [String: VideoScalingPolicy] = [:]
    var isReduceMotionEnabled: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    private var previewId: String? {
        models.first { $0.value.participant.isLocalPreview }?.key
    }
    private var previewFloats: Bool { previewId != nil && tiles.count > 1 }
    private var attachMargin: CGFloat { bounds.height / 3 }
    var previewControlInsets: UIEdgeInsets = .zero {
        didSet {
            guard previewControlInsets != oldValue else { return }
            let arriving = previewControlInsets.top + previewControlInsets.bottom
                > oldValue.top + oldValue.bottom
            previewSpring = arriving ? PreviewMotion.push : PreviewMotion.settle
            if case .docked = previewPresentation, previewFloats {
                previewWalls = .settled(previewControlInsets)
                layoutDockedPreview()
                return
            }
            guard previewBody != nil, !isReduceMotionEnabled() else {
                previewWalls = .settled(previewControlInsets)
                snapPreviewToRest()
                return
            }
            previewWalls = PreviewMotion.WallTravel(
                from: previewWalls.current,
                destination: previewControlInsets,
                duration: CallScreenView.Motion.chromeFadeDuration)
            startPreviewMotion()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        addSubview(scrollView)
        scrollView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(canvasTapped)))
        addGestureRecognizer(
            UIPinchGestureRecognizer(target: self, action: #selector(canvasPinched(_:))))
        configureStripDriver()
        configurePreviewDockHandle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureStripDriver() {
        stripDriver.isHidden = true
        stripDriver.showsHorizontalScrollIndicator = false
        stripDriver.contentInsetAdjustmentBehavior = .never
        stripDriver.alwaysBounceVertical = false
        stripDriver.delegate = self
        stripDriver.panGestureRecognizer.isEnabled = false
        addSubview(stripDriver)
        addGestureRecognizer(stripDriver.panGestureRecognizer)
    }

    private func configurePreviewDockHandle() {
        previewDockHandle.frame.size = PreviewDockHandleView.Metrics.hitSize
        previewDockHandle.isHidden = true
        previewDockHandle.addTarget(self, action: #selector(previewDockHandleTapped),
                                    for: .touchUpInside)
        previewDockHandle.addGestureRecognizer(UIPanGestureRecognizer(
            target: self, action: #selector(previewDockHandlePanned(_:))))
        addSubview(previewDockHandle)
    }

    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer === stripDriver.panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(recognizer)
        }
        return stripPanShouldBegin(recognizer)
    }

    private func stripPanShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard case .spotlight = mode else { return false }
        return CanvasLayout.stripBand(currentInput())
            .contains(recognizer.location(in: self))
    }

    // MARK: - Updates

    func apply(_ state: CanvasState, animated: Bool = true) {
        apply(models: state.tiles, mode: state.mode, style: state.style, animated: animated)
    }

    private func apply(models newModels: [CanvasTileModel], mode newMode: CanvasLayoutMode,
                       style newStyle: CanvasTileStyle, animated: Bool) {
        guard newMode != mode || newStyle != style
                || newModels != lastAppliedModels else { return }
        lastAppliedModels = newModels
        style = newStyle

        let newIds = Set(newModels.map(\.participant.id))

        let wasLonelyPreview = !models.isEmpty
            && models.values.allSatisfy { $0.participant.isLocalPreview }
        let remoteJoined = newModels.contains { !$0.participant.isLocalPreview }
        let answerTransition = wasLonelyPreview && remoteJoined

        for (id, tile) in tiles where !newIds.contains(id) {
            tiles[id] = nil
            models[id] = nil
            videoScalingPolicyOverrides[id] = nil
            if animated {
                UIView.animate(withDuration: Self.tileFadeDuration,
                               animations: { tile.alpha = 0 },
                               completion: { _ in tile.removeFromSuperview() })
            } else {
                tile.removeFromSuperview()
            }
        }

        var newcomers = Set<String>()
        for model in newModels {
            let id = model.participant.id
            let tile: ParticipantTileUIView
            if let existing = tiles[id] {
                tile = existing
            } else {
                tile = ParticipantTileUIView(participantId: id)
                tile.foreignGestureGate = { [weak self] recognizer in
                    guard let self = self,
                          recognizer === self.stripDriver.panGestureRecognizer else {
                        return true
                    }
                    return self.stripPanShouldBegin(recognizer)
                }
                tile.addGestureRecognizer(UILongPressGestureRecognizer(
                                            target: self, action: #selector(tileLongPressed(_:))))
                tile.onVideoScalingToggleRequested = { [weak self] in
                    self?.toggleVideoScalingPolicy(forTileId: id)
                }
                if model.participant.isLocalPreview {
                    tile.addGestureRecognizer(UITapGestureRecognizer(
                                                target: self, action: #selector(canvasTapped)))
                    tile.addGestureRecognizer(UIPanGestureRecognizer(
                                                target: self, action: #selector(previewPanned(_:))))
                    addSubview(tile)
                } else {
                    scrollView.addSubview(tile)
                }
                tiles[id] = tile
                newcomers.insert(id)
            }
            tile.apply(model.tileState)
            tile.videoView.fixedTransform = model.fixedTransform
            tile.videoView.expectedFrameSize = model.expectedVideoSize
            tile.bindAvatar(model.avatarProvider)
            models[id] = model
        }

        if let id = previewId, let previewTile = tiles[id] {
            previewTile.onPreviewHideRequested = tiles.count > 1 ? { [weak self] in
                self?.dockPreviewBesideCurrentCorner()
            } : nil
        }

        orderedParticipants = models.values.map(\.participant)
            .sorted { $0.id < $1.id }
            .sorted { !$0.isLocalPreview && $1.isLocalPreview }

        if newMode.focusId != mode.focusId {
            setStripOffsetSilently(.zero)
        }
        mode = newMode
        relayout(animated: animated, newcomers: newcomers,
                 duration: answerTransition ? Self.answerTransitionDuration
                    : Self.modeSwitchDuration)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size
        relayout(animated: false)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        relayout(animated: false)
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            stopPreviewMotion()
            stopDockAnimator()
        }
    }

    private func relayout(animated: Bool, newcomers: Set<String> = [],
                          duration: TimeInterval = ParticipantCanvas.modeSwitchDuration) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let layout = CanvasLayout.plan(currentInput())

        scrollView.isScrollEnabled = layout.scrollEnabled
        syncStripDriver(with: layout)

        for id in layout.zOrder {
            if let tile = tiles[id] {
                tile.superview?.bringSubviewToFront(tile)
            }
        }

        for id in newcomers {
            guard let tile = tiles[id], let frame = layout.frames[id] else { continue }
            tile.frame = frame
            tile.layer.cornerRadius = cornerRadius(for: id, in: layout)
            tile.contentInsets = contentInsets(for: id, in: layout)
            tile.layoutIfNeeded()
            if animated { tile.alpha = 0 }
        }
        let previewIsHeld = isDraggingPreview || previewBody != nil
            || (previewFloats && previewPresentation.isDocked)
        let held = previewIsHeld ? previewId : nil
        let applyFrames = { [self] in
            for (id, frame) in layout.frames where !newcomers.contains(id) {
                guard let tile = tiles[id] else { continue }
                if id == held {
                    tile.bounds.size = frame.size
                } else {
                    tile.frame = frame
                }
                tile.layer.cornerRadius = cornerRadius(for: id, in: layout)
                tile.contentInsets = contentInsets(for: id, in: layout)
            }
        }
        if animated {
            let target = prepareContentGeometry(for: layout.contentSize)
            retargetLayoutAnimator(duration: duration) { [self] in
                applyFrames()
                if scrollView.contentOffset != target {
                    scrollView.contentOffset = target
                }
            }
            layoutAnimator?.addCompletion { [weak self] position in
                guard position == .end else { return }
                self?.scrollView.contentSize = layout.contentSize
                self?.clampContentOffset()
            }
            UIView.animate(withDuration: Self.tileFadeDuration) { [self] in
                for id in newcomers { tiles[id]?.alpha = 1 }
            }
        } else {
            stopLayoutAnimator()
            applyFrames()
            scrollView.contentSize = layout.contentSize
            clampContentOffset()
        }
        updateVideoAttachments(frames: layout.frames, offstage: layout.offstage)
        applyVideoScalingPolicies(primaryTileId: layout.primaryTileId)
        syncPreviewMotion(animated: animated)
    }

    private func stopLayoutAnimator() {
        guard let running = layoutAnimator, running.state == .active else { return }
        running.stopAnimation(false)
        running.finishAnimation(at: .current)
    }

    private func retargetLayoutAnimator(duration: TimeInterval,
                                        animations: @escaping () -> Void) {
        stopLayoutAnimator()
        let animator = UIViewPropertyAnimator(
            duration: duration,
            timingParameters: UISpringTimingParameters(dampingRatio: 1))
        animator.addAnimations(animations)
        animator.addCompletion { [weak self] _ in
            self?.layoutAnimator = nil
        }
        layoutAnimator = animator
        animator.startAnimation()
    }

    private func prepareContentGeometry(for newSize: CGSize) -> CGPoint {
        let current = scrollView.contentSize
        scrollView.contentSize = CGSize(width: max(current.width, newSize.width),
                                        height: max(current.height, newSize.height))
        return CGPoint(
            x: min(scrollView.contentOffset.x, max(0, newSize.width - bounds.width)),
            y: min(scrollView.contentOffset.y, max(0, newSize.height - bounds.height)))
    }

    private func clampContentOffset() {
        let maxOffset = CGPoint(
            x: max(0, scrollView.contentSize.width - bounds.width),
            y: max(0, scrollView.contentSize.height - bounds.height))
        let clamped = CGPoint(x: min(max(0, scrollView.contentOffset.x), maxOffset.x),
                              y: min(max(0, scrollView.contentOffset.y), maxOffset.y))
        if clamped != scrollView.contentOffset {
            scrollView.contentOffset = clamped
        }
    }

    private func syncStripDriver(with layout: CanvasLayout.Plan) {
        let hasStrip = layout.stripContentWidth > 0
        stripDriver.panGestureRecognizer.isEnabled = hasStrip
        guard hasStrip else { return }
        let band = CanvasLayout.stripBand(currentInput())
        stripDriver.frame = band
        stripDriver.contentSize = CGSize(width: layout.stripContentWidth,
                                         height: band.height)
        let maxOffset = max(0, layout.stripContentWidth - band.width)
        if stripDriver.contentOffset.x > maxOffset {
            setStripOffsetSilently(CGPoint(x: maxOffset, y: 0))
        }
    }

    private func setStripOffsetSilently(_ offset: CGPoint) {
        suppressesStripCallback = true
        stripDriver.contentOffset = offset
        suppressesStripCallback = false
    }

    private func applyStripOffset() {
        let layout = CanvasLayout.plan(currentInput())
        let focusId = mode.focusId
        for (id, frame) in layout.frames
        where id != focusId && id != previewId && !layout.offstage.contains(id) {
            tiles[id]?.frame = frame
        }
        updateVideoAttachments(frames: layout.frames, offstage: layout.offstage)
    }

    private func contentInsets(for id: String, in layout: CanvasLayout.Plan) -> UIEdgeInsets {
        id == layout.edgeToEdgeTileId ? safeAreaInsets : .zero
    }

    private func cornerRadius(for id: String, in layout: CanvasLayout.Plan) -> CGFloat {
        if models[id]?.participant.isLocalPreview == true {
            return models.count > 1 ? CanvasLayout.tileCornerRadius : 0
        }
        guard style == .cards, id != layout.edgeToEdgeTileId else { return 0 }
        return CanvasLayout.tileCornerRadius
    }

    private func currentInput() -> CanvasLayout.Input {
        return CanvasLayout.Input(
            participants: orderedParticipants,
            mode: mode,
            canvasSize: bounds.size,
            safeAreaInsets: safeAreaInsets,
            previewCorner: previewCorner,
            stripOffset: stripDriver.contentOffset.x,
            style: style,
            previewControlInsets: previewWalls.current)
    }

    private func updateVideoAttachments(frames: [String: CGRect],
                                        offstage: Set<String>) {
        let scrollVisible = CGRect(origin: scrollView.contentOffset, size: bounds.size)
        for (id, tile) in tiles {
            guard let model = models[id], let frame = frames[id] else { continue }
            let isPreview = model.participant.isLocalPreview
            let visible = isPreview ? bounds : scrollVisible
            let shouldRender = model.tileState.showsVideo
                && !offstage.contains(id)
                && CanvasLayout.shouldRenderVideo(frame: frame, visibleRect: visible,
                                                  margin: attachMargin)
                && !(isPreview && previewIsDockedAndSettled)
            tile.videoView.attach(to: shouldRender ? model.distributor : nil)
        }
    }

    private var previewIsDockedAndSettled: Bool {
        return previewFloats && previewPresentation.isDocked && !isDockTransitioning
    }

    // MARK: - Video scaling

    private func applyVideoScalingPolicies(primaryTileId: String?) {
        for (id, tile) in tiles {
            let isPrimary = id == primaryTileId
            tile.videoView.scalingPolicy = videoScalingPolicyOverrides[id]
                ?? (isPrimary ? .automatic : .aspectFill)
            tile.canToggleVideoScaling = models[id]?.tileState.showsVideo == true
        }
    }

    private func toggleVideoScalingPolicy(forTileId id: String) {
        guard let tile = tiles[id] else { return }
        videoScalingPolicyOverrides[id] = tile.videoView.showsWholeFrame
            ? .aspectFill : .aspectFit
        applyVideoScalingPolicies(
            primaryTileId: CanvasLayout.plan(currentInput()).primaryTileId)
    }

    // MARK: - Gestures

    @objc
    private func canvasTapped() {
        onCanvasTapped?()
    }

    @objc
    private func canvasPinched(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .ended,
              let id = tileId(at: recognizer.location(in: self)),
              models[id]?.tileState.showsVideo == true else { return }
        if recognizer.scale > 1.15 {
            videoScalingPolicyOverrides[id] = .aspectFill
        } else if recognizer.scale < 0.87 {
            videoScalingPolicyOverrides[id] = .aspectFit
        } else {
            return
        }
        applyVideoScalingPolicies(
            primaryTileId: CanvasLayout.plan(currentInput()).primaryTileId)
    }

    private func tileId(at point: CGPoint) -> String? {
        let layout = CanvasLayout.plan(currentInput())
        for id in layout.zOrder.reversed()
        where !layout.offstage.contains(id) {
            guard let tile = tiles[id] else { continue }
            if tile.convert(tile.bounds, to: self).contains(point) { return id }
        }
        return nil
    }

    @objc
    private func tileLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let tile = recognizer.view as? ParticipantTileUIView else { return }
        onTileLongPressed?(tile.participantId)
    }

    @objc
    private func previewPanned(_ recognizer: UIPanGestureRecognizer) {
        guard previewFloats, previewPresentation == .visible,
              let tile = recognizer.view else { return }

        switch recognizer.state {
        case .began:
            isDraggingPreview = true
            stopLayoutAnimator()
            stopDockAnimator()
            previewDragRawOrigin = previewOrigin(of: tile)
            previewDockHandle.isHidden = true
            seedPreviewBody()
        case .changed:
            isDraggingPreview = true
            let translation = recognizer.translation(in: self)
            recognizer.setTranslation(.zero, in: self)
            let current = previewDragRawOrigin ?? previewOrigin(of: tile)
            let dragged = CGPoint(x: current.x + translation.x,
                                  y: current.y + translation.y)
            previewDragRawOrigin = dragged
            let origin = dockAwarePreviewOrigin(for: dragged)
            previewBody = PreviewMotion.Body(position: origin)
            movePreview(tile, to: origin)
        case .ended:
            isDraggingPreview = false
            let velocity = recognizer.velocity(in: self)
            if let dragged = previewDragRawOrigin,
               let overshoot = previewOvershoot(for: dragged),
               PreviewDocking.shouldDock(
                outwardDistance: overshoot.distance,
                outwardVelocity: overshoot.side.outwardComponent(of: velocity.x),
                previewWidth: tile.bounds.width) {
                dockPreview(to: overshoot.side, animated: true, velocity: velocity)
            } else {
                previewDockHandle.isHidden = true
                releasePreview(tile, velocity: velocity)
            }
            previewDragRawOrigin = nil
        case .cancelled, .failed:
            isDraggingPreview = false
            previewDragRawOrigin = nil
            previewDockHandle.isHidden = true
            releasePreview(tile, velocity: .zero)
        default:
            break
        }
    }

    private struct PreviewOvershoot {
        let side: PreviewDockSide
        let distance: CGFloat
    }

    private func previewOvershoot(for dragged: CGPoint) -> PreviewOvershoot? {
        let travel = previewTravelBounds()
        if dragged.x < travel.minX {
            return PreviewOvershoot(side: .left, distance: travel.minX - dragged.x)
        }
        if dragged.x > travel.maxX {
            return PreviewOvershoot(side: .right, distance: dragged.x - travel.maxX)
        }
        return nil
    }

    private func dockAwarePreviewOrigin(for dragged: CGPoint) -> CGPoint {
        let travel = previewTravelBounds()
        let clampedY = PreviewMotion.clamp(dragged, within: travel).y
        guard let overshoot = previewOvershoot(for: dragged) else {
            return CGPoint(x: dragged.x, y: clampedY)
        }
        let edgeX = overshoot.side == .left ? travel.minX : travel.maxX
        let rubberBanded = PreviewDocking.rubberBanded(overshoot.distance,
                                                       dimension: bounds.width)
        return CGPoint(x: edgeX + overshoot.side.outwardComponent(of: rubberBanded),
                       y: clampedY)
    }

    private func releasePreview(_ tile: UIView, velocity: CGPoint) {
        previewCorner = PreviewCorner(isTop: tile.center.y < bounds.midY,
                                      isLeading: tile.center.x < bounds.midX)
        previewSpring = PreviewMotion.fling
        previewBody = PreviewMotion.Body(
            position: tile.frame.origin,
            velocity: CGVector(dx: velocity.x, dy: velocity.y))
        startPreviewMotion()
    }

    // MARK: - Preview docking

    func dockPreview(to side: PreviewDockSide, animated: Bool = true,
                     velocity: CGPoint = .zero) {
        guard previewFloats, let id = previewId, let tile = tiles[id] else { return }
        stopPreviewMotion()
        stopDockAnimator()
        previewCorner = PreviewCorner(isTop: tile.center.y < bounds.midY,
                                      isLeading: side == .left)
        settleDockedPreview(to: side, animated: animated, velocity: velocity)
    }

    func settleDockedPreview(to side: PreviewDockSide, animated: Bool = true,
                             velocity: CGPoint = .zero) {
        guard previewFloats, let id = previewId, let tile = tiles[id] else { return }
        stopPreviewMotion()
        stopDockAnimator()
        isDraggingPreview = false
        previewCorner = PreviewCorner(isTop: previewCorner.isTop, isLeading: side == .left)
        previewPresentation = .docked(side)
        isDockTransitioning = true
        tile.isAccessibilityElement = false

        previewDockHandle.configure(side: side)
        previewDockHandle.isHidden = false

        let target = dockedPreviewOrigin(for: side, tile: tile)
        guard animated else {
            previewBody = nil
            movePreview(tile, to: target)
            positionDockHandle(side: side, previewOrigin: target, tile: tile)
            finishDocking(tile: tile)
            return
        }
        guard isReduceMotionEnabled() else {
            springPreview(tile, side: side, velocity: velocity)
            return
        }
        previewBody = nil
        tile.alpha = 0
        movePreview(tile, to: target)
        positionDockHandle(side: side, previewOrigin: target, tile: tile)
        previewDockHandle.alpha = 0
        fadePreviewTransition(
            tile: tile,
            animations: { [weak self] in self?.previewDockHandle.alpha = 1 },
            completion: { [weak self] tile in self?.finishDocking(tile: tile) })
    }

    func restorePreview(animated: Bool = true, velocity: CGPoint = .zero) {
        guard case .docked(let side) = previewPresentation,
              previewFloats, let id = previewId, let tile = tiles[id],
              let model = models[id] else { return }
        stopDockAnimator()
        stopPreviewMotion()
        isDockTransitioning = true
        previewCorner = PreviewCorner(isTop: previewCorner.isTop, isLeading: side == .left)
        previewPresentation = .visible
        tile.isAccessibilityElement = true
        tile.videoView.attach(to: model.tileState.showsVideo ? model.distributor : nil)
        let target = previewRestOrigin()

        guard animated else {
            movePreview(tile, to: target)
            finishRestoring(tile: tile, target: target)
            return
        }
        guard isReduceMotionEnabled() else {
            tile.alpha = 1
            springPreview(tile, side: side, velocity: velocity)
            return
        }
        previewBody = nil
        positionDockHandle(side: side, previewOrigin: previewOrigin(of: tile), tile: tile)
        movePreview(tile, to: target)
        tile.alpha = 0
        fadePreviewTransition(
            tile: tile,
            animations: { [weak self, weak tile] in
                tile?.alpha = 1
                self?.previewDockHandle.alpha = 0
            },
            completion: { [weak self] tile in
                self?.finishRestoring(tile: tile, target: target)
            })
    }

    private func springPreview(_ tile: UIView, side: PreviewDockSide, velocity: CGPoint) {
        previewSpring = PreviewMotion.fling
        let origin = previewOrigin(of: tile)
        previewBody = PreviewMotion.Body(
            position: origin,
            velocity: CGVector(dx: velocity.x, dy: velocity.y))
        positionDockHandle(side: side, previewOrigin: origin, tile: tile)
        startPreviewMotion()
    }

    private func fadePreviewTransition(
        tile: ParticipantTileUIView,
        animations: @escaping () -> Void,
        completion: @escaping (ParticipantTileUIView) -> Void) {
        let expected = previewPresentation
        let animator = UIViewPropertyAnimator(duration: Self.dockFadeDuration,
                                              curve: .easeInOut,
                                              animations: animations)
        animator.addCompletion { [weak self, weak tile] position in
            guard position == .end, let self = self, let tile = tile,
                  self.previewFloats, self.previewPresentation == expected else { return }
            completion(tile)
        }
        dockAnimator = animator
        animator.startAnimation()
    }

    private func dockPreviewBesideCurrentCorner() {
        dockPreview(to: previewCorner.isLeading ? .left : .right)
    }

    private func finishDocking(tile: ParticipantTileUIView) {
        isDockTransitioning = false
        if case .docked(let side) = previewPresentation {
            positionDockHandle(side: side,
                               previewOrigin: dockedPreviewOrigin(for: side, tile: tile),
                               tile: tile)
        }
        previewDockHandle.alpha = 1
        tile.isAccessibilityElement = false
        tile.videoView.attach(to: nil)
        previewBody = nil
        dockAnimator = nil
    }

    private func finishRestoring(tile: ParticipantTileUIView, target: CGPoint) {
        tile.alpha = 1
        previewDockHandle.alpha = 1
        previewDockHandle.isHidden = true
        isDockTransitioning = false
        previewBody = PreviewMotion.Body(position: target)
        dockAnimator = nil
        updateCurrentVideoAttachments()
    }

    private func stopDockAnimator() {
        guard let animator = dockAnimator else { return }
        animator.stopAnimation(false)
        animator.finishAnimation(at: .current)
        dockAnimator = nil
        reconcilePreviewPresentation()
    }

    private func reconcilePreviewPresentation() {
        isDockTransitioning = false
        isDraggingPreview = false
        previewBody = nil

        switch previewPresentation {
        case .docked:
            layoutDockedPreview()
        case .visible:
            previewDockHandle.alpha = 1
            previewDockHandle.isHidden = true
            guard previewFloats, let id = previewId, let tile = tiles[id] else {
                updateCurrentVideoAttachments()
                return
            }
            let target = previewRestOrigin()
            tile.alpha = 1
            tile.isAccessibilityElement = true
            movePreview(tile, to: target)
            previewBody = PreviewMotion.Body(position: target)
            updateCurrentVideoAttachments()
        }
    }

    private func dockedPreviewOrigin(for side: PreviewDockSide, tile: UIView) -> CGPoint {
        let compactedInset = tile.bounds.width * (1 - previewScale) / 2
        let horizontalOrigin: CGFloat = side == .left
            ? bounds.minX - tile.bounds.width + compactedInset - 1
            : bounds.maxX - compactedInset + 1
        return CGPoint(x: horizontalOrigin,
                       y: dockedPreviewVerticalOrigin(height: tile.bounds.height))
    }

    private func dockedPreviewVerticalOrigin(height: CGFloat) -> CGFloat {
        let preferred = previewCorner.isTop
            ? safeAreaInsets.top + CanvasLayout.previewPadding
            : bounds.height - safeAreaInsets.bottom - CanvasLayout.previewPadding - height
        return clampedDockY(preferred, height: height)
    }

    private func clampedDockY(_ preferred: CGFloat, height: CGFloat) -> CGFloat {
        let minimum = safeAreaInsets.top + CanvasLayout.previewPadding
        let maximum = bounds.height - safeAreaInsets.bottom
            - CanvasLayout.previewPadding - height
        return min(max(minimum, preferred), max(minimum, maximum))
    }

    private func layoutDockedPreview() {
        guard case .docked(let side) = previewPresentation,
              previewFloats, let id = previewId, let tile = tiles[id] else {
            previewDockHandle.isHidden = true
            return
        }
        let origin = dockedPreviewOrigin(for: side, tile: tile)
        previewDockHandle.configure(side: side)
        previewDockHandle.isHidden = false
        movePreview(tile, to: origin)
        positionDockHandle(side: side, previewOrigin: origin, tile: tile)
        previewDockHandle.alpha = 1
        tile.isAccessibilityElement = false
        if !isDockTransitioning { tile.videoView.attach(to: nil) }
    }

    private func previewVisualRect(origin: CGPoint, tile: UIView) -> CGRect {
        let inset = (1 - previewScale) / 2
        return CGRect(origin: origin, size: tile.bounds.size)
            .insetBy(dx: tile.bounds.width * inset, dy: tile.bounds.height * inset)
    }

    private func positionDockHandle(side: PreviewDockSide,
                                    previewOrigin: CGPoint,
                                    tile: UIView) {
        let size = PreviewDockHandleView.Metrics.hitSize
        let visual = previewVisualRect(origin: previewOrigin, tile: tile)
        var origin = PreviewDocking.handleOrigin(for: side,
                                                 previewVisualRect: visual,
                                                 hitSize: size)
        origin.y = clampedDockY(origin.y, height: size.height)
        previewDockHandle.frame = CGRect(origin: origin, size: size)
        bringSubviewToFront(previewDockHandle)
        previewDockHandle.alpha = isDockTransitioning
            ? dockHandleFade(side: side, previewOrigin: previewOrigin, tile: tile)
            : 1
    }

    private func dockHandleFade(side: PreviewDockSide,
                                previewOrigin: CGPoint,
                                tile: UIView) -> CGFloat {
        let docked = dockedPreviewOrigin(for: side, tile: tile)
        let travel = previewTravelBounds()
        let edgeX = side == .left ? travel.minX : travel.maxX
        let span = max(abs(edgeX - docked.x), 1)
        let distanceFromDock = abs(previewOrigin.x - docked.x)
        return max(0, 1 - min(distanceFromDock / span, 1))
    }

    @objc
    private func previewDockHandleTapped() {
        restorePreview()
    }

    @objc
    private func previewDockHandlePanned(_ recognizer: UIPanGestureRecognizer) {
        guard case .docked(let side) = previewPresentation,
              previewFloats, let id = previewId, let tile = tiles[id],
              let model = models[id] else { return }

        switch recognizer.state {
        case .began:
            stopDockAnimator()
            stopPreviewMotion()
            previewBody = nil
            isDockTransitioning = true
            tile.alpha = 1
            tile.videoView.attach(to: model.tileState.showsVideo ? model.distributor : nil)
        case .changed:
            let base = dockedPreviewOrigin(for: side, tile: tile)
            let travel = min(restoreDistance(of: recognizer, side: side),
                             tile.bounds.width + CanvasLayout.previewPadding)
            let origin = CGPoint(x: base.x + side.inwardComponent(of: travel), y: base.y)
            movePreview(tile, to: origin)
            positionDockHandle(side: side, previewOrigin: origin, tile: tile)
        case .ended:
            let velocity = recognizer.velocity(in: self)
            if PreviewDocking.shouldRestore(
                inwardDistance: restoreDistance(of: recognizer, side: side),
                inwardVelocity: side.inwardComponent(of: velocity.x)) {
                restorePreview(velocity: velocity)
            } else {
                settleDockedPreview(to: side, velocity: velocity)
            }
        case .cancelled, .failed:
            settleDockedPreview(to: side)
        default:
            break
        }
    }

    private func restoreDistance(of recognizer: UIPanGestureRecognizer,
                                 side: PreviewDockSide) -> CGFloat {
        return max(0, side.inwardComponent(of: recognizer.translation(in: self).x))
    }

    private func updateCurrentVideoAttachments() {
        let layout = CanvasLayout.plan(currentInput())
        updateVideoAttachments(frames: layout.frames, offstage: layout.offstage)
    }

    // MARK: - Preview motion

    private func syncPreviewMotion(animated: Bool) {
        guard previewFloats else {
            previewBody = nil
            stopPreviewMotion()
            stopDockAnimator()
            isDockTransitioning = false
            previewDockHandle.isHidden = true
            if let id = previewId, let tile = tiles[id] {
                if let frame = CanvasLayout.plan(currentInput()).frames[id] {
                    tile.frame = frame
                }
                tile.alpha = 1
                tile.isAccessibilityElement = true
                tile.layer.transform = CATransform3DIdentity
            }
            return
        }
        if case .docked = previewPresentation {
            if isDockTransitioning, previewBody != nil {
                startPreviewMotion()
                return
            }
            if !isDockTransitioning {
                previewBody = nil
                stopPreviewMotion()
                layoutDockedPreview()
            }
            return
        }
        previewDockHandle.isHidden = true
        guard previewBody == nil else {
            startPreviewMotion()
            return
        }
        if animated, let animator = layoutAnimator {
            animator.addCompletion { [weak self] position in
                guard position == .end else { return }
                self?.seedPreviewBody()
            }
        } else {
            seedPreviewBody()
        }
    }

    private func seedPreviewBody() {
        guard previewFloats, let id = previewId, let tile = tiles[id] else { return }
        previewBody = PreviewMotion.Body(position: tile.frame.origin)
    }

    private func snapPreviewToRest() {
        guard previewFloats, let id = previewId, let tile = tiles[id] else { return }
        stopPreviewMotion()
        let body = PreviewMotion.settled(at: previewRestOrigin(),
                                         within: previewTravelBounds())
        previewBody = body
        movePreview(tile, to: body.position)
    }

    private func previewRestOrigin() -> CGPoint {
        return CanvasLayout.previewOrigin(
            for: previewCorner,
            in: CGRect(origin: .zero, size: bounds.size),
            safeAreaInsets: safeAreaInsets,
            controlInsets: previewWalls.current)
    }

    private func previewTravelBounds() -> CGRect {
        return CanvasLayout.previewOriginBounds(
            in: CGRect(origin: .zero, size: bounds.size),
            safeAreaInsets: safeAreaInsets,
            controlInsets: previewWalls.current)
    }

    private func movePreview(_ tile: UIView, to origin: CGPoint) {
        tile.center = CGPoint(x: origin.x + tile.bounds.width / 2,
                              y: origin.y + tile.bounds.height / 2)
        tile.layer.transform = CATransform3DMakeScale(previewScale, previewScale, 1)
    }

    private var previewScale: CGFloat {
        return 1 - (1 - CanvasLayout.previewCompactScale)
            * previewWalls.chromePresence
    }

    private func previewOrigin(of tile: UIView) -> CGPoint {
        return CGPoint(x: tile.center.x - tile.bounds.width / 2,
                       y: tile.center.y - tile.bounds.height / 2)
    }

    private func startPreviewMotion() {
        guard previewMotionLink == nil else { return }
        let link = CADisplayLink(target: self,
                                 selector: #selector(advancePreviewMotion(_:)))
        link.add(to: .main, forMode: .common)
        previewMotionTimestamp = CACurrentMediaTime()
        previewMotionLink = link
    }

    private func stopPreviewMotion() {
        previewMotionLink?.invalidate()
        previewMotionLink = nil
    }

    @objc
    private func advancePreviewMotion(_ link: CADisplayLink) {
        let interval = min(max(0, link.timestamp - previewMotionTimestamp),
                           Self.maximumPreviewMotionInterval)
        previewMotionTimestamp = link.timestamp
        previewWalls.advance(by: interval)

        guard let id = previewId, let tile = tiles[id], var body = previewBody else {
            stopPreviewMotion()
            return
        }
        if isDraggingPreview {
            body.position = dockAwarePreviewOrigin(
                for: previewDragRawOrigin ?? body.position)
            previewBody = body
            movePreview(tile, to: body.position)
            if previewWalls.isFinished { stopPreviewMotion() }
            return
        }

        let attractor: CGPoint
        if case .docked(let side) = previewPresentation, isDockTransitioning {
            attractor = dockedPreviewOrigin(for: side, tile: tile)
        } else {
            attractor = previewRestOrigin()
        }
        let walls = isDockTransitioning
            ? previewMotionWalls(spanning: attractor, body.position)
            : previewTravelBounds()

        body = PreviewMotion.step(body, toward: attractor, within: walls,
                                  spring: previewSpring, interval: CGFloat(interval))
        if isDockTransitioning, let side = dockSideForMotion {
            positionDockHandle(side: side, previewOrigin: body.position, tile: tile)
        }

        if previewWalls.isFinished, PreviewMotion.isAtRest(body, at: attractor) {
            body = PreviewMotion.settled(at: attractor, within: walls)
            stopPreviewMotion()
            previewBody = body
            movePreview(tile, to: body.position)
            if isDockTransitioning {
                switch previewPresentation {
                case .docked:
                    finishDocking(tile: tile)
                case .visible:
                    finishRestoring(tile: tile, target: attractor)
                }
            }
            return
        }
        previewBody = body
        movePreview(tile, to: body.position)
    }

    private var dockSideForMotion: PreviewDockSide? {
        switch previewPresentation {
        case .docked(let side):
            return side
        case .visible where isDockTransitioning:
            return previewCorner.isLeading ? .left : .right
        default:
            return nil
        }
    }

    private func previewMotionWalls(spanning first: CGPoint, _ second: CGPoint) -> CGRect {
        let travel = previewTravelBounds()
        let minX = min(travel.minX, first.x, second.x)
        let maxX = max(travel.maxX, first.x, second.x)
        let minY = min(travel.minY, first.y, second.y)
        let maxY = max(travel.maxY, first.y, second.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

}

// MARK: - Preview corner geometry

extension ParticipantCanvas {
    static let maximumPreviewMotionInterval: CFTimeInterval = 1.0 / 20.0
    static let dockFadeDuration: TimeInterval = 0.18
}

// MARK: - UIScrollViewDelegate

extension ParticipantCanvas: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === stripDriver {
            guard !suppressesStripCallback else { return }
            applyStripOffset()
        } else {
            updateCurrentVideoAttachments()
        }
    }
}
