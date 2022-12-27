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
    @SwiftUI.State var style: UIBlurEffect.Style // 1
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
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
    @SwiftUI.State private var messageScale: CGFloat = 1.00
    @SwiftUI.State private var messageShadow: CGFloat = 0.00
    @SwiftUI.State private var actionsOpacity: CGFloat = 0
    @SwiftUI.State private var backgroundOpacity: CGFloat = 0
    @SwiftUI.State private var messageOffsetDiff: CGFloat = 0
    @SwiftUI.State private var cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            // background
            makeBackground()
            GeometryReader { _ in
                VStack(alignment: .leading) {
                    // message
                    model.presentingMessage
                        .cornerRadius(cornerRadius)
                        .scaleEffect(messageScale, anchor: model.messsageAnchor)
                        .shadow(color: Color(UIColor.lightGray), radius: messageShadow)
                        .frame(
                            width: model.messageFrame.width,
                            height: model.messageFrame.height
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
        }
        .onTapGesture {
            withAnimation(Animation.easeOut(duration: 0.3)) {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showContextMenu = false
            }
        }
        .onAppear(perform: {
            withAnimation(.easeOut(duration: 0.4)) {
                messageScale = model.scaleDown ? 0.8 : 1.1
                messageShadow = 4
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                blurAmount = 10
                backgroundScale = 0.96
                backgroundOpacity = 0.3
                actionsOpacity = 1
                messageOffsetDiff = model.bottomOffset
                cornerRadius = 6
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
                .opacity(actionsOpacity)
            if let snapshot = model.currentSnapshot, let image = snapshot.fillPartOfImage(frame: model.messageFrame, with: UIColor.systemBackground) {
                Image(uiImage: image)
                    .scaleEffect(backgroundScale, anchor: .center)
                    .blur(radius: blurAmount)
            }
            VisualEffect(style: .systemUltraThinMaterialDark)
                .opacity(backgroundOpacity)
        }
        .edgesIgnoringSafeArea(.all)
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
        .background(VisualEffect(style: .systemChromeMaterial))
        .cornerRadius(radius: model.menuCornerRadius, corners: .allCorners)
    }
}
