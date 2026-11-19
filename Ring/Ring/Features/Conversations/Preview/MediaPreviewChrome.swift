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
import MCEmojiPicker

enum MediaPreviewLayout {
    static let control: CGFloat = 44
    static let sideInset: CGFloat = 16
    static let capsuleHeight: CGFloat = 54
    static let capsuleBottomOffset: CGFloat = -4
    static let reactionsHeight: CGFloat = 30
    static let reactionRowHeight: CGFloat = 50
    static let bottomStackSpacing: CGFloat = 12
    static let headerSpacing: CGFloat = 12
    static let reactionsTopSpacing: CGFloat = 8
    static let scrimFade: CGFloat = 24
    static let scrimOpacity: Double = 0.16
    static let scrimStops = 12
    static let chromeAnimation = Animation.easeInOut(duration: 0.2)
}

// MARK: - Glass

struct MediaPreviewGlass<S: Shape>: ViewModifier {
    let shape: S
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glass = Glass.regular
            content.glassEffect(interactive ? glass.interactive() : glass, in: shape)
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
        let count = MediaPreviewLayout.scrimStops
        return Gradient(stops: (0...count).map { index in
            let location = Double(index) / Double(count)
            let level = (1 + cos(location * .pi)) / 2
            return Gradient.Stop(color: .black.opacity(MediaPreviewLayout.scrimOpacity * level),
                                 location: location)
        })
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
        HStack(spacing: MediaPreviewLayout.headerSpacing) {
            MediaPreviewGlassButton(systemName: "xmark", accessibilityLabel: L10n.Global.close, action: onClose)
            Spacer(minLength: 0)
            if !menuActions.isEmpty {
                MediaPreviewMenuButton(actions: menuActions)
                    .frame(width: MediaPreviewLayout.control, height: MediaPreviewLayout.control)
                    .mediaPreviewGlass(in: Circle(), interactive: true)
            }
        }
        .overlay(titleCapsule.padding(.horizontal, MediaPreviewLayout.control + MediaPreviewLayout.headerSpacing))
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

    private let dimmedOpacity = 0.45

    private var othersOpacity: Double { model.isReacting ? dimmedOpacity : 1 }

    var body: some View {
        HStack(spacing: 0) {
            if model.canReply {
                Button(action: model.beginReply) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrowshape.turn.up.backward")
                            .font(.system(size: NavBarIcon.glyphSize))
                        Text(L10n.Global.reply)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: MediaPreviewLayout.control)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityShowsLargeContentViewer()
                .opacity(othersOpacity)
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 6)
                    .accessibilityHidden(true)
            }
            if model.canReact {
                iconButton("face.smiling", label: L10n.MediaPreview.react, isSelected: model.isReacting, action: model.toggleReacting)
            }
            Group {
                iconButton("arrowshape.turn.up.forward", label: L10n.Global.forward, action: model.forward)
                iconButton("square.and.arrow.up", label: L10n.Global.share, action: model.share)
            }
            .opacity(othersOpacity)
        }
        .padding(.horizontal, 5)
        .frame(height: MediaPreviewLayout.capsuleHeight)
        .mediaPreviewGlass(in: Capsule())
    }

    private func iconButton(_ systemName: String, label: String, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Reactions

struct MediaPreviewReactionsSummary: View {
    @ObservedObject var reactions: ReactionsContainerModel
    let maxWidth: CGFloat

    @Environment(\.sizeCategory)
    private var sizeCategory

    private let segmentSpacing: CGFloat = 8
    private let contentSpacing: CGFloat = 3
    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 5

    var body: some View {
        let fonts = ReactionsCapsuleFonts(sizeCategory: sizeCategory)
        let summary = reactions.summary(fitting: maxWidth, maxVisible: reactions.segments.count) { width(of: $0, fonts: fonts) }
        if !summary.segments.isEmpty {
            HStack(spacing: segmentSpacing) {
                ForEach(summary.segments) { segment in
                    HStack(spacing: contentSpacing) {
                        Text(segment.emoji)
                            .font(.subheadline)
                        if segment.count > 1 {
                            countText(String(segment.count))
                                .foregroundColor(.white)
                        }
                    }
                }
                if summary.hiddenCount > 0 {
                    countText("+" + String(summary.hiddenCount))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            .fixedSize()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: MediaPreviewLayout.reactionsHeight)
            .mediaPreviewGlass(in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Accessibility.messageReactions)
            .accessibilityValue(summary.accessibilityValue)
        }
    }

    private func countText(_ value: String) -> Text {
        Text(verbatim: value)
            .font(.footnote.weight(.semibold).monospacedDigit())
    }

    private func width(of summary: ReactionsSummary, fonts: ReactionsCapsuleFonts) -> CGFloat {
        var widths = summary.segments.map { segment -> CGFloat in
            var width = fonts.emojiWidth(segment.emoji)
            if segment.count > 1 {
                width += contentSpacing + fonts.countWidth(String(segment.count))
            }
            return width
        }
        if summary.hiddenCount > 0 {
            widths.append(fonts.countWidth("+" + String(summary.hiddenCount)))
        }
        return widths.reduce(0, +) + segmentSpacing * CGFloat(max(0, widths.count - 1)) + 2 * horizontalPadding
    }
}

struct MediaPreviewReactionPicker: View {
    let choices: ReactionChoices
    let maxWidth: CGFloat
    let onPick: (String) -> Void

    private let spacing: CGFloat = 2
    private let inset: CGFloat = 6

    private var contentWidth: CGFloat {
        let items = CGFloat(choices.all.count + 1)
        return items * MediaPreviewLayout.control + (items - 1) * spacing + 2 * inset
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                MediaPreviewEmojiPickerButton(onPick: onPick)
                ForEach(choices.all, id: \.self) { emoji in
                    emojiButton(emoji, isActive: choices.own.contains(emoji))
                }
            }
            .padding(.horizontal, inset)
            .frame(height: MediaPreviewLayout.reactionRowHeight)
        }
        .frame(width: min(contentWidth, maxWidth), height: MediaPreviewLayout.reactionRowHeight)
        .mediaPreviewGlass(in: Capsule())
    }

    private func emojiButton(_ emoji: String, isActive: Bool) -> some View {
        Button(action: { onPick(emoji) }, label: {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: MediaPreviewLayout.control, height: MediaPreviewLayout.control)
                .background(Circle().fill(Color.white.opacity(isActive ? 0.22 : 0)))
                .contentShape(Rectangle())
        })
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isActive ? L10n.Accessibility.removeReaction(emoji) : emoji)
        .accessibilityShowsLargeContentViewer()
    }
}

struct MediaPreviewEmojiPickerButton: View {
    let onPick: (String) -> Void

    @SwiftUI.State private var isPresented = false
    @SwiftUI.State private var selectedEmoji = ""

    var body: some View {
        Button(action: { isPresented = true }, label: {
            Image(systemName: "plus")
                .font(.system(size: NavBarIcon.glyphSize))
                .foregroundColor(.white)
                .frame(width: MediaPreviewLayout.control, height: MediaPreviewLayout.control)
                .contentShape(Rectangle())
        })
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n.MediaPreview.moreEmoji)
        .accessibilityShowsLargeContentViewer { Label(L10n.MediaPreview.moreEmoji, systemImage: "plus") }
        .emojiPicker(isPresented: $isPresented, selectedEmoji: $selectedEmoji, arrowDirection: .down)
        .onChange(of: selectedEmoji) { emoji in
            guard !emoji.isEmpty else { return }
            isPresented = false
            selectedEmoji = ""
            onPick(emoji)
        }
    }
}
