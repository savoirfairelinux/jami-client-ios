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
    var tileState: ParticipantTileState
    var distributor: FrameDistributor?
    var fixedTransform: CGAffineTransform?
    var avatarProvider: AvatarProvider?
    var expectedVideoSize: CGSize?
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

final class ParticipantCanvas: UIView {

    var onCanvasTapped: (() -> Void)?
    var onTileLongPressed: ((String) -> Void)?

    static let modeSwitchDuration: TimeInterval = 0.35
    static let answerTransitionDuration: TimeInterval = 0.5
    static let tileFadeDuration: TimeInterval = 0.25

    private let scrollView = UIScrollView()
    private let stripDriver = UIScrollView()
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
    private var previewFlingAnimator: UIViewPropertyAnimator?
    private var videoScalingPolicyOverrides: [String: VideoScalingPolicy] = [:]
    private var previewInteracting: Bool {
        isDraggingPreview || previewFlingAnimator?.isRunning == true
    }
    private var previewId: String? {
        models.first { $0.value.participant.isLocalPreview }?.key
    }
    private var attachMargin: CGFloat { bounds.height / 3 }

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

    func apply(models newModels: [CanvasTileModel], mode newMode: CanvasLayoutMode,
               style newStyle: CanvasTileStyle = .plain, animated: Bool = true) {
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
                    tile.addGestureRecognizer(UIPanGestureRecognizer(
                                                target: self, action: #selector(previewPanned(_:))))
                }
                scrollView.addSubview(tile)
                tiles[id] = tile
                newcomers.insert(id)
            }
            tile.apply(model.tileState)
            tile.videoView.fixedTransform = model.fixedTransform
            tile.videoView.expectedFrameSize = model.expectedVideoSize
            tile.bindAvatar(model.avatarProvider)
            models[id] = model
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

    private func relayout(animated: Bool, newcomers: Set<String> = [],
                          duration: TimeInterval = ParticipantCanvas.modeSwitchDuration) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let layout = CanvasLayout.plan(currentInput())

        scrollView.isScrollEnabled = layout.scrollEnabled
        syncStripDriver(with: layout)

        for id in layout.zOrder {
            if let tile = tiles[id] {
                scrollView.bringSubviewToFront(tile)
            }
        }

        for id in newcomers {
            guard let tile = tiles[id], let frame = layout.frames[id] else { continue }
            tile.frame = frame
            tile.layer.cornerRadius = cornerRadius(for: id)
            tile.contentInsets = contentInsets(for: id)
            tile.layoutIfNeeded()
            if animated { tile.alpha = 0 }
        }
        let held = previewInteracting ? previewId : nil
        let applyFrames = { [self] in
            for (id, frame) in layout.frames where !newcomers.contains(id) && id != held {
                tiles[id]?.frame = frame
                tiles[id]?.layer.cornerRadius = cornerRadius(for: id)
                tiles[id]?.contentInsets = contentInsets(for: id)
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

    private func contentInsets(for id: String) -> UIEdgeInsets {
        guard case .fullscreen(let focusId) = mode, focusId == id else { return .zero }
        return safeAreaInsets
    }

    private func cornerRadius(for id: String) -> CGFloat {
        if models[id]?.participant.isLocalPreview == true {
            return models.count > 1 ? CanvasLayout.tileCornerRadius : 0
        }
        guard style == .cards else { return 0 }
        if case .fullscreen(let focusId) = mode, focusId == id { return 0 }
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
            style: style)
    }

    private func updateVideoAttachments(frames: [String: CGRect],
                                        offstage: Set<String>) {
        let visible = CGRect(origin: scrollView.contentOffset, size: bounds.size)
        for (id, tile) in tiles {
            guard let model = models[id], let frame = frames[id] else { continue }
            let shouldRender = model.tileState.showsVideo
                && !offstage.contains(id)
                && CanvasLayout.shouldRenderVideo(frame: frame, visibleRect: visible,
                                                  margin: attachMargin)
            tile.videoView.attach(to: shouldRender ? model.distributor : nil)
        }
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
              let id = tileId(at: recognizer.location(in: scrollView)),
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
        where layout.frames[id]?.contains(point) == true
            && !layout.offstage.contains(id) {
            return id
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
        guard tiles.count > 1, let tile = recognizer.view else { return }

        switch recognizer.state {
        case .began:
            isDraggingPreview = true
            previewFlingAnimator?.stopAnimation(true)
            previewFlingAnimator = nil
        case .changed:
            isDraggingPreview = true
            let translation = recognizer.translation(in: scrollView)
            recognizer.setTranslation(.zero, in: scrollView)
            var origin = tile.frame.origin
            origin.x = min(max(0, origin.x + translation.x),
                           bounds.width - tile.frame.width)
            origin.y = min(max(0, origin.y + translation.y),
                           bounds.height - tile.frame.height)
            tile.frame.origin = origin
        case .ended, .cancelled, .failed:
            isDraggingPreview = false
            flingPreview(tile, velocity: recognizer.velocity(in: scrollView))
        default:
            break
        }
    }

    private func flingPreview(_ tile: UIView, velocity: CGPoint) {
        let corner = Self.nearestCorner(toCenter: tile.center, in: bounds)
        previewCorner = corner
        let origin = CanvasLayout.previewOrigin(
            for: corner, in: CGRect(origin: .zero, size: bounds.size),
            safeAreaInsets: safeAreaInsets)
        let target = CGRect(origin: origin,
                            size: CanvasLayout.previewSize(for: bounds.size))

        let initialVelocity = Self.springVelocity(from: velocity,
                                                  current: tile.frame.origin,
                                                  target: origin)
        let timing = UISpringTimingParameters(dampingRatio: 0.7,
                                              initialVelocity: initialVelocity)
        let animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: timing)
        animator.addAnimations { tile.frame = target }
        animator.addCompletion { [weak self] _ in
            self?.previewFlingAnimator = nil
        }
        previewFlingAnimator = animator
        animator.startAnimation()
    }

}

// MARK: - Preview fling geometry

extension ParticipantCanvas {
    static func nearestCorner(toCenter center: CGPoint, in bounds: CGRect) -> PreviewCorner {
        let top = center.y < bounds.midY
        let leading = center.x < bounds.midX
        switch (top, leading) {
        case (true, true): return .topLeading
        case (true, false): return .topTrailing
        case (false, true): return .bottomLeading
        case (false, false): return .bottomTrailing
        }
    }

    static func springVelocity(from velocity: CGPoint,
                               current: CGPoint, target: CGPoint) -> CGVector {
        let horizontalDistance = target.x - current.x
        let verticalDistance = target.y - current.y
        return CGVector(dx: abs(horizontalDistance) > 0.001
                            ? velocity.x / horizontalDistance : 0,
                        dy: abs(verticalDistance) > 0.001
                            ? velocity.y / verticalDistance : 0)
    }
}

// MARK: - UIScrollViewDelegate

extension ParticipantCanvas: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === stripDriver {
            guard !suppressesStripCallback else { return }
            applyStripOffset()
        } else {
            let layout = CanvasLayout.plan(currentInput())
            updateVideoAttachments(frames: layout.frames, offstage: layout.offstage)
        }
    }
}
