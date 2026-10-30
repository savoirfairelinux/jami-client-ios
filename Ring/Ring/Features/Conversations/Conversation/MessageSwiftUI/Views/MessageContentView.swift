/*
 *  Copyright (C) 2022 - 2025 Savoir-faire Linux Inc.
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

class CustomLinkView: LPLinkView {
    override var intrinsicContentSize: CGSize { CGSize(width: 0, height: super.intrinsicContentSize.height) }

    override func addInteraction(_ interaction: UIInteraction) {
        if interaction is UIContextMenuInteraction {
            return
        }
        super.addInteraction(interaction)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        stripSystemContextMenu(from: self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stripSystemContextMenu(from: self)
    }

    private func stripSystemContextMenu(from view: UIView) {
        for interaction in view.interactions where interaction is UIContextMenuInteraction {
            view.removeInteraction(interaction)
        }
        for subview in view.subviews {
            stripSystemContextMenu(from: subview)
        }
    }
}

struct URLPreview: UIViewRepresentable {
    typealias UIViewType = UIView

    var metadata: LPLinkMetadata
    var maxDimension: CGFloat
    var fixedSize: CGFloat?

    func makeUIView(context: Context) -> UIView {
        if let size = fixedSize {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.clipsToBounds = false

            let linkView = CustomLinkView(metadata: metadata)
            linkView.translatesAutoresizingMaskIntoConstraints = false
            linkView.contentMode = .scaleAspectFit

            container.addSubview(linkView)

            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: size),
                container.heightAnchor.constraint(equalToConstant: size),
                linkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                linkView.topAnchor.constraint(equalTo: container.topAnchor),
                linkView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                linkView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            return container
        } else {
            let view = CustomLinkView(metadata: metadata)
            view.frame = CGRect(x: 0, y: 0, width: maxDimension, height: maxDimension)
            view.contentMode = .scaleAspectFit
            return view
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class ScaledImageView: UIImageView {
    var maxHeight: CGFloat = 300
    var maxWidth: CGFloat = 250
    override var intrinsicContentSize: CGSize {
        if let imageSize = self.image?.size {
            if imageSize.width < maxWidth && imageSize.height < maxHeight {
                return imageSize
            }
            let widthRatio = maxWidth / imageSize.width
            let heightRatio = maxHeight / imageSize.height
            let ratio = min(widthRatio, heightRatio)
            return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
        }
        return CGSize(width: -1, height: -1)
    }
}

struct ScaledImageViewWrapper: UIViewRepresentable {
    let imageToShow: UIImage
    var maxHeight: CGFloat
    var maxWidth: CGFloat

    func makeUIView(context: Context) -> ScaledImageView {
        let imageView = ScaledImageView()
        imageView.maxHeight = maxHeight
        imageView.maxWidth = maxWidth
        imageView.image = imageToShow
        return imageView
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct MessageTextStyle: ViewModifier {
    @ObservedObject var model: MessageContentVM

    func body(content: Content) -> some View {
        content
            .padding(.top, model.textVerticalInset)
            .padding(.bottom, model.textVerticalInset)
            .padding(.leading, model.textInset)
            .padding(.trailing, model.textInset)
            .foregroundColor(model.styling.textColor)
            .background(MessageBubbleFill(model: model))
            .if(model.hasBorder) { view in
                view.overlay(
                    CornerRadiusShape(radius: model.cornerRadius, corners: model.corners)
                        .stroke(model.borderColor, lineWidth: 2))
            }
            .modifier(MessageCornerRadius(model: model))
    }
}

/// Unified long press (and optional tap) gesture handler for all message types.
/// Reads `suppressLongPress` from the environment so that swipe-to-reply
/// correctly suppresses long press on every message type, not just text.
/// Reads `contextMenuActive` to suppress taps while the context menu is
/// presenting or dismissing, preventing accidental full-screen preview.
struct MessageGestureHandler: ViewModifier {
    /// Called on long press. Required for all message types.
    var onLongPress: () -> Void
    /// Called on tap with the view's global frame and a provider closure that
    /// can be called later to get the up-to-date frame (e.g. after scrolling).
    var onTap: ((_ frame: CGRect, _ frameProvider: @escaping () -> CGRect) -> Void)?

    private let longPressDuration: Double = 0.2

    @Environment(\.suppressLongPress)
    private var suppressLongPress
    @Environment(\.contextMenuActive)
    private var contextMenuActive

    func body(content: Content) -> some View {
        content
            .overlay(tapOverlay)
            .scrollableLongPress(minimumDuration: longPressDuration) {
                guard !suppressLongPress else { return }
                onLongPress()
            }
    }

    @ViewBuilder
    private var tapOverlay: some View {
        if let onTap = onTap {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !contextMenuActive else { return }
                        onTap(proxy.frame(in: .global), { proxy.frame(in: .global) })
                    }
                    .accessibilityAction(named: L10n.Global.preview) {
                        onTap(proxy.frame(in: .global), { proxy.frame(in: .global) })
                    }
            }
        }
    }
}

private struct ScrollableLongPress: ViewModifier {
    let minimumDuration: TimeInterval
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .simultaneousGesture(LongPressGesture(minimumDuration: minimumDuration).onEnded { _ in action() })
        } else {
            // Before iOS 18 a SwiftUI long press keeps the enclosing ScrollView
            // from scrolling when the drag starts on the view.
            content
                .overlay(LongPressTouchArea(minimumDuration: minimumDuration, action: action)
                            .allowsHitTesting(false))
        }
    }
}

/// A UIKit long press attached to the enclosing scroll view that only accepts
/// touches inside this view's bounds.
private struct LongPressTouchArea: UIViewRepresentable {
    let minimumDuration: TimeInterval
    let action: () -> Void

    func makeUIView(context: Context) -> TouchAreaView {
        let view = TouchAreaView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: TouchAreaView, context: Context) {
        view.recognizer.minimumPressDuration = minimumDuration
        view.action = action
    }

    final class TouchAreaView: UIView, UIGestureRecognizerDelegate {
        let recognizer = UILongPressGestureRecognizer()
        var action: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            recognizer.addTarget(self, action: #selector(handleLongPress))
            recognizer.delegate = self
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            recognizer.view?.removeGestureRecognizer(recognizer)
            guard window != nil else { return }
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) {
                ancestor = view.superview
            }
            (ancestor ?? superview)?.addGestureRecognizer(recognizer)
        }

        @objc
        private func handleLongPress() {
            guard recognizer.state == .began else { return }
            action?()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            bounds.contains(touch.location(in: self))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

extension View {
    func scrollableLongPress(minimumDuration: TimeInterval, perform action: @escaping () -> Void) -> some View {
        modifier(ScrollableLongPress(minimumDuration: minimumDuration, action: action))
    }

    func messageGesture(
        onLongPress: @escaping () -> Void,
        onTap: ((_ frame: CGRect, _ frameProvider: @escaping () -> CGRect) -> Void)? = nil
    ) -> some View {
        modifier(MessageGestureHandler(onLongPress: onLongPress, onTap: onTap))
    }
}

struct MessageBubbleFill: View {
    @ObservedObject var model: MessageContentVM
    @Environment(\.drawsMessageBubble)
    private var drawsMessageBubble

    var body: some View {
        if model.hasBubbleBackground && drawsMessageBubble {
            model.backgroundColor
        }
    }
}

struct MessageCornerRadius: ViewModifier {
    @ObservedObject var model: MessageContentVM

    func body(content: Content) -> some View {
        content
            .if(!model.hasBorder) { view in
                view.cornerRadius(radius: model.cornerRadius, corners: model.corners)
            }
            .cornerRadius(5)
    }
}

struct MessageContentView: View {
    let messageModel: MessageContainerModel
    @ObservedObject var model: MessageContentVM
    @ObservedObject var reactionsModel: ReactionsContainerModel
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView, _ mode: ContextMenuMode) -> Void
    @ScaledMetric(relativeTo: .subheadline)
    private var reactionsCapsuleHeight = MessageReactionsCapsule.defaultHeight

    // swipe to reply

    @Environment(\.layoutDirection)
    var layoutDirection
    @SwiftUI.State private var bubbleWidth: CGFloat = 0
    @SwiftUI.State private var menuRequest: ContextMenuMode?
    @SwiftUI.State private var audioSeekArea: CGRect = .null
    @SwiftUI.State private var bubbleDragOffset: CGFloat = 0
    @SwiftUI.State private var dragHapticFired: Bool = false
    @SwiftUI.State private var dragX: CGFloat = 0

    private enum SwipeAxis { case horizontal, vertical }

    @SwiftUI.State private var lockedAxis: SwipeAxis?
    @SwiftUI.State private var suppressLongPress: Bool = false
    @SwiftUI.State private var ringProgress: CGFloat = 0
    private let replyActivationDistance: CGFloat = 70
    private let minSwipeDistance: CGFloat = 30

    private var hasPlayer: Bool {
        model.type == .fileTransfer
            && (model.content as NSString).pathExtension.isMediaExtension()
    }
    private let maxVisualOffset: CGFloat = 80
    private let replyArrowGap: CGFloat = 30
    private let replyRingSize: CGFloat = 28
    private let replyRingStrokeWidth: CGFloat = 1
    private let replyArrowFontSize: CGFloat = 16
    private let swipeResistance: CGFloat = 0.6
    private let maxDrag: CGFloat = 90
    private let lockThreshold: CGFloat = 12

    var body: some View {
        VStack(alignment: model.isIncoming ? .leading : .trailing, spacing: 0) {
            VStack(alignment: messageModel.replyTarget.alignment) {
                MessageBubbleView(messageModel: messageModel, model: model, menuRequest: $menuRequest, onLongPress: onLongPress)
                    .onAppear {
                        self.model.onAppear()
                    }
            }
            .if(model.hasReactions && reactionsOverlapContent) { view in
                view.mask {
                    reactionsCutout()
                }
            }
            .overlay(alignment: reactionsAlignment) {
                if model.hasReactions {
                    reactions()
                }
            }
            .padding(.bottom, model.hasReactions ? reactionsSpaceBelow : 0)
            if model.showsTimeBelowReactions {
                MessageTimeView(text: model.timeText, color: model.timeColor)
            }
        }
        .scaleEffect(model.scale)
        .suppressLongPress(suppressLongPress)
        .measuringWidth(BubbleWidthKey.self, into: $bubbleWidth)
        .coordinateSpace(name: AudioSeekAreaKey.coordinateSpace)
        .onPreferenceChange(AudioSeekAreaKey.self) { area in
            audioSeekArea = area
        }
        .contentShape(Rectangle())
        .offset(x: outwardSign() * dragX)
        .if(model.menuItems.contains(.reply)) { view in
            view
                .overlay(replyIndicator().allowsHitTesting(false))
                .simultaneousGesture(replySwipeGesture())
        }
    }

    private func replyStartIsTrailing() -> Bool {
        let isLTR = (layoutDirection == .leftToRight)
        return isLTR ? !model.message.incoming : model.message.incoming
    }
    private func replyIndicatorProgress() -> CGFloat {
        let projected = outwardSign() * (outwardSign() * dragX)
        let distance = max(0, projected)
        return min(1, distance / replyActivationDistance)
    }
    private func outwardSign() -> CGFloat {
        let isLTR = (layoutDirection == .leftToRight)
        return model.message.incoming ? (isLTR ? 1 : -1) : (isLTR ? -1 : 1)
    }
    private func replyIndicator() -> some View {
        let progress = min(1, (dragX / swipeResistance) / replyActivationDistance)
        let startIsTrailing = replyStartIsTrailing()
        let iconName = startIsTrailing ? "arrowshape.turn.up.right" : "arrowshape.turn.up.left"
        let edgeSign: CGFloat = startIsTrailing ? 1 : -1
        let width = bubbleWidth
        let offsetX = edgeSign * (width / 2 + replyArrowGap) + outwardSign() * dragX
        let screenScale = UIScreen.main.scale
        let alignedOffsetX = (offsetX * screenScale).rounded() / screenScale
        return ZStack {
            if dragHapticFired {
                Circle()
                    .trim(from: 0, to: min(1, ringProgress))
                    .rotation(Angle(degrees: -90))
                    .stroke(Color(model.preferencesColor), style: StrokeStyle(lineWidth: replyRingStrokeWidth, lineCap: .round))
                    .frame(width: replyRingSize, height: replyRingSize)
                    .opacity(Double(progress))
            }
            Image(systemName: iconName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: replyArrowFontSize.rounded(.toNearestOrAwayFromZero), height: replyArrowFontSize.rounded(.toNearestOrAwayFromZero))
                .foregroundColor(Color(model.preferencesColor))
                .opacity(Double(progress))
        }
        .offset(x: alignedOffsetX)
        .allowsHitTesting(false)
    }
    private func replySwipeGesture() -> some Gesture {
        return DragGesture(minimumDistance: minSwipeDistance, coordinateSpace: .local)
            .onChanged { value in
                if lockedAxis == nil {
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    // For player messages, reject drags that start in the
                    // seek slider zone so horizontal slider drags do not
                    // trigger swipe-to-reply.
                    if hasPlayer {
                        if isInSeekZone(value.startLocation) {
                            lockedAxis = .vertical
                        } else if horizontal > lockThreshold && horizontal > vertical {
                            lockedAxis = .horizontal
                        } else if vertical > lockThreshold {
                            lockedAxis = .vertical
                        }
                    } else {
                        if horizontal > lockThreshold && horizontal > vertical {
                            lockedAxis = .horizontal
                        } else if vertical > lockThreshold {
                            lockedAxis = .vertical
                        }
                    }
                }
                guard lockedAxis == .horizontal, model.menuItems.contains(.reply) else { return }
                suppressLongPress = true
                let projected = outwardSign() * value.translation.width
                let base = max(0, projected)
                let clamped = min(base, maxDrag)
                let visual = clamped * swipeResistance
                dragX = visual
                if !dragHapticFired && clamped >= replyActivationDistance {
                    dragHapticFired = true
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    ringProgress = 0
                    withAnimation(.linear(duration: 0.25)) { ringProgress = 1 }
                }
            }
            .onEnded { _ in
                defer { lockedAxis = nil }
                suppressLongPress = false
                guard lockedAxis == .horizontal, model.menuItems.contains(.reply) else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { dragX = 0 }
                    return
                }
                if (dragX / swipeResistance) > replyActivationDistance { model.contextMenuSelect(item: .reply) }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { dragX = 0 }
                dragHapticFired = false
                ringProgress = 0
            }
    }

    private func isInSeekZone(_ location: CGPoint) -> Bool {
        guard let media = model.media, media.playback?.player(for: media.item.id) != nil else { return false }
        return media.item.preview.hasVideo
            ? isInVideoSeekZone(location)
            : audioSeekArea.contains(location)
    }

    private func isInVideoSeekZone(_ location: CGPoint) -> Bool {
        let sliderZoneHeight: CGFloat = 44
        let viewHeight = max(model.playerHeight, 80)
        return location.y > viewHeight - sliderZoneHeight
    }

    private var reactionsAlignment: Alignment {
        model.isIncoming ? .bottomLeading : .bottomTrailing
    }

    private func reactions() -> some View {
        reactionsRow(isCutout: false)
            .onAppear {
                self.messageModel.reactionsModel.onAppear()
            }
    }

    private var reactionsSpaceBelow: CGFloat {
        MessageReactionsCapsule.spaceBelow(height: reactionsCapsuleHeight, overlapsContent: reactionsOverlapContent)
    }

    private var reactionsOverlapContent: Bool {
        model.hasBubbleBackground || model.isEmojiOnly
    }

    private func reactionsCutout() -> some View {
        ZStack {
            Rectangle()
                .padding(-MessageReactionsCapsule.cutoutMaskOverflow)
            Color.clear
                .overlay(alignment: reactionsAlignment) {
                    reactionsRow(isCutout: true)
                        .blendMode(.destinationOut)
                }
        }
        .compositingGroup()
    }

    private func reactionsRow(isCutout: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            MessageReactionsCapsule(model: reactionsModel,
                                    tint: model.receivedBubbleColor,
                                    height: reactionsCapsuleHeight,
                                    insetsFromBubbleEdges: model.hasBubbleBackground,
                                    isCutout: isCutout) {
                menuRequest = .reactions
            }
        }
        .offset(y: reactionsSpaceBelow)
    }
}

private struct MessageReactionsCapsule: View {
    static let defaultHeight: CGFloat = 24
    private static let fillOverlap: CGFloat = 6
    private static let ringWidth: CGFloat = 2
    private static let bubbleOverlap: CGFloat = fillOverlap + ringWidth
    private static let contentGap: CGFloat = 2
    static let cutoutMaskOverflow: CGFloat = 100

    static func spaceBelow(height: CGFloat, overlapsContent: Bool) -> CGFloat {
        height + 2 * ringWidth + (overlapsContent ? -bubbleOverlap : contentGap)
    }

    @ObservedObject var model: ReactionsContainerModel
    let tint: Color
    let height: CGFloat
    let insetsFromBubbleEdges: Bool
    let isCutout: Bool
    let onSelect: () -> Void

    private let bubbleLeadingInset: CGFloat = 30
    private let bubbleTrailingInset: CGFloat = 10
    private let segmentSpacing: CGFloat = 2
    private let segmentPadding: CGFloat = 6
    private let contentSpacing: CGFloat = 3
    private let hitExtension: CGFloat = 16
    private let hitHorizontalExtension: CGFloat = 6

    @Environment(\.messageReactionsMaxWidth)
    private var maxWidth
    @Environment(\.sizeCategory)
    private var sizeCategory

    var body: some View {
        let fonts = ReactionsCapsuleFonts(sizeCategory: sizeCategory)
        let summary = model.summary(fitting: maxWidth) { width(of: $0, fonts: fonts) }
        HStack(spacing: segmentSpacing) {
            ForEach(summary.segments) { reaction in
                segment(reaction)
            }
            if summary.hiddenCount > 0 {
                overflowSegment(hiddenCount: summary.hiddenCount)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: height)
        .if(!isCutout) { view in
            view.conversationContentMaterial(tint: tint, in: Capsule())
        }
        .padding(Self.ringWidth)
        .if(isCutout) { view in
            view.background(Capsule().fill(Color.black))
        }
        .padding(.top, hitExtension)
        .padding(.horizontal, hitHorizontalExtension)
        .contentShape(Rectangle())
        .padding(.top, -hitExtension)
        .padding(.horizontal, -hitHorizontalExtension)
        .padding(.leading, insetsFromBubbleEdges ? bubbleLeadingInset - Self.ringWidth : 0)
        .padding(.trailing, insetsFromBubbleEdges ? bubbleTrailingInset - Self.ringWidth : 0)
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Accessibility.messageReactions)
        .accessibilityValue(summary.accessibilityValue)
        .accessibilityHint(L10n.Accessibility.messageReactionsHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityHidden(isCutout)
    }

    private func segment(_ reaction: ReactionSegment) -> some View {
        HStack(spacing: contentSpacing) {
            Text(reaction.emoji)
                .font(.subheadline)
            if reaction.count > 1 {
                countText(String(reaction.count))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, segmentPadding)
        .frame(maxHeight: .infinity)
    }

    private func width(of summary: ReactionsSummary, fonts: ReactionsCapsuleFonts) -> CGFloat {
        var segmentWidths = summary.segments.map { reaction -> CGFloat in
            var width = fonts.emojiWidth(reaction.emoji) + 2 * segmentPadding
            if reaction.count > 1 {
                width += contentSpacing + fonts.countWidth(String(reaction.count))
            }
            return width
        }
        if summary.hiddenCount > 0 {
            segmentWidths.append(fonts.countWidth("+" + String(summary.hiddenCount)) + 2 * segmentPadding)
        }
        let spacing = segmentSpacing * CGFloat(max(0, segmentWidths.count - 1))
        let insets = insetsFromBubbleEdges ? bubbleLeadingInset + bubbleTrailingInset - 2 * Self.ringWidth : 0
        return segmentWidths.reduce(0, +) + spacing + 2 * Self.ringWidth + insets
    }

    private func overflowSegment(hiddenCount: Int) -> some View {
        countText("+" + String(hiddenCount))
            .foregroundColor(.conversationSecondaryText)
            .padding(.horizontal, segmentPadding)
            .frame(maxHeight: .infinity)
    }

    private func countText(_ value: String) -> Text {
        Text(verbatim: value)
            .font(Font.footnote.weight(.semibold).monospacedDigit())
    }
}

private struct ReactionsCapsuleFonts {
    private let emojiFont: UIFont
    private let countFont: UIFont

    init(sizeCategory: ContentSizeCategory) {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(sizeCategory))
        emojiFont = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits)
        let countSize = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: traits).pointSize
        countFont = UIFont.monospacedDigitSystemFont(ofSize: countSize, weight: .semibold)
    }

    func emojiWidth(_ text: String) -> CGFloat {
        width(of: text, font: emojiFont)
    }

    func countWidth(_ text: String) -> CGFloat {
        width(of: text, font: countFont)
    }

    private func width(of text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

private struct BubbleWidthKey: MeasuredWidthKey {}
