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

private final class CornerShapeView: UIView {

    override class var layerClass: AnyClass { CAShapeLayer.self }

    var shape: CAShapeLayer {
        guard let shape = layer as? CAShapeLayer else {
            fatalError("layerClass mismatch")
        }
        return shape
    }
}

enum TileCornerStyle: Equatable {
    case square
    case clipped(CGFloat)
    case backdrop(CGFloat)

    var clipRadius: CGFloat {
        if case .clipped(let radius) = self { return radius }
        return 0
    }

    var paintedRadius: CGFloat {
        if case .backdrop(let radius) = self { return radius }
        return 0
    }

    var radius: CGFloat { max(clipRadius, paintedRadius) }
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
    private let namePlate = UIView()

    private static let paintedCorners: [(unit: CGPoint, startAngle: CGFloat)] = [
        (CGPoint(x: 0, y: 0), .pi),
        (CGPoint(x: 1, y: 0), 1.5 * .pi),
        (CGPoint(x: 0, y: 1), 0.5 * .pi),
        (CGPoint(x: 1, y: 1), 0)
    ]
    private static let speakingBorderWidth: CGFloat = 2

    private let cornerViews = ParticipantTileUIView.paintedCorners.map { _ in CornerShapeView() }
    private let speakingBorder = UIView()
    private var pathRadius: CGFloat = -1

    private var avatarWidth: NSLayoutConstraint!
    private var avatarHeight: NSLayoutConstraint!
    private var nameLeading: NSLayoutConstraint!
    private var nameBottom: NSLayoutConstraint!
    private var nameTrailing: NSLayoutConstraint!

    var backdropColor: UIColor = .black {
        didSet {
            guard backdropColor != oldValue else { return }
            for corner in cornerViews { corner.shape.fillColor = backdropColor.cgColor }
        }
    }

    var cornerStyle: TileCornerStyle = .square {
        didSet {
            guard cornerStyle != oldValue else { return }
            applyCornerStyle()
        }
    }

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            guard contentInsets != oldValue else { return }
            applyContentInsets()
        }
    }
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
        nameLeading = namePlate.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        nameBottom = namePlate.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        nameTrailing = namePlate.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor,
                                                           constant: -8)
        NSLayoutConstraint.activate([
            avatarView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarWidth, avatarHeight,
            nameLeading, nameBottom, nameTrailing,
            nameLabel.leadingAnchor.constraint(equalTo: namePlate.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: namePlate.trailingAnchor,
                                                constant: -8),
            nameLabel.topAnchor.constraint(equalTo: namePlate.topAnchor, constant: 3),
            nameLabel.bottomAnchor.constraint(equalTo: namePlate.bottomAnchor, constant: -3)
        ])

        configureOverlayViews()
    }

    private func configureOverlayViews() {
        for (corner, definition) in zip(cornerViews, Self.paintedCorners) {
            corner.shape.fillColor = backdropColor.cgColor
            corner.isUserInteractionEnabled = false
            corner.isHidden = true
            corner.autoresizingMask = [
                definition.unit.x == 0 ? .flexibleRightMargin : .flexibleLeftMargin,
                definition.unit.y == 0 ? .flexibleBottomMargin : .flexibleTopMargin
            ]
            addSubview(corner)
        }

        speakingBorder.isUserInteractionEnabled = false
        speakingBorder.isHidden = true
        speakingBorder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        speakingBorder.layer.borderWidth = Self.speakingBorderWidth
        speakingBorder.layer.borderColor = UIColor.systemGreen.cgColor
        addSubview(speakingBorder)
    }

    private func applyCornerStyle() {
        layer.cornerRadius = cornerStyle.clipRadius
        speakingBorder.layer.cornerRadius = cornerStyle.radius
        let paints = cornerStyle.paintedRadius > 0
        for corner in cornerViews { corner.isHidden = !paints }
        setNeedsLayout()
    }

    private func layoutOverlayViews() {
        speakingBorder.frame = bounds

        let radius = cornerStyle.paintedRadius
        guard radius > 0 else { return }
        if radius != pathRadius {
            pathRadius = radius
            for (corner, definition) in zip(cornerViews, Self.paintedCorners) {
                corner.shape.path = Self.cornerPath(radius: radius, unit: definition.unit,
                                                    startAngle: definition.startAngle)
            }
        }
        for (corner, definition) in zip(cornerViews, Self.paintedCorners) {
            corner.frame = CGRect(x: definition.unit.x * (bounds.width - radius),
                                  y: definition.unit.y * (bounds.height - radius),
                                  width: radius, height: radius)
        }
    }

    private static func cornerPath(radius: CGFloat, unit: CGPoint,
                                   startAngle: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: unit.x * radius, y: unit.y * radius))
        path.addArc(withCenter: CGPoint(x: (1 - unit.x) * radius,
                                        y: (1 - unit.y) * radius),
                    radius: radius, startAngle: startAngle,
                    endAngle: startAngle + .pi / 2, clockwise: true)
        path.close()
        return path.cgPath
    }

    private func applyContentInsets() {
        let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let leadingInset = rightToLeft ? contentInsets.right : contentInsets.left
        let trailingInset = rightToLeft ? contentInsets.left : contentInsets.right
        nameLeading.constant = leadingInset + 8
        nameBottom.constant = -(contentInsets.bottom + 6)
        nameTrailing.constant = -(trailingInset + 8)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = CallParticipantAvatars.avatarSize(forTileSide: min(bounds.width, bounds.height))
        if avatarWidth.constant != side {
            avatarWidth.constant = side
            avatarHeight.constant = side
        }
        namePlate.layer.cornerRadius = namePlate.bounds.height / 2
        layoutOverlayViews()
    }

    func apply(_ state: ParticipantTileState) {
        let losesVideo = tileState.showsVideo && !state.showsVideo && !videoView.isHidden
        tileState = state
        nameLabel.isHidden = !state.showsName
        namePlate.isHidden = !state.showsName
        if state.showsVideo { videoView.isHidden = false }
        syncAvatarVisibility(animated: losesVideo)
        speakingBorder.isHidden = !state.isSpeaking
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
                self?.setNeedsLayout()
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
