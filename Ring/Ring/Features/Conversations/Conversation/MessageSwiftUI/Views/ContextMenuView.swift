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

enum ContextMenuPresentingState {
    case none
    case shouldPresent
    case willDismissWithoutAction
    case willDismissWithTextEditingAction
    case willDismissWithAction
    case dismissed
}

struct VisualEffect: UIViewRepresentable {
    @SwiftUI.State var style: UIBlurEffect.Style
    var withVibrancy: Bool

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let effect = withVibrancy ? UIVibrancyEffect(blurEffect: blurEffect) : blurEffect
        return UIVisualEffectView(effect: effect)
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
    }
}

struct ContextMenuView: View {
    var model: ContextMenuVM
    @Binding var presentingState: ContextMenuPresentingState
    // animations
    @SwiftUI.State private var blurAmount = 0.0
    @SwiftUI.State private var backgroundScale: CGFloat = 1.00
    @SwiftUI.State private var actionsScale: CGFloat = 0.00
    @SwiftUI.State private var messageScale: CGFloat = 1.00
    @SwiftUI.State private var messageShadow: CGFloat = 0.00
    @SwiftUI.State private var actionsOpacity: CGFloat = 0
    @SwiftUI.State private var backgroundOpacity: CGFloat = 0
    @SwiftUI.State private var messageOffsetDiff: CGFloat = 0
    @SwiftUI.State private var cornerRadius: CGFloat = 0
    @SwiftUI.State private var scrollViewHeight: CGFloat = 0
    @SwiftUI.GestureState private var isLongPressingEmojiBar = false

    var body: some View {
        ZStack {
            GeometryReader { _ in
                VStack(alignment: .leading) {
                    Spacer()
                        .frame(height: model.defaultVerticalPadding)
                    // emoji picker
                    if model.isShortMsg {
                        HStack {
                            if !model.isOurMsg! {
                                Spacer()
                                    .frame(width: model.incomingMessageMarginSize)
                            }
                            makeEmojiBar()
                            if model.isOurMsg! {
                                Spacer()
                                    .frame(width: 10)
                            }
                        }
                        .frame(width: screenWidth, alignment: model.isOurMsg! ? .trailing : .leading)
                        Spacer()
                            .frame(height: model.emojiVerticalPadding)
                    }
                    // message body in scrollable view
                    // message + tappable area
                    HStack {
                        if !model.isOurMsg! {
                            Spacer()
                                .frame(width: model.incomingMessageMarginSize)
                        }
                        tappableMessageBody()
                        if model.isOurMsg! {
                            Spacer()
                                .frame(width: 10)
                        }
                    }
                    .frame(width: screenWidth, alignment: model.isOurMsg! ? .trailing : .leading)
                    // extra check for long messages to move emojis closer to the touch center
                    if !model.isShortMsg {
                        HStack {
                            if !model.isOurMsg! {
                                Spacer()
                                    .frame(width: model.incomingMessageMarginSize)
                            }
                            makeEmojiBar()
                            if model.isOurMsg! {
                                Spacer()
                                    .frame(width: 10)
                            }
                        }
                        .frame(width: screenWidth, alignment: model.isOurMsg! ? .trailing : .leading)
                    } else {
                        Spacer()
                            .frame(height: model.defaultVerticalPadding)
                    }
                    // actions (reply, fwd, etc.)
                    HStack {
                        if !model.isOurMsg! {
                            Spacer()
                                .frame(width: model.incomingMessageMarginSize)
                        }
                        makeActions()
                            .opacity(actionsOpacity)
                            .scaleEffect(actionsScale, anchor: model.actionsAnchor)
                            .frame(width: model.menuSize.width)
                        if model.isOurMsg! {
                            Spacer()
                                .frame(width: 10)
                        }
                    }
                    .frame(width: screenWidth, alignment: model.isOurMsg! ? .trailing : .leading)
                }
                .padding(.trailing, 4)
            }
            .offset( // offset vstack
                x: 0,
                y: max(0, model.messageFrame.origin.y + messageOffsetDiff - (model.isShortMsg ? model.emojiBarHeight : 0))
            )

        }
        .background(makeBackground())
        .onTapGesture {
            presentingState = .willDismissWithoutAction
            withAnimation(Animation.easeOut(duration: 0.1)) {
                scrollViewHeight = model.messageFrame.height
                blurAmount = 0
                backgroundScale = 1.00
                messageScale = 1
                actionsScale = 0.00
                actionsOpacity = 0
                messageShadow = 0
                backgroundOpacity = 0
                messageOffsetDiff = 0
                cornerRadius = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                presentingState = .dismissed
            }
        }
        .onAppear(perform: {
            scrollViewHeight = model.messageFrame.height
            withAnimation(.easeOut(duration: 0.3)) {
                messageScale = model.scaleMessageUp ? model.maxScaleFactor : 1.0
                messageShadow = 4
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.15)) {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                blurAmount = 10
                backgroundScale = 0.96
                backgroundOpacity = 0.3
                actionsOpacity = 1
                scrollViewHeight = model.messageHeight
                messageOffsetDiff = model.bottomOffset
                cornerRadius = model.menuCornerRadius
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(0.15)) {
                actionsScale = 1
            }
        })
        .edgesIgnoringSafeArea(.all)
    }

    func tappableMessageBody() -> some View {
        ZStack {
            ScrollView {
                model.presentingMessage
                    .frame(
                        width: model.messageFrame.width,
                        height: model.messageFrame.height
                    )

            }
            .cornerRadius(cornerRadius)
            .scaleEffect(messageScale, anchor: model.messsageAnchor)
            .shadow(color: Color(model.shadowColor), radius: messageShadow)
            .frame(
                width: model.messageFrame.width,
                height: scrollViewHeight
            )
            // invisible tap area for accessibility
            Rectangle()
                .cornerRadius(cornerRadius)
                .scaleEffect(messageScale, anchor: model.messsageAnchor)
                .frame(
                    width: model.messageFrame.width,
                    height: scrollViewHeight
                )
                .onTapGesture {
                    presentingState = .willDismissWithoutAction
                    withAnimation(Animation.easeOut(duration: 0.1)) {
                        scrollViewHeight = model.messageFrame.height
                        blurAmount = 0
                        backgroundScale = 1.00
                        messageScale = 1
                        actionsScale = 0.00
                        actionsOpacity = 0
                        messageShadow = 0
                        backgroundOpacity = 0
                        messageOffsetDiff = 0
                        cornerRadius = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        presentingState = .dismissed
                    }
                }
                .foregroundColor(Color.clear) // Make the Rectangle transparent
                .contentShape(Rectangle())
        }
    }

    func makeBackground() -> some View {
        ZStack {
            Color(UIColor.systemBackground)
                .opacity(backgroundOpacity)
            Color(UIColor.systemBackground)
                .frame(width: model.messageFrame.width, height: model.messageFrame.height)
                .position(x: model.messageFrame.midX, y: model.messageFrame.midY)
            VisualEffect(style: .regular, withVibrancy: false)
            Color(UIColor.tertiaryLabel)
                .opacity(backgroundOpacity)
        }
        .edgesIgnoringSafeArea(.all)
    }

    func makeEmojiBar() -> some View {
        HStack {
            let defaultReactionEmojis: [String] = [
                0x1F44D, 0x1F44E, 0x1F606, 0x1F923, 0x1F615
            ].map { String(UnicodeScalar($0)!) }

            ForEach(defaultReactionEmojis.indices, id: \.self) { index in
                EmojiBarView(
                    model: model,
                    emoji: defaultReactionEmojis[index],
                    presentingState: $presentingState,
                    elementOpacity: 0.0 as CGFloat,
                    delayIn: 0.03 * Double(index),
                    elementRotation: Angle(degrees: 45.0)
                )
            }

        }
        .opacity(actionsOpacity)
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(radius: 32, corners: .allCorners)
        .shadow(color: Color(model.shadowColor), radius: messageShadow)
    }

    func makeActions() -> some View {
        VStack(spacing: 0) {
            ForEach(model.menuItems) { item in
                VStack(spacing: 0) {
                    Button {
                        let shouldShowKeyboard = item == .copy || item == .deleteMessage
                        let state: ContextMenuPresentingState = shouldShowKeyboard ? .willDismissWithAction : .willDismissWithTextEditingAction
                        presentingState = state
                        model.presentingMessage.model.contextMenuSelect(item: item)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            presentingState = .dismissed
                        }
                    } label: {
                        HStack {
                            Spacer()
                                .frame(width: model.menuPadding)
                            Text(item.toString())
                                .font(.callout)
                                .fontWeight(.light)
                                .foregroundColor(Color(UIColor.label))
                            Spacer()

                            Image(systemName: item.image())
                                .foregroundColor(Color(UIColor.label))
                                .font(Font.callout.weight(.light))
                                .frame(maxHeight: model.menuImageSize)
                            Spacer()
                                .frame(width: model.menuPadding)
                        }
                        .frame(height: model.itemHeight)
                    }
                    if model.menuItems.last != item {
                        Divider()
                    }
                }
            }
        }
        .background(VisualEffect(style: .systemUltraThinMaterial, withVibrancy: true))
        .background(VisualEffect(style: .systemChromeMaterial, withVibrancy: false))
        .cornerRadius(radius: model.menuCornerRadius, corners: .allCorners)
    }
}

struct EmojiBarView: View {
    var model: ContextMenuVM
    var emoji: String
    @Binding var presentingState: ContextMenuPresentingState
    @SwiftUI.State var elementOpacity: CGFloat
    @SwiftUI.State var delayIn: Double
    @SwiftUI.State var elementRotation: Angle
    @SwiftUI.State private var enabledNotifierLength: CGFloat = 0
    @SwiftUI.State private var hightligthColor: UIColor = UIColor.defaultSwarmColor

    var body: some View {
        let emojiActive = model.localUserAuthoredReaction(emoji: emoji)
        VStack {
            Text(verbatim: emoji)
                .font(.title2)
                .opacity(elementOpacity)
                .rotationEffect(elementRotation)
                .padding(8)
                .overlay(
                    Rectangle()
                        .fill(Color(hightligthColor))
                        .opacity(emojiActive ? elementOpacity : 0)
                        .frame(width: enabledNotifierLength, height: 3, alignment: .center)
                        .cornerRadius(8)
                        .offset(y: 20)
                        .onAppear(perform: {
                            hightligthColor = model.presentingMessage.model.preferencesColor
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.3, blendDuration: 0.9).delay(delayIn + 0.5)) {
                                enabledNotifierLength = 20
                            }
                        })
                )
        }
        .simultaneousGesture(
            // handles adding or removing the default reactions from a message
            TapGesture().onEnded({ _ in
                DispatchQueue.main.async {
                    switch emojiActive {
                    case false:
                        model.sendReaction(value: emoji)
                    case true:
                        let reactionMsgId: String =
                            model.presentingMessage.model.message.reactions.first(where: {
                                item in item.author == model.currentJamiAccountId && item.content == emoji
                            })!.id
                        model.revokeReaction(value: emoji, reactionId: reactionMsgId)
                    }
                    presentingState = .dismissed
                }
            }))
        .padding(4)
        .onAppear {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(delayIn)) {
                elementOpacity = 1
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.3).delay(delayIn)) {
                elementRotation = Angle(degrees: elementRotation.degrees / -2)
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0.5).delay(delayIn + 0.3)) {
                elementRotation = Angle(degrees: 0)
            }
        }
    }

}
