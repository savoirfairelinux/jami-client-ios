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

    var body: some View {
        ZStack {
            GeometryReader { _ in
                VStack(alignment: .leading) {
                    // message
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
                    Spacer()
                        .frame(height: 10)
                    // actions
                    makeActions()
                        .frame(width: model.menuSize.width)
                        .opacity(actionsOpacity)
                        .scaleEffect(actionsScale, anchor: model.actionsAnchor)
                        .offset(
                            x: model.menuOffsetX,
                            y: model.menuOffsetY
                        )
                }
                .offset(
                    x: model.messageFrame.origin.x,
                    y: model.messageFrame.origin.y + messageOffsetDiff
                )
            }
            .background(makeBackground())
        }
        .onTapGesture {
            presentingState = .willDismissWithoutAction
                withAnimation(Animation.easeOut(duration: 0.3)) {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    presentingState = .dismissed
                }
        }
        .onAppear(perform: {
            scrollViewHeight = model.messageFrame.height
            withAnimation(.easeOut(duration: 0.4)) {
                messageScale = model.scaleMessageUp ? 1.1 : 1.0
                messageShadow = 4
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
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
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2).delay(0.3)) {
                actionsScale = 1
            }
        })
        .edgesIgnoringSafeArea(.all)
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
