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
import Combine

struct ParticipantTileState: Equatable {
    let showsVideo: Bool
    let showsName: Bool
    let isAudioMuted: Bool
    let isHandRaised: Bool
    let isSpeaking: Bool

    init(showsVideo: Bool = false,
         showsName: Bool = false,
         isAudioMuted: Bool = false,
         isHandRaised: Bool = false,
         isSpeaking: Bool = false) {
        self.showsVideo = showsVideo
        self.showsName = showsName
        self.isAudioMuted = isAudioMuted
        self.isHandRaised = isHandRaised
        self.isSpeaking = isSpeaking
    }
}

final class ParticipantTileUIView: UIView {

    private enum Metrics {
        static let audioOnlyAvatarLiftRatio: CGFloat = 1.0 / 6.0
        static let nameHorizontalPadding: CGFloat = 8
        static let nameVerticalPadding: CGFloat = 3
        static let nameEdgeMargin: CGFloat = 8
        static let nameBottomMargin: CGFloat = 6
    }

    let participantId: String
    let videoView = RendererLayerView()

    var foreignGestureGate: ((UIGestureRecognizer) -> Bool)?
    var onVideoScalingToggleRequested: (() -> Void)?
    var onPreviewHideRequested: (() -> Void)? {
        didSet { syncAccessibilityActions() }
    }

    var canToggleVideoScaling = false {
        didSet {
            guard canToggleVideoScaling != oldValue else { return }
            syncAccessibilityActions()
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view !== self, let gate = foreignGestureGate {
            return gate(gestureRecognizer)
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    private let avatarView = CallAvatarView()
    private let backdropLayer = CAGradientLayer()
    private let nameLabel = UILabel()
    private let namePlate = UIView()

    private var avatarWidth: NSLayoutConstraint!
    private var avatarHeight: NSLayoutConstraint!
    private var avatarCenterY: NSLayoutConstraint!
    private var nameLeading: NSLayoutConstraint!
    private var nameBottom: NSLayoutConstraint!
    private var nameTrailing: NSLayoutConstraint!

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            guard contentInsets != oldValue else { return }
            applyContentInsets()
        }
    }
    private var nameCancellable: AnyCancellable?
    private var backdropCancellable: AnyCancellable?
    private var backdropSource: (name: String, avatar: UIImage?)?
    private weak var boundProvider: AvatarProvider?

    private(set) var tileState = ParticipantTileState()

    init(participantId: String) {
        self.participantId = participantId
        super.init(frame: .zero)
        configureSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureSubviews() {
        clipsToBounds = true
        backgroundColor = .jamiCallBackdrop
        isAccessibilityElement = true
        accessibilityTraits = .image
        if participantId == CanvasParticipant.localId {
            accessibilityLabel = L10n.Accessibility.Conference.localPreview
        }

        backdropLayer.type = .radial
        backdropLayer.locations = IdentityBackdrop.Geometry.locations
        backdropLayer.isHidden = true
        layer.insertSublayer(backdropLayer, at: 0)

        videoView.frame = bounds
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.onVideoContentChanged = { [weak self] _ in
            self?.syncAvatarVisibility(animated: true)
        }
        videoView.onWholeFrameDisplayChanged = { [weak self] _ in
            self?.syncAccessibilityActions()
        }
        addSubview(videoView)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(avatarView)

        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOpacity = 0.8
        nameLabel.layer.shadowRadius = 2
        nameLabel.layer.shadowOffset = .zero
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        namePlate.backgroundColor = .jamiOnVideoScrim
        namePlate.clipsToBounds = true
        namePlate.translatesAutoresizingMaskIntoConstraints = false
        namePlate.addSubview(nameLabel)
        addSubview(namePlate)

        avatarWidth = avatarView.widthAnchor.constraint(equalToConstant: 72)
        avatarHeight = avatarView.heightAnchor.constraint(equalToConstant: 72)
        avatarCenterY = avatarView.centerYAnchor.constraint(
            equalTo: centerYAnchor,
            constant: 0)
        nameLeading = namePlate.leadingAnchor.constraint(
            equalTo: leadingAnchor, constant: Metrics.nameEdgeMargin)
        nameBottom = namePlate.bottomAnchor.constraint(
            equalTo: bottomAnchor, constant: -Metrics.nameBottomMargin)
        nameTrailing = namePlate.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor,
                                                           constant: -Metrics.nameEdgeMargin)
        NSLayoutConstraint.activate([
            avatarView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarCenterY,
            avatarWidth, avatarHeight,
            nameLeading, nameBottom, nameTrailing,
            nameLabel.leadingAnchor.constraint(equalTo: namePlate.leadingAnchor,
                                               constant: Metrics.nameHorizontalPadding),
            nameLabel.trailingAnchor.constraint(equalTo: namePlate.trailingAnchor,
                                                constant: -Metrics.nameHorizontalPadding),
            nameLabel.topAnchor.constraint(equalTo: namePlate.topAnchor,
                                           constant: Metrics.nameVerticalPadding),
            nameLabel.bottomAnchor.constraint(equalTo: namePlate.bottomAnchor,
                                              constant: -Metrics.nameVerticalPadding)
        ])
    }

    private func applyContentInsets() {
        let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let leadingInset = rightToLeft ? contentInsets.right : contentInsets.left
        let trailingInset = rightToLeft ? contentInsets.left : contentInsets.right
        nameLeading.constant = leadingInset + Metrics.nameEdgeMargin
        nameBottom.constant = -(contentInsets.bottom + Metrics.nameBottomMargin)
        nameTrailing.constant = -(trailingInset + Metrics.nameEdgeMargin)
    }

    override func layoutSubviews() {
        let side = CallParticipantAvatars.avatarSize(forTileSide: min(bounds.width, bounds.height))
        if avatarWidth.constant != side {
            avatarWidth.constant = side
            avatarHeight.constant = side
        }
        let avatarLift = tileState.showsVideo
            ? 0 : side * Metrics.audioOnlyAvatarLiftRatio
        if avatarCenterY.constant != -avatarLift {
            avatarCenterY.constant = -avatarLift
        }
        super.layoutSubviews()
        syncBackdropGeometry()
        namePlate.layer.cornerRadius = namePlate.bounds.height / 2
        layer.borderWidth = tileState.isSpeaking ? 2 : 0
    }

    func apply(_ state: ParticipantTileState) {
        let losesVideo = tileState.showsVideo && !state.showsVideo && !videoView.isHidden
        let videoAvailabilityChanged = tileState.showsVideo != state.showsVideo
        tileState = state
        if videoAvailabilityChanged { setNeedsLayout() }
        nameLabel.isHidden = !state.showsName
        namePlate.isHidden = !state.showsName
        if state.showsVideo { videoView.isHidden = false }
        syncAvatarVisibility(animated: losesVideo)
        layer.borderColor = UIColor.systemGreen.cgColor
        layer.borderWidth = state.isSpeaking ? 2 : 0
    }

    func bindAvatar(_ provider: AvatarProvider?) {
        avatarView.bind(provider)
        guard provider !== boundProvider else { return }
        boundProvider = provider
        guard let provider = provider else {
            nameCancellable = nil
            backdropCancellable = nil
            clearBackdrop()
            return
        }
        backdropSource = nil
        backdropCancellable = provider.$profileName
            .combineLatest(provider.$isAvatarResolved, provider.$avatar)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name, isResolved, avatar in
                self?.applyBackdrop(name: name, avatar: avatar, isResolved: isResolved)
            }
        let isLocalParticipant = provider.isLocalParticipant
        nameCancellable = provider.$profileName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                guard let self = self else { return }
                let displayName = isLocalParticipant ? name.withYourselfSuffix() : name
                self.nameLabel.text = displayName
                self.accessibilityLabel = displayName
                self.setNeedsLayout()
            }
    }

    var showsAvatarPlaceholder: Bool {
        !avatarView.isHidden && avatarView.alpha > 0.5
    }

    var displayedName: String? { nameLabel.isHidden ? nil : nameLabel.text }

    var nameChipFrame: CGRect? { namePlate.isHidden ? nil : namePlate.frame }

    var nameTextFrame: CGRect? {
        namePlate.isHidden ? nil : namePlate.convert(nameLabel.frame, to: self)
    }

    private func applyBackdrop(name: String, avatar: UIImage?, isResolved: Bool) {
        guard isResolved else {
            clearBackdrop()
            return
        }
        if isBackdropCurrent(name: name, avatar: avatar) { return }
        backdropSource = (name, avatar)

        guard let avatar = avatar else {
            setBackdrop(IdentityBackdrop.monogramTint(forName: name))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tint = IdentityBackdrop.photoTint(for: avatar)
                ?? IdentityBackdrop.monogramTint(forName: name)
            DispatchQueue.main.async {
                guard let self = self, self.backdropSource?.avatar === avatar else { return }
                self.setBackdrop(tint)
            }
        }
    }

    private func isBackdropCurrent(name: String, avatar: UIImage?) -> Bool {
        guard let source = backdropSource, source.avatar === avatar else { return false }
        return avatar != nil || source.name == name
    }

    private func clearBackdrop() {
        backdropSource = nil
        setBackdrop(nil)
    }

    private func syncBackdropGeometry() {
        let mirrored = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let (start, end) = IdentityBackdrop.Geometry.points(mirrored: mirrored)

        guard backdropLayer.frame != bounds
                || backdropLayer.startPoint != start
                || backdropLayer.endPoint != end else { return }

        withoutImplicitAnimation {
            backdropLayer.frame = bounds
            backdropLayer.startPoint = start
            backdropLayer.endPoint = end
        }
    }

    private func setBackdrop(_ tint: UIColor?) {
        withoutImplicitAnimation {
            backdropLayer.colors = tint.map(IdentityBackdrop.gradientColors)
        }
        syncBackdropVisibility()
    }

    private func syncBackdropVisibility() {
        setBackdropHidden(backdropLayer.colors == nil || backdropLayer.opacity == 0)
    }

    private func setBackdropHidden(_ hidden: Bool) {
        guard backdropLayer.isHidden != hidden else { return }
        withoutImplicitAnimation { backdropLayer.isHidden = hidden }
    }

    private func withoutImplicitAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    private func syncAvatarVisibility(animated: Bool) {
        let showsContent = tileState.showsVideo && videoView.hasVideoContent
        let targetAlpha: CGFloat = showsContent ? 0 : 1
        guard avatarView.alpha != targetAlpha else {
            hideVideoSurfaceIfUnused()
            return
        }
        if targetAlpha > 0, backdropLayer.colors != nil {
            setBackdropHidden(false)
        }
        let apply = {
            self.avatarView.alpha = targetAlpha
            self.backdropLayer.opacity = Float(targetAlpha)
        }
        if animated {
            UIView.animate(withDuration: 0.15, animations: apply) { [weak self] finished in
                self?.hideVideoSurfaceIfUnused()
                guard finished else { return }
                self?.syncBackdropVisibility()
            }
        } else {
            withoutImplicitAnimation(apply)
            hideVideoSurfaceIfUnused()
            syncBackdropVisibility()
        }
    }

    private func hideVideoSurfaceIfUnused() {
        videoView.isHidden = !tileState.showsVideo
    }

    private func syncAccessibilityActions() {
        var actions: [UIAccessibilityCustomAction] = []
        if canToggleVideoScaling {
            let name = videoView.showsWholeFrame
                ? L10n.Accessibility.Conference.cropVideo
                : L10n.Accessibility.Conference.showFullVideo
            actions.append(UIAccessibilityCustomAction(name: name) { [weak self] _ in
                self?.onVideoScalingToggleRequested?()
                return true
            })
        }
        if onPreviewHideRequested != nil {
            actions.append(UIAccessibilityCustomAction(
                name: L10n.Accessibility.Conference.hideLocalPreview) { [weak self] _ in
                self?.onPreviewHideRequested?()
                return true
            })
        }
        accessibilityCustomActions = actions.isEmpty ? nil : actions
    }
}
