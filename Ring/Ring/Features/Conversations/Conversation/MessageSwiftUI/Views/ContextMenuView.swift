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
import MCEmojiPicker

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
    @SwiftUI.StateObject var model: ContextMenuVM
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
                    // emoji picker if short message, otherwise see below
                    if model.isShortMsg {
                        makeWithSpacers(elementForAlignment: makeEmojiBar())
                            .frame(width: UIScreen.main.bounds.size.width, alignment: model.isOurMsg! ? .trailing : .leading)
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
                    .frame(width: UIScreen.main.bounds.size.width, alignment: model.isOurMsg! ? .trailing : .leading)
                    // extra check for long messages to move reaction bar closer to the part of the screen where finger was last
                    if !model.isShortMsg {
                        makeWithSpacers(elementForAlignment: makeEmojiBar())
                            .frame(width: UIScreen.main.bounds.size.width, alignment: model.isOurMsg! ? .trailing : .leading)
                    } else {
                        Spacer()
                            .frame(height: model.defaultVerticalPadding)
                    }

                    ZStack {
                        // actions (reply, fwd, etc.)
                        makeWithSpacers(elementForAlignment: makeActions()
                                            .opacity(actionsOpacity)
                                            .scaleEffect(actionsScale, anchor: model.actionsAnchor)
                                            .frame(width: model.menuSize.width)
                        )
                        .frame(width: UIScreen.main.bounds.size.width, alignment: model.isOurMsg! ? .trailing : .leading)
                    }
                    .frame(width: UIScreen.main.bounds.size.width, alignment: model.isOurMsg! ? .trailing : .leading)
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
                model.isEmojiPickerPresented = false
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
                        model.isEmojiPickerPresented = false
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

    func makeActions() -> some View {
        VStack(spacing: 0) {
            ForEach(model.menuItems) { item in
                VStack(spacing: 0) {
                    Button {
                        let shouldShowKeyboard = item == .copy || item == .deleteMessage
                        let state: ContextMenuPresentingState = shouldShowKeyboard ? .willDismissWithAction : .willDismissWithTextEditingAction
                        model.isEmojiPickerPresented = false
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

    func makeActionsAccessibilityActions() {
        model.menuItems.forEach { item in
            // Adding accessibility action for each item
            self.accessibilityAction(named: Text(item.toString())) {
                // Directly call the method or trigger the action
                if let messageModel = model.presentingMessage?.model as? MessageContentVM {
                    messageModel.contextMenuSelect(item: item)
                    print("\(item.toString()) action triggered")
                } else {
                    print("Error: Unable to trigger action for \(item.toString())")
                }
            }
        }
    }

    func makeWithSpacers(elementForAlignment: some View) -> some View {
        HStack {
            if !model.isOurMsg! {
                Spacer()
                    .frame(width: model.incomingMessageMarginSize)
            }
            elementForAlignment
            if model.isOurMsg! {
                Spacer()
                    .frame(width: 10)
            }
        }
    }

    func makeEmojiBar() -> some View {
        EmojiBarView(cxModel: model, presentingState: $presentingState)
    }
}

struct EmojiBarView: View {
    @SwiftUI.StateObject var cxModel: ContextMenuVM
    @SwiftUI.State private var backgroundOpacity: CGFloat = 0.0
    @Binding var presentingState: ContextMenuPresentingState
    @SwiftUI.State private var messageShadow: CGFloat = 0.00
    @SwiftUI.State private var emojiPaletteButtonOpacity: Double = 0
    @SwiftUI.State private var emojiPaletteButtonOffset: Double = -12

    var emojipalette: some View {
        ZStack {
            Button(action: {
                cxModel.isEmojiPickerPresented.toggle()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(Color(cxModel.presentingMessage.model.preferencesColor))
            }.emojiPicker(
                isPresented: $cxModel.isEmojiPickerPresented,
                selectedEmoji: $cxModel.selectedEmoji
            )
        }
        .padding(.trailing, 5)
        .opacity(emojiPaletteButtonOpacity)
        .offset(x: emojiPaletteButtonOffset)
        .onAppear(perform: {
            cxModel.selectedEmoji = ""
            withAnimation(.easeOut(duration: 0.3).delay(0.1), {
                emojiPaletteButtonOffset = 8
                emojiPaletteButtonOpacity = 1
            })
        })
        .onChange(of: cxModel.selectedEmoji, perform: { newValue in
            if newValue != "" {
                cxModel.handleUpdatedReaction()
                cxModel.isEmojiPickerPresented = false
                presentingState = .willDismissWithAction
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    presentingState = .dismissed
                }
            }
        })
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                // add the emojipalette button with a plus sign
                emojipalette
                // then add defaults/favorites
                ForEach(cxModel.preferredUserReactions.indices, id: \.self) { index in
                    EmojiBarItemView(
                        cxModel: cxModel,
                        emoji: cxModel.preferredUserReactions[index],
                        presentingState: $presentingState,
                        elementOpacity: 1.0 as CGFloat,
                        delayIn: min(2.0, 0.03 * Double(index)),
                        elementRotation: Angle(degrees: 45)
                    )
                }
                // then add scrollable revokes not in the defaults
                ForEach(cxModel.uniqueAuthoredReactions.indices, id: \.self) { index in
                    EmojiBarItemView(
                        cxModel: cxModel,
                        emoji: cxModel.uniqueAuthoredReactions[index],
                        presentingState: $presentingState,
                        elementOpacity: 1.0 as CGFloat,
                        delayIn: min(2.0, 0.03 * Double(index)),
                        elementRotation: Angle(degrees: 45)
                    )
                }
                Spacer().frame(width: 2)
            }
            .frame(height: cxModel.emojiBarHeight)
        }
        .frame(width: cxModel.emojiBarMaxWidth, height: cxModel.emojiBarHeight)
        .opacity(1.0)
        .padding(.vertical, 1)
        .padding(.horizontal, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(radius: 32, corners: .allCorners)
        .shadow(color: Color(cxModel.shadowColor), radius: messageShadow)
        .onAppear(perform: {
            withAnimation(.easeOut(duration: 0.3)) {
                messageShadow = 2
            }
        })
    }
}

struct EmojiBarItemView: View {
    var cxModel: ContextMenuVM
    var emoji: String
    @Binding var presentingState: ContextMenuPresentingState
    @SwiftUI.State var elementOpacity: CGFloat
    @SwiftUI.State var delayIn: Double
    @SwiftUI.State var elementRotation: Angle
    @SwiftUI.State private var enabledNotifierLength: CGFloat = 0
    @SwiftUI.State private var enabledNotifierHeight: CGFloat = 0
    @SwiftUI.State private var fontSize: CGFloat = 0.0

    var body: some View {
        let emojiActive = cxModel.localUserAuthoredReaction(emoji: emoji)
        VStack(alignment: .center) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: enabledNotifierLength, height: enabledNotifierHeight, alignment: .center)
            Text(verbatim: emoji)
                .font(.title2)
                .opacity(elementOpacity)
                .rotationEffect(elementRotation)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(
                    // for adjusting the size of reactions in accordance with system font
                    GeometryReader { geometry in
                        Color.clear.onAppear {
                            self.fontSize = geometry.size.width
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.3, blendDuration: 0.9).delay(delayIn + 0.5)) {
                                self.enabledNotifierLength = round(12 + (fontSize / 6))
                                self.enabledNotifierHeight = round(0.5 + (fontSize / 24))
                            }
                        }
                    }
                )
            Rectangle()
                .fill(Color(cxModel.presentingMessage.model.preferencesColor))
                .opacity(emojiActive ? elementOpacity : 0)
                .frame(width: enabledNotifierLength, height: enabledNotifierHeight, alignment: .center)
                .cornerRadius(8)
        }
        .simultaneousGesture(
            // handles adding or removing the reaction from the ReactionRow for the displayed message
            TapGesture().onEnded({ _ in
                cxModel.selectedEmoji = emoji
            }))
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
