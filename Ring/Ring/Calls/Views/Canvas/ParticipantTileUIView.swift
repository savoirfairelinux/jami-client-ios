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
    var showsVideo = false
    var showsName = false
    var isAudioMuted = false
    var isHandRaised = false
    var isSpeaking = false
}

final class ParticipantTileUIView: UIView {

    let participantId: String
    let videoView = RendererLayerView()

    var foreignGestureGate: ((UIGestureRecognizer) -> Bool)?
    var onVideoScalingToggleRequested: (() -> Void)?

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
    private let nameLabel = UILabel()

    private var avatarWidth: NSLayoutConstraint!
    private var avatarHeight: NSLayoutConstraint!
    private var nameCancellable: AnyCancellable?
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
        backgroundColor = UIColor(white: 0.12, alpha: 1)
        isAccessibilityElement = true
        accessibilityTraits = .image
        if participantId == CanvasParticipant.localId {
            accessibilityLabel = L10n.Accessibility.Conference.localPreview
        }

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
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOpacity = 0.8
        nameLabel.layer.shadowRadius = 2
        nameLabel.layer.shadowOffset = .zero
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        avatarWidth = avatarView.widthAnchor.constraint(equalToConstant: 72)
        avatarHeight = avatarView.heightAnchor.constraint(equalToConstant: 72)
        NSLayoutConstraint.activate([
            avatarView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarWidth, avatarHeight,
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = CallParticipantAvatars.avatarSize(forTileSide: min(bounds.width, bounds.height))
        if avatarWidth.constant != side {
            avatarWidth.constant = side
            avatarHeight.constant = side
        }
        layer.borderWidth = tileState.isSpeaking ? 2 : 0
    }

    func apply(_ state: ParticipantTileState) {
        let losesVideo = tileState.showsVideo && !state.showsVideo && !videoView.isHidden
        tileState = state
        nameLabel.isHidden = !state.showsName
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
            return
        }
        nameCancellable = provider.$profileName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.nameLabel.text = name
                self?.accessibilityLabel = name
            }
    }

    var showsAvatarPlaceholder: Bool {
        !avatarView.isHidden && avatarView.alpha > 0.5
    }

    var displayedName: String? { nameLabel.isHidden ? nil : nameLabel.text }

    private func syncAvatarVisibility(animated: Bool) {
        let showsContent = tileState.showsVideo && videoView.hasVideoContent
        let targetAlpha: CGFloat = showsContent ? 0 : 1
        guard avatarView.alpha != targetAlpha else {
            hideVideoSurfaceIfUnused()
            return
        }
        let apply = { self.avatarView.alpha = targetAlpha }
        if animated {
            UIView.animate(withDuration: 0.15, animations: apply) { [weak self] _ in
                self?.hideVideoSurfaceIfUnused()
            }
        } else {
            apply()
            hideVideoSurfaceIfUnused()
        }
    }

    private func hideVideoSurfaceIfUnused() {
        videoView.isHidden = !tileState.showsVideo
    }

    private func syncAccessibilityActions() {
        guard canToggleVideoScaling else {
            accessibilityCustomActions = nil
            return
        }
        let name = videoView.showsWholeFrame
            ? L10n.Accessibility.Conference.cropVideo
            : L10n.Accessibility.Conference.showFullVideo
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: name) { [weak self] _ in
                self?.onVideoScalingToggleRequested?()
                return true
            }
        ]
    }
}
