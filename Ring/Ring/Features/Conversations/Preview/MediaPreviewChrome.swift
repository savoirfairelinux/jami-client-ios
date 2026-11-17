/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI

enum MediaPreviewLayout {
    static let control: CGFloat = 44
    static let sideInset: CGFloat = 16
    static let capsuleHeight: CGFloat = 54
    static let capsuleBottomOffset: CGFloat = -4
    static let bottomStackSpacing: CGFloat = 12
    static let scrimFade: CGFloat = 56
    static let scrimOpacity: Double = 0.2
    static let scrimRamp: [Double] = [0, 0.16, 0.5, 0.84, 1]
    static let chromeAnimation = Animation.easeInOut(duration: 0.25)
}

// MARK: - Glass

struct MediaPreviewGlass<S: Shape>: ViewModifier {
    let shape: S
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .clear.interactive() : .clear, in: shape)
        } else {
            content.background(VisualEffect(style: .systemUltraThinMaterialDark).clipShape(shape))
        }
    }
}

extension View {
    func mediaPreviewGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(MediaPreviewGlass(shape: shape, interactive: interactive))
    }
}

struct MediaPreviewGlassButton: View {
    let systemName: String
    let accessibilityLabel: String
    var size: CGFloat = MediaPreviewLayout.control
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: NavBarIcon.glyphSize))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .mediaPreviewGlass(in: Circle(), interactive: true)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityShowsLargeContentViewer { Label(accessibilityLabel, systemImage: systemName) }
    }
}

// MARK: - Edge gradients

struct MediaPreviewScrim: View {
    enum Edge { case top, bottom }

    let edge: Edge
    let chromeHeight: CGFloat

    private var height: CGFloat { chromeHeight + MediaPreviewLayout.scrimFade }

    private var gradient: Gradient {
        let ramp = MediaPreviewLayout.scrimRamp
        let fadeStart = chromeHeight / max(height, 1)
        let fade = ramp.reversed().enumerated().map { index, level in
            Gradient.Stop(color: .black.opacity(MediaPreviewLayout.scrimOpacity * level),
                          location: fadeStart + (1 - fadeStart) * CGFloat(index) / CGFloat(ramp.count - 1))
        }
        return Gradient(stops: [Gradient.Stop(color: .black.opacity(MediaPreviewLayout.scrimOpacity), location: 0)] + fade)
    }

    var body: some View {
        LinearGradient(gradient: gradient,
                       startPoint: edge == .top ? .top : .bottom,
                       endPoint: edge == .top ? .bottom : .top)
            .frame(height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Header

struct MediaPreviewHeader: View {
    let title: String
    let subtitle: String
    let menuActions: [MediaPreviewMenuAction]
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MediaPreviewGlassButton(systemName: "xmark", accessibilityLabel: L10n.Global.close, action: onClose)
            Spacer(minLength: 0)
            if !menuActions.isEmpty {
                MediaPreviewMenuButton(actions: menuActions)
                    .frame(width: MediaPreviewLayout.control, height: MediaPreviewLayout.control)
                    .mediaPreviewGlass(in: Circle(), interactive: true)
            }
        }
        .overlay(titleCapsule.padding(.horizontal, MediaPreviewLayout.control + 12))
        .padding(.horizontal, MediaPreviewLayout.sideInset)
    }

    @ViewBuilder private var titleCapsule: some View {
        if !title.isEmpty {
            VStack(spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .truncationMode(.middle)
                    .foregroundColor(.white)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(minHeight: MediaPreviewLayout.control)
            .mediaPreviewGlass(in: Capsule())
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Menu

struct MediaPreviewMenuAction {
    let title: String
    let systemName: String
    var isDestructive = false
    let handler: () -> Void
}

struct MediaPreviewMenuButton: UIViewRepresentable {
    let actions: [MediaPreviewMenuAction]

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.tintColor = .white
        button.setImage(UIImage(systemName: "ellipsis",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: NavBarIcon.glyphSize)),
                        for: .normal)
        button.accessibilityLabel = L10n.MediaPreview.moreActions
        button.showsLargeContentViewer = true
        button.largeContentTitle = L10n.MediaPreview.moreActions
        button.addInteraction(UILargeContentViewerInteraction())
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = UIMenu(children: actions.map { action in
            UIAction(title: action.title,
                     image: UIImage(systemName: action.systemName),
                     attributes: action.isDestructive ? .destructive : []) { _ in action.handler() }
        })
    }
}

// MARK: - Action capsule

struct MediaPreviewActionCapsule: View {
    @ObservedObject var model: MediaPreviewModel

    var body: some View {
        HStack(spacing: 0) {
            iconButton("arrowshape.turn.up.forward", label: L10n.Global.forward, action: model.forward)
            iconButton("square.and.arrow.up", label: L10n.Global.share, action: model.share)
        }
        .padding(.horizontal, 5)
        .frame(height: MediaPreviewLayout.capsuleHeight)
        .mediaPreviewGlass(in: Capsule())
    }

    private func iconButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: NavBarIcon.glyphSize))
                .foregroundColor(.white)
                .frame(width: MediaPreviewLayout.control, height: MediaPreviewLayout.control)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: systemName) }
    }
}
