/*
 *  Copyright (C) 2022 - 2026 Savoir-faire Linux Inc.
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
    let style: UIBlurEffect.Style
    let withVibrancy: Bool

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
    @SwiftUI.State private var actionsScale: CGFloat = 0.00
    @SwiftUI.State private var messageScale: CGFloat = 1.00
    @SwiftUI.State private var messageShadow: CGFloat = 0.00
    @SwiftUI.State private var actionsOpacity: CGFloat = 0
    @SwiftUI.State private var backgroundOpacity: CGFloat = 0
    @SwiftUI.State private var messageOffsetDiff: CGFloat = 0
    @SwiftUI.State private var cornerRadius: CGFloat = 0
    @SwiftUI.State private var scrollViewHeight: CGFloat = 0
    @SwiftUI.State private var emojiBarOpacity: CGFloat = 0
    @SwiftUI.State private var messageOpacity: CGFloat = 1

    var body: some View {
        ZStack {
            GeometryReader { _ in
                VStack(alignment: .leading) {
                    Spacer()
                        .frame(height: model.defaultVerticalPadding)
                    // emoji picker if short message, otherwise see below
                    if model.isShortMsg {
                        makeWithSpacers(elementForAlignment: makeEmojiBar())
                            .frame(width: model.screenWidth, alignment: model.isOurMsg ? .trailing : .leading)
                            .opacity(emojiBarOpacity)
                        Spacer()
                            .frame(height: model.emojiVerticalPadding)
                    }
                    // message body in scrollable view
                    // message + tappable area
                    HStack {
                        if !model.isOurMsg {
                            Spacer()
                                .frame(width: model.incomingMessageMarginSize)
                        }
                        tappableMessageBody()
                            .opacity(messageOpacity)
                        if model.isOurMsg {
                            Spacer()
                                .frame(width: 10)
                        }
                    }
                    .frame(width: model.screenWidth, alignment: model.isOurMsg ? .trailing : .leading)
                    // extra check for long messages to move reaction bar closer to the part of the screen where finger was last
                    if !model.isShortMsg {
                        makeWithSpacers(elementForAlignment: makeEmojiBar())
                            .frame(width: model.screenWidth, alignment: model.isOurMsg ? .trailing : .leading)
                            .opacity(emojiBarOpacity)
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
                        .frame(width: model.screenWidth, alignment: model.isOurMsg ? .trailing : .leading)
                    }
                    .frame(width: model.screenWidth, alignment: model.isOurMsg ? .trailing : .leading)
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
            animateDismiss(state: .willDismissWithoutAction)
        }
        .onAppear(perform: {
            scrollViewHeight = model.messageFrame.height
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.prepare()
            impactMed.impactOccurred()

            withAnimation(.easeOut(duration: 0.25)) {
                messageScale = model.scaleMessageUp ? model.maxScaleFactor : 1.0
                messageShadow = 6
                backgroundOpacity = 0.3
                scrollViewHeight = model.messageHeight
                messageOffsetDiff = model.bottomOffset
                cornerRadius = model.menuCornerRadius
            }

            withAnimation(.easeOut(duration: 0.2).delay(0.15)) {
                emojiBarOpacity = 1
                actionsOpacity = 1
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0).delay(0.15)) {
                actionsScale = 1
            }
        })
        .edgesIgnoringSafeArea(.all)
    }

    func tappableMessageBody() -> some View {
        ZStack {
            ScrollView {
                model.presentingMessageView
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
                    animateDismiss(state: .willDismissWithoutAction)
                }
                .foregroundColor(Color.clear) // Make the Rectangle transparent
                .contentShape(Rectangle())
        }
    }

    func makeBackground() -> some View {
        let progress = backgroundOpacity / 0.3  // 0→1
        return ZStack {
            VisualEffect(style: .systemUltraThinMaterial, withVibrancy: false)
                .opacity(progress)
            Color.black.opacity(progress * 0.1)
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
                        model.contentVM?.contextMenuSelect(item: item)
                        animateDismiss(state: state, delay: 0.1)
                    } label: {
                        HStack {
                            Text(item.toString())
                                .font(.body)
                                .foregroundColor(item.isDestructive ? .red : Color(UIColor.label))
                            Spacer()
                            Image(systemName: item.image())
                                .foregroundColor(item.isDestructive ? .red : Color(UIColor.secondaryLabel))
                                .font(.body)
                                .frame(width: model.menuImageSize, alignment: .center)
                        }
                        .padding(.horizontal, model.menuPadding)
                        .frame(height: model.itemHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ContextMenuButtonStyle())
                    if model.menuItems.last != item {
                        Divider()
                            .padding(.leading, model.menuPadding)
                    }
                }
            }
        }
        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: model.menuCornerRadius, style: .continuous)))
    }

    func makeWithSpacers(elementForAlignment: some View) -> some View {
        HStack {
            if !model.isOurMsg {
                Spacer()
                    .frame(width: model.incomingMessageMarginSize)
            }
            elementForAlignment
            if model.isOurMsg {
                Spacer()
                    .frame(width: 10)
            }
        }
    }

    func makeEmojiBar() -> some View {
        EmojiBarView(cxModel: model, presentingState: $presentingState)
    }

    private func animateDismiss(state: ContextMenuPresentingState, delay: Double = 0.25) {
        presentingState = state
        model.isEmojiPickerPresented = false
        withAnimation(Animation.easeOut(duration: 0.2)) {
            scrollViewHeight = model.messageFrame.height
            messageScale = 1
            actionsScale = 0
            actionsOpacity = 0
            messageShadow = 0
            backgroundOpacity = 0
            messageOffsetDiff = 0
            cornerRadius = 0
            emojiBarOpacity = 0
            messageOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            presentingState = .dismissed
        }
    }
}

struct EmojiBarView: View {
    @ObservedObject var cxModel: ContextMenuVM
    @SwiftUI.State private var messageShadow: CGFloat = 0.00
    @SwiftUI.State private var emojiPaletteButtonOpacity: Double = 0
    @SwiftUI.State private var emojiPaletteButtonOffset: Double = -12
    @Binding var presentingState: ContextMenuPresentingState

    var emojipalette: some View {
        ZStack {
            Button(action: {
                cxModel.isEmojiPickerPresented.toggle()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(Color(cxModel.preferencesColor))
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
        .onChange(of: cxModel.selectedEmoji) { newValue in
            if !newValue.isEmpty {
                cxModel.handleUpdatedReaction()
                cxModel.isEmojiPickerPresented = false
                presentingState = .willDismissWithAction
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    presentingState = .dismissed
                }
            }
        }
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
                        initialOpacity: 1.0,
                        delayIn: min(2.0, 0.03 * Double(index)),
                        initialRotation: Angle(degrees: 45)
                    )
                }
                // then add scrollable revokes not in the defaults
                ForEach(cxModel.uniqueAuthoredReactions.indices, id: \.self) { index in
                    EmojiBarItemView(
                        cxModel: cxModel,
                        emoji: cxModel.uniqueAuthoredReactions[index],
                        presentingState: $presentingState,
                        initialOpacity: 1.0,
                        delayIn: min(2.0, 0.03 * Double(index)),
                        initialRotation: Angle(degrees: 45)
                    )
                }
                Spacer().frame(width: 2)
            }
            .frame(height: cxModel.emojiBarHeight)
        }
        .frame(width: cxModel.emojiBarMaxWidth, height: cxModel.emojiBarHeight)
        .padding(.vertical, 1)
        .padding(.horizontal, 8)
        .modifier(GlassModifier(shape: Capsule()))
        .shadow(color: Color(cxModel.shadowColor), radius: messageShadow)
        .onAppear(perform: {
            withAnimation(.easeOut(duration: 0.3)) {
                messageShadow = 2
            }
        })
    }
}

struct EmojiBarItemView: View {
    let cxModel: ContextMenuVM
    let emoji: String
    @Binding var presentingState: ContextMenuPresentingState
    let initialOpacity: CGFloat
    let delayIn: Double
    let initialRotation: Angle
    @SwiftUI.State private var elementOpacity: CGFloat = 0
    @SwiftUI.State private var elementRotation: Angle = Angle(degrees: 45)
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
                .fill(Color(cxModel.preferencesColor))
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
            elementOpacity = initialOpacity
            elementRotation = initialRotation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(delayIn)) {
                elementOpacity = 1
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.3).delay(delayIn)) {
                elementRotation = Angle(degrees: initialRotation.degrees / -2)
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0.5).delay(delayIn + 0.3)) {
                elementRotation = Angle(degrees: 0)
            }
        }
    }

}

// MARK: - view modifiers

private struct GlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(in: shape)
        } else {
            content
                .background(
                    ZStack {
                        VisualEffect(style: .systemUltraThinMaterial, withVibrancy: false)
                        Color.white.opacity(0.08)
                    }
                    .clipShape(shape)
                )
                .overlay(
                    shape
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                .clipShape(shape)
        }
    }
}

private struct ContextMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(UIColor.systemGray4).opacity(0.5) : Color.clear)
    }
}
