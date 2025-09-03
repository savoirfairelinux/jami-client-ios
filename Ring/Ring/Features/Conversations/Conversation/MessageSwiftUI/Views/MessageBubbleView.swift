/*
 *  Copyright (C) 2023-2025 Savoir-faire Linux Inc.
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
import UIKit

struct MessageBubbleView: View {
    let messageModel: MessageContainerModel
    @StateObject var model: MessageContentVM
    @SwiftUI.State private var frame: CGRect = .zero
    @SwiftUI.State private var presentMenu = false
    @Environment(\.openURL)
    var openURL
    @Environment(\.colorScheme)
    var colorScheme
    @Environment(\.layoutDirection)
    var layoutDirection
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView) -> Void
    let padding: CGFloat = 12
    // swipe to reply
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
        VStack(alignment: .leading) {
            if model.messageDeleted {
                MessageBubbleWithEditionWrapper(model: model) {
                    Text(model.messageDeletedText)
                        .font(model.styling.secondaryFont)
                        .foregroundColor(model.editionColor)
                }
            } else {
                if model.type == .call {
                    renderCallMessage()
                } else if model.type == .fileTransfer {
                    MediaView(message: model, onLongGesture: receivedLongPress(), minHeight: 50, maxHeight: 300, withPlayerControls: true, cornerRadius: 0)
                } else if model.type == .text {
                    renderTextContent()
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Rectangle().fill(Color.clear)
                    .onAppear {
                        self.bubbleWidth = proxy.size.width
                    }
                    .onChange(of: presentMenu, perform: { _ in
                        if !presentMenu {
                            return
                        }
                        DispatchQueue.main.async {
                            let frame = proxy.frame(in: .global)
                            presentMenu = false
                            onLongPress(frame, self)
                        }
                    })
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.accessibilityLabelValue))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.preview.toString(), action: { model.contextMenuSelect(item: .preview) }), apply: model.menuItems.contains(.preview))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.forward.toString(), action: { model.contextMenuSelect(item: .forward) }), apply: model.menuItems.contains(.forward))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.share.toString(), action: { model.contextMenuSelect(item: .share) }), apply: model.menuItems.contains(.share))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.save.toString(), action: { model.contextMenuSelect(item: .save) }), apply: model.menuItems.contains(.save))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.copy.toString(), action: { model.contextMenuSelect(item: .copy) }), apply: model.menuItems.contains(.copy))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.reply.toString(), action: { model.contextMenuSelect(item: .reply) }), apply: model.menuItems.contains(.reply))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.deleteMessage.toString(), action: { model.contextMenuSelect(item: .deleteMessage) }), apply: model.menuItems.contains(.deleteMessage))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.deleteFile.toString(), action: { model.contextMenuSelect(item: .deleteFile) }), apply: model.menuItems.contains(.deleteFile))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.edit.toString(), action: { model.contextMenuSelect(item: .edit) }), apply: model.menuItems.contains(.edit))
        .accessibilityAddTraits(.isButton)
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

    private func renderCallMessage() -> some View {
        Text(model.content)
            .padding(.horizontal, model.textInset)
            .padding(.vertical, model.textVerticalInset)
            .foregroundColor(model.styling.textColor)
            .lineLimit(nil)
            .background(model.backgroundColor)
            .font(model.styling.textFont)
            .modifier(MessageCornerRadius(model: model))
    }

    private func renderTextContent() -> some View {
        Group {
            if let metadata = model.metadata {
                URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                    .modifier(MessageCornerRadius(model: model))
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            } else if model.content.isValidURL, let url = model.getURL() {
                MessageBubbleWithEditionWrapper(model: model) {
                    Text(model.content)
                        .font(model.styling.textFont)
                        .underline()
                        .onTapGesture {
                            openURL(url)
                        }
                        .modifier(MessageLongPress(longPressCb: receivedLongPress()))
                }
            } else {
                MessageBubbleWithEditionWrapper(model: model) {
                    Text(model.content)
                        .font(model.styling.textFont)
                        .lineLimit(nil)
                        .onTapGesture {
                            // Add an empty onTapGesture to keep the table view scrolling smooth
                        }
                        .modifier(MessageLongPress(longPressCb: receivedLongPress()))
                }
            }
        }
    }

    private func receivedLongPress() -> (() -> Void) {
        return {
            if model.menuItems.isEmpty { return }
            if suppressLongPress { return }
            presentMenu = true
        }
    }
}

struct MessageBubbleWithEditionWrapper<Content: View>: View {
    @ObservedObject var model: MessageContentVM
    let content: Content
    let messageEditedPadding: CGFloat = 4

    init(model: MessageContentVM, @ViewBuilder content: () -> Content) {
        self.model = model
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: messageEditedPadding) {
            content

            if model.messageEdited {
                editingIndicator()
            }
        }
        .applyMessageStyle(model: model)
    }

    private func editingIndicator() -> some View {
        HStack(spacing: 2) {
            Image(systemName: "pencil")
                .resizable()
                .font(Font.body.weight(.bold))
                .foregroundColor(model.editionColor)
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 12)
            Text(model.editIndicator)
                .font(.footnote)
                .foregroundColor(model.editionColor)
        }
    }
}

struct AccessibilityActionModifier: ViewModifier {
    let actionName: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text(actionName)) {
                action()
            }
    }
}

struct AccessibilityHintModifier: ViewModifier {
    let hint: String

    func body(content: Content) -> some View {
        content
            .accessibilityHint(Text(hint))
    }
}
