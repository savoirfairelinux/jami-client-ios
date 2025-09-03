/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
    @StateObject var model: MessageContentVM

    func body(content: Content) -> some View {
        content
            .padding(.top, model.textVerticalInset)
            .padding(.bottom, model.textVerticalInset)
            .padding(.leading, model.textInset)
            .padding(.trailing, model.textInset)
            .foregroundColor(model.styling.textColor)
            .background(model.backgroundColor)
            .if(model.hasBorder) { view in
                view.overlay(
                    CornerRadiusShape(radius: model.cornerRadius, corners: model.corners)
                        .stroke(model.borderColor, lineWidth: 2))
            }
            .modifier(MessageCornerRadius(model: model))
    }
}

struct MessageLongPress: ViewModifier {
    var longPressCb: (() -> Void)

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.2, perform: longPressCb)
    }
}

struct MessageCornerRadius: ViewModifier {
    @StateObject var model: MessageContentVM

    func body(content: Content) -> some View {
        content
            .if(!model.hasBorder) { view in
                view.cornerRadius(radius: model.cornerRadius, corners: model.corners)
            }
            .cornerRadius(3)
    }
}

struct MessageContentView: View {
    let messageModel: MessageContainerModel
    @StateObject var model: MessageContentVM
    @StateObject var reactionsModel: ReactionsContainerModel
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView) -> Void
    let padding: CGFloat = 12
    var showReactionsView: (_ message: ReactionsContainerModel?) -> Void
    @SwiftUI.State private var messageWidth: CGFloat = 0
    @SwiftUI.State private var reactionsHeight: CGFloat = 20
    @SwiftUI.State private var reactionsWidth: CGFloat = 0
    @SwiftUI.State private var emojiAlignment: Alignment = Alignment.bottomTrailing

    // swipe to reply

    @Environment(\.layoutDirection)
    var layoutDirection
    @SwiftUI.State private var bubbleWidth: CGFloat = 0
    @SwiftUI.State private var bubbleDragOffset: CGFloat = 0
    @SwiftUI.State private var dragHapticFired: Bool = false
    @SwiftUI.State private var dragX: CGFloat = 0
    private enum SwipeAxis { case horizontal, vertical }
    @SwiftUI.State private var lockedAxis: SwipeAxis?
    @SwiftUI.State private var suppressLongPress: Bool = false
    @SwiftUI.State private var ringProgress: CGFloat = 0
    private let replyActivationDistance: CGFloat = 70
    private let minSwipeDistance: CGFloat = 20
    private let swipeDominanceFactor: CGFloat = 1.5
    private let maxVisualOffset: CGFloat = 80
    private let replyArrowGap: CGFloat = 30
    private let replyRingSize: CGFloat = 28
    private let replyRingStrokeWidth: CGFloat = 1
    private let replyArrowFontSize: CGFloat = 16
    private let swipeResistance: CGFloat = 0.6
    private let maxDrag: CGFloat = 90
    private let lockThreshold: CGFloat = 12

    var body: some View {
        ZStack(alignment: emojiAlignment) {
            VStack(alignment: messageModel.replyTarget.alignment) {
                if messageModel.messageContent.isHistory {
                    renderReplyHistory()
                }
                MessageBubbleView(messageModel: messageModel, model: model, onLongPress: onLongPress)
                    .onAppear {
                        self.model.onAppear()
                    }
                    .offset(y: messageModel.messageContent.isHistory ? -padding : 0)
                    .background(GeometryReader { preferences in
                        Color.clear.onAppear {
                            if preferences.size.width == 0 || preferences.size.height == 0 { return }
                            self.messageWidth = preferences.size.width
                            self.updateAlignment()
                        }
                    })
            }
            .padding(.bottom, !messageModel.hasReactions() ? 0 : reactionsHeight - 6)
            if messageModel.hasReactions() {
                renderReactions()
            }
        }
        .onPreferenceChange(SizePreferenceKey.self) { preferences in
            self.reactionsHeight = preferences.height
            self.reactionsWidth = preferences.width
            self.updateAlignment()
        }
        .offset(y: messageModel.messageContent.isHistory ? padding : 0)
        .scaleEffect(model.scale)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        self.bubbleWidth = proxy.size.width
                    }
            }
        )
        .conditionalModifier(AccessibilityHintModifier(hint: swipeReplyHint()), apply: model.menuItems.contains(.reply) && UIAccessibility.isVoiceOverRunning)
        .contentShape(Rectangle())
        .offset(x: outwardSign() * dragX)
        .if(model.menuItems.contains(.reply)) { view in
            view
                .overlay(simpleReplyIndicator().allowsHitTesting(false))
                .simultaneousGesture(simpleSwipeGesture())
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
    private func simpleReplyIndicator() -> some View {
        let progress = min(1, (dragX / swipeResistance) / replyActivationDistance)
        let startIsTrailing = replyStartIsTrailing()
        let iconName = startIsTrailing ? "arrowshape.turn.up.right" : "arrowshape.turn.up.left"
        let edgeSign: CGFloat = startIsTrailing ? 1 : -1
        let offsetX = edgeSign * (bubbleWidth / 2 + replyArrowGap) + outwardSign() * dragX
        let screenScale = UIScreen.main.scale
        let alignedOffsetX = (offsetX * screenScale).rounded() / screenScale
        return ZStack {
            if dragHapticFired {
                Circle()
                    .trim(from: 0, to: min(1, ringProgress))
                    .rotation(Angle(degrees: -90))
                    .stroke(Color(UIColor.systemBlue), style: StrokeStyle(lineWidth: replyRingStrokeWidth, lineCap: .round))
                    .frame(width: replyRingSize, height: replyRingSize)
                    .opacity(Double(progress))
            }
            Image(systemName: iconName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: replyArrowFontSize.rounded(.toNearestOrAwayFromZero), height: replyArrowFontSize.rounded(.toNearestOrAwayFromZero))
                .foregroundColor(Color(UIColor.systemBlue))
                .opacity(Double(progress))
        }
        .offset(x: alignedOffsetX)
        .allowsHitTesting(false)
    }
    private func simpleSwipeGesture() -> some Gesture {
        return DragGesture(minimumDistance: minSwipeDistance, coordinateSpace: .local)
            .onChanged { value in
                if lockedAxis == nil {
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if horizontal > lockThreshold && horizontal > vertical { lockedAxis = .horizontal } else if vertical > lockThreshold { lockedAxis = .vertical }
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
    private func swipeReplyHint() -> String {
        let isLTR = (layoutDirection == .leftToRight)
        if model.message.incoming {
            return isLTR ? L10n.Accessibility.swipeLeftToReply : L10n.Accessibility.swipeRightToReply
        } else {
            return isLTR ? L10n.Accessibility.swipeRightToReply : L10n.Accessibility.swipeLeftToReply
        }
    }

    private func updateAlignment() {
        if self.messageWidth < self.reactionsWidth && model.message.incoming {
            emojiAlignment = Alignment.bottomLeading
        } else {
            emojiAlignment = Alignment.bottomTrailing
        }
    }

    private func renderReplyHistory() -> some View {
        HStack {
            if messageModel.replyTarget.alignment == .leading {
                Spacer().frame(width: padding)
            }
            ReplyHistory(model: messageModel.replyTarget)
            if messageModel.replyTarget.alignment == .trailing {
                Spacer().frame(width: padding)
            }
        }
    }

    private func renderReactions() -> some View {
        Text(reactionsModel.displayValue)
            .font(.callout)
            .fontWeight(.regular)
            .lineLimit(nil)
            .lineSpacing(5)
            .padding(5)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(model.backgroundColor, lineWidth: 0.8)
            )
            .padding(.trailing, 10)
            .padding(.leading, 30)
            .shadowForConversation()
            .measureSize()
            .onLongPressGesture(minimumDuration: 0.5) {
                self.showReactionsView(reactionsModel)
            }
            .onAppear {
                self.messageModel.reactionsModel.onAppear()
            }
            .padding(.bottom, 2)
    }
}
