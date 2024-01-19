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
    @Binding var showContextMenu: Bool
    // animations
    @SwiftUI.State private var blurAmount = 0.0
    @SwiftUI.State private var backgroundScale: CGFloat = 1.00
    @SwiftUI.State private var actionsScale: CGFloat = 0.00
    @SwiftUI.State private var messageScaleY: CGFloat = 1.00
    @SwiftUI.State private var messageShadow: CGFloat = 0.00
    @SwiftUI.State private var actionsOpacity: CGFloat = 0
    @SwiftUI.State private var backgroundOpacity: CGFloat = 0
    @SwiftUI.State private var messageOffsetDiff: CGFloat = 0
    @SwiftUI.State private var cornerRadius: CGFloat = 0
    @SwiftUI.State private var scrollViewHeight: CGFloat = 0
    @SwiftUI.State private var isShortMessage: Bool = true

    // TODO drag up on thumbs up to open emoji picker
    var body: some View {
        // used for alignment of emoji bar
        // TODO cleanup alignment logic of emoji bar
        let isOurMsg = !model.presentingMessage.messageModel.message.incoming
        ZStack {
            GeometryReader { _ in
                VStack(alignment: .leading) {
                    Spacer()
                        .frame(maxHeight: 6)
                    // emoji picker
                    HStack {
                        Spacer()
                            .frame(maxWidth: isOurMsg ? screenWidth : 10)
                        makeEmojiSelector()
                            .opacity(actionsOpacity)
                            .padding(8)
                            .background(Color(UIColor.jamiBackgroundColor))
                            .cornerRadius(radius: 16.0, corners: .allCorners)
                        Spacer()
                            .frame(maxWidth: isOurMsg ? 10 : screenWidth)
                    }
                    .frame(width: screenWidth)
//                    .offset(x: 0)
//                    makeEmojiSelector()
//                        
//                        .alig
//                        .offset(x: model.presentingMessage.messageModel.message.incoming ? 0 : -(model.emojiBarSize.width) + (model.messageFrame.width))
////                        .offset(x: !model.presentingMessage.messageModel.message.incoming ? -((5 * 42) + 16) + (model.messageFrame.width) : 0)
                    Spacer()
                        .frame(maxHeight: 6)
                    // message + tappable area
                    clickableMessageBody()
                    Spacer()
                        .frame(height: 8)
                    // actions (reply, fwd, etc.)
                    makeActions()
                        .frame(width: model.menuSize.width * messageScaleY)
                        .opacity(actionsOpacity)
                        .scaleEffect(actionsScale, anchor: model.actionsAnchor)
                        .offset(
                            x: 0,//model.menuOffsetX,
                            y: model.menuOffsetY * messageScaleY
                        )
                }
                .offset(
                    x: 0,//model.messageFrame.origin.x,
                    y: max(0, model.messageFrame.origin.y + messageOffsetDiff - (6 + 8 + 4)) // for emojiBar
                )
            }
            .background(makeBackground())
        }
        .onTapGesture {
            withAnimation(Animation.easeOut(duration: 0.3)) {
                scrollViewHeight = model.messageFrame.height// * messageScale
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showContextMenu = false
            }
        }
        .onAppear(perform: {
            scrollViewHeight = model.messageFrame.height * messageScaleY
            withAnimation(.easeOut(duration: 0.3)) {
                messageScaleY = model.scaleMessageUp ? 1.1 : 1.0
//                messageScale = model.scaleMessageUp ? 1.1 : 1.0
                messageShadow = 4
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.15)) {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                blurAmount = 10
                backgroundScale = 0.96
                backgroundOpacity = 0.3
                actionsOpacity = 1
                scrollViewHeight = model.messageHeight * messageScaleY
                messageOffsetDiff = model.bottomOffset - (isShortMessage ? model.emojiBarSize.height : 0) * messageScaleY
                cornerRadius = model.menuCornerRadius
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(0.15)) {
                actionsScale = 1
            }
        })
        .edgesIgnoringSafeArea(.all)
    }

    func clickableMessageBody() -> some View {
        ZStack {
            ScrollView {
                model.presentingMessage
                    .padding(
                        .vertical, 6
                    )
                    .frame(
                        width: model.messageFrame.width,
                        height: scrollViewHeight
                    )
            }
            .cornerRadius(cornerRadius)
            .scaleEffect(messageScaleY, anchor: model.messsageAnchor)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showContextMenu = false
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
                        emoji: Binding(
                            get: { defaultReactionEmojis[index] },
                            set: { _ in }
                        ),
                        showContextMenu: $showContextMenu,
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
                        showContextMenu = false
                        model.presentingMessage.model.contextMenuSelect(item: item)
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
    @Binding var emoji: UTF32Char
    @Binding var showContextMenu: Bool
    @SwiftUI.State var elementOpacity: CGFloat
    @SwiftUI.State var delayIn: Double
    @SwiftUI.State var elementRotation: Angle
    
    var body: some View {
        let displayableEmoji: String = String(UnicodeScalar(emoji)!)
        let emojiActive = model.presentingMessage.messageModel.reactionsModel.displayValue.containsCaseInsentative(string: displayableEmoji)
        Button(action: {
            model.sendEmoji(value: displayableEmoji, emojiActive: emojiActive)
            showContextMenu = false
        }) {
            Text(verbatim: displayableEmoji)
                .font(.title3)
                .opacity(elementOpacity)
                .rotationEffect(elementRotation)
                .cornerRadius(radius: 16, corners: .allCorners)
//                .opacity(emojiActive ? 0.5 : 1.0)
        }
        .rotationEffect(elementRotation)
        .padding(6)
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
