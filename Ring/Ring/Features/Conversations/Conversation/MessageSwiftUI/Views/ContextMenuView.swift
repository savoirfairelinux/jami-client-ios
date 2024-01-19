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
    @SwiftUI.State private var messageScaleY: CGFloat = 1.00
    @SwiftUI.State private var messageShadow: CGFloat = 0.00
    @SwiftUI.State private var actionsOpacity: CGFloat = 0
    @SwiftUI.State private var backgroundOpacity: CGFloat = 0
    @SwiftUI.State private var messageOffsetDiff: CGFloat = 0
    @SwiftUI.State private var messageOffsetTop: CGFloat = 0
    @SwiftUI.State private var cornerRadius: CGFloat = 0
    @SwiftUI.State private var scrollViewHeight: CGFloat = 0
    @SwiftUI.State private var isShortMessage: Bool = true
    @SwiftUI.State private var animSpeed: Double = 0.3
    @SwiftUI.State private var globalOffset: CGFloat = 0.0

    // TODO drag up on thumbs up to open emoji picker
    var body: some View {
        // used for alignment of emoji bar
        // TODO cleanup alignment logic of emoji bar
//<<<<<<< HEAD
//        let isOurMsg = model.presentingMessage.messageModel.message.authorId.isEmpty
//        ZStack {
//            GeometryReader { _ in
//                VStack(alignment: .leading) {
//                    Spacer()
//                        .frame(maxHeight: model.defaultVerticalPadding)
//                    // emoji picker
//                    makeEmojiSelector()
//                        .opacity(actionsOpacity)
//                        .padding(4)
//                        .background(Color(UIColor.jamiBackgroundColor))
//                        .cornerRadius(radius: 16.0, corners: .allCorners)
//                        .offset(x: isOurMsg ? -((5 * 42) + 16) + (model.messageFrame.width) : 0)
//                    Spacer()
//                        .frame(maxHeight: model.emojiVerticalPadding)
//                    // message + tappable area
//                    clickableMessageBody()
//                    Spacer()
//                        .frame(height: model.defaultVerticalPadding)
//                    // actions (reply, fwd, etc.)
//                    makeActions()
//                        .frame(width: model.menuSize.width)
//                        .opacity(actionsOpacity)
//                        .scaleEffect(actionsScale, anchor: model.actionsAnchor)
//                        .offset(
//                            x: model.menuOffsetX,
//                            y: model.menuOffsetY
//                        )
//                }
//                .offset(
//                    x: model.messageFrame.origin.x,
//                    y: max(0, model.messageFrame.origin.y + messageOffsetDiff - (6 + 8 + 4)) // for emojiBar
//=======
        let isOurMsg = !model.presentingMessage.messageModel.message.incoming
        let isShortMsg = model.messageHeight < screenHeight / 3.3// ||  model.presentingMessage.messageModel.message.content.count < 200
        let margSize: CGFloat = 30.0
        let animSpeed: Double = animSpeed
        // VStack containing all the reactions/actions for a message
        VStack {
            // emoji picker / emoji bar
            if isShortMsg {
                HStack {
                    Spacer()
                        .frame(width: isOurMsg ? 0 : margSize)
                    makeEmojiSelector()
                        .opacity(actionsOpacity)
                        .padding(0)
                        .background(Color(UIColor.jamiBackgroundSecondaryColor))
                        .cornerRadius(radius: 16.0, corners: .allCorners)
                    Spacer()
                        .frame(width: isOurMsg ? margSize : 0)
                }
                .frame(width: screenWidth, alignment: isOurMsg ? .trailing : .leading)
                .padding(.bottom, 2)
            }
            // message body in scrollable view
            // message + tappable area
            HStack {
                Spacer()
                    .frame(width: isOurMsg ? 0 : margSize)
                clickableMessageBody()
//                    .opacity(actionsOpacity)
                Spacer()
                    .frame(width: isOurMsg ? margSize : 0)
            }
                .frame(width: screenWidth, alignment: isOurMsg ? .trailing : .leading)
                .padding(.bottom, 0)
            // extra check for long messages to move emojis closer to the touch center
            if !isShortMsg {
                HStack {
                    Spacer()
                        .frame(width: isOurMsg ? 0 : margSize)
                    makeEmojiSelector()
                        .opacity(actionsOpacity)
                        .padding(0)
                        .background(Color(UIColor.jamiBackgroundSecondaryColor))
                        .cornerRadius(radius: 16.0, corners: .allCorners)
                    Spacer()
                        .frame(width: isOurMsg ? margSize : 0)
                }
                .frame(width: screenWidth, alignment: isOurMsg ? .trailing : .leading)
                .padding(.bottom, 0)
            }
            // message actions (reply, fwd, etc.)
            HStack {
                Spacer()
                    .frame(width: isOurMsg ? 0 : margSize)
                makeActions()
                    .opacity(actionsOpacity)
                    .scaleEffect(actionsScale, anchor: model.actionsAnchor)
                    .frame(width: model.menuSize.width)
                Spacer()
                    .frame(width: isOurMsg ? margSize : 0)
            }
            .frame(width: screenWidth, alignment: isOurMsg ? .trailing : .leading)
            .padding(.bottom, 0)
            // handles animation of message on hover
            Rectangle()
                .background(Color.red)
                .opacity(0)
                .frame(
                    width: 40,//model.messageFrame.width,
                    height: globalOffset
                )
                .onAppear(perform: {
                    globalOffset = model.messageFrame.origin.y + messageOffsetDiff - 2
//                    globalOffset = model.initialTopOffset
                    withAnimation(.easeOut(duration: animSpeed)) {
//                        globalOffset = model.finalTopOffset
                    }
                })
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .bottom)
//        .offset(y: -40)
        .background(makeBackground())
        .opacity(min(1.0, actionsOpacity * 3.0))
        .onTapGesture {
            presentingState = .willDismissWithoutAction
            withAnimation(Animation.easeOut(duration: 0.1)) {
                scrollViewHeight = model.messageFrame.height
                blurAmount = 0
                backgroundScale = 1.00
                messageScaleY = 1
                actionsScale = 0.00
                actionsOpacity = 0
                messageShadow = 0
                backgroundOpacity = 0
                messageOffsetDiff = 0
                cornerRadius = 0
            }
//<<<<<<< HEAD
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                presentingState = .dismissed
            }
        }
        .onAppear(perform: {
            scrollViewHeight = model.messageFrame.height
            withAnimation(.easeOut(duration: 0.3)) {
                messageScaleY = model.scaleMessageUp ? model.maxScaleFactor : 1.0
                messageShadow = 4
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.15)) {
//=======
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                showContextMenu = false
//            }
//        }
//        .onAppear(perform: {
//            scrollViewHeight = model.messageFrame.height * messageScaleY
//            withAnimation(.easeOut(duration: 0.3)) {
//                messageScaleY = model.scaleMessageUp ? 1.1 : 1.0
//                messageShadow = 4
//            }
//            withAnimation(.easeIn(duration: animSpeed).delay(0.15)) {
//>>>>>>> c5d94aa1 ((WIP) iOS: emoji picker)
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                blurAmount = 10
                backgroundScale = 0.96
                backgroundOpacity = 0.3
                actionsOpacity = 1
                scrollViewHeight = model.messageHeight * messageScaleY
//                messageOffsetDiff = model.finalBottomOffset - (isShortMessage ? model.emojiBarSize.height : 0) * messageScaleY
                cornerRadius = model.menuCornerRadius
            }
//<<<<<<< HEAD
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(0.15)) {
//=======
//            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: animSpeed / 3.0 * 2.0).delay(0.15)) {
//>>>>>>> c5d94aa1 ((WIP) iOS: emoji picker)
                actionsScale = 1
            }
        })
        .edgesIgnoringSafeArea(.all)
    }

    func clickableMessageBody() -> some View {
        ZStack {
            ScrollView {
                model.presentingMessage
//<<<<<<< HEAD
                    .frame(
                        width: model.messageFrame.width,
                        height: scrollViewHeight
                    )
            }
            .cornerRadius(cornerRadius)
            .scaleEffect(messageScaleY, anchor: model.messsageAnchor)
//=======
//                    .padding(
//                        .vertical, 6
//                    )
//            }
//            .cornerRadius(cornerRadius)
//            .scaleEffect(messageScaleY, anchor: model.messsageAnchor)
//>>>>>>> c5d94aa1 ((WIP) iOS: emoji picker)
            .shadow(color: Color(model.shadowColor), radius: messageShadow)
            .frame(
                width: model.messageFrame.width,
                height: scrollViewHeight
            )
            // invisible tap area for accessibility
            Rectangle()
                .cornerRadius(cornerRadius)
                .scaleEffect(messageScaleY, anchor: model.messsageAnchor)
                .shadow(color: Color(model.shadowColor), radius: messageShadow)
                .frame(
                    width: model.messageFrame.width,
                    height: scrollViewHeight
                )
                .onTapGesture {
                    presentingState = .willDismissWithoutAction
                    withAnimation(Animation.easeOut(duration: 0.1)) {
//                    withAnimation(Animation.easeOut(duration: animSpeed)) {
                        scrollViewHeight = model.messageFrame.height
                        blurAmount = 0
                        backgroundScale = 1.00
                        messageScaleY = 1
                        actionsScale = 0.00
                        actionsOpacity = 0
                        messageShadow = 0
                        backgroundOpacity = 0
                        messageOffsetDiff = 0
                        cornerRadius = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        presentingState = .dismissed
//                    DispatchQueue.main.asyncAfter(deadline: .now() + animSpeed + 0.2) {
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
            VisualEffect(style: .regular, withVibrancy: false)
            Color(UIColor.tertiaryLabel)
                .opacity(backgroundOpacity)
        }
        .edgesIgnoringSafeArea(.all)
    }

    func makeEmojiSelector() -> some View {
        HStack {
            let defaultReactionEmojis: [UTF32Char] = [UTF32Char(0x1F44D), UTF32Char(0x1F44E), UTF32Char(0x1F606), UTF32Char(0x1F923), UTF32Char(0x1F615)]
                                                      //, UTF32Char(0xFE0F)]

            if #available(iOS 15.0, *) {
                ForEach(defaultReactionEmojis.indices, id: \.self) { index in
                    AnimatableWrapperView(
                        model: model,
                        emoji: defaultReactionEmojis[index],
//<<<<<<< HEAD
                        presentingState: $presentingState,
//=======
//                        showContextMenu: $showContextMenu,
//>>>>>>> c5d94aa1 ((WIP) iOS: emoji picker)
                        elementOpacity: 0.0 as CGFloat,
                        delayIn: 0.03 * Double(index),
                        elementRotation: Angle(degrees: 10.0 * Double(defaultReactionEmojis.count))
                    )
                }
            } else {
                // Fallback on earlier versions
            }

        }
        .frame(width: model.emojiBarSize.width, height: model.emojiBarSize.height)
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

@available(iOS 15.0, *)
struct EmojiMoreButton: View {
    var model: ContextMenuVM
    @Binding var emoji: UTF32Char
    @SwiftUI.State var elementOpacity: CGFloat
    @SwiftUI.State var delayIn: Double

    var body: some View {
        let displayableEmoji: String = String(UnicodeScalar(emoji)!)
        Button(action: {
            // UNINPLEMENTED TODO display all emoji
        }) {
            Text(verbatim: displayableEmoji)
                .font(.title3)
                .opacity(elementOpacity)
                .cornerRadius(radius: 16, corners: .allCorners)

        }
        .padding(6)
        .onAppear {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(delayIn)) {
                elementOpacity = 1
            }
        }
    }

    func updateElementOpacity(_ newOpacity: CGFloat) {
        elementOpacity = newOpacity
    }

}

@available(iOS 15.0, *)
struct AnimatableWrapperView: View {
    var model: ContextMenuVM
    var emoji: UTF32Char
    @Binding var presentingState: ContextMenuPresentingState
    @SwiftUI.State var elementOpacity: CGFloat
    @SwiftUI.State var delayIn: Double
    @SwiftUI.State var elementRotation: Angle
    
    var body: some View {
        let displayableEmoji: String = String(UnicodeScalar(emoji)!)
        let emojiActive = model.presentingMessage.messageModel.reactionsModel.displayValue.containsCaseInsentative(string: displayableEmoji)
        Button(action: {
            model.sendEmoji(value: displayableEmoji, emojiActive: emojiActive)
        }) {
            Text(verbatim: displayableEmoji)
                .font(.title2)
                .opacity(elementOpacity)
                .rotationEffect(elementRotation)
        }
//        .rotationEffect(elementRotation)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(emojiActive ? Color(model.presentingMessage.messageModel.theSwarmColor).opacity(0.35) : Color(UIColor.jamiBackgroundSecondaryColor))
        .cornerRadius(radius: 32, corners: .allCorners)
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

    func updateElementOpacity(_ newOpacity: CGFloat) {
        elementOpacity = newOpacity
    }

}
