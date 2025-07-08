/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

let maxButtonsWidgetHeight: CGFloat = ScreenDimensionsManager.shared.adaptiveHeight * 0.7
let avatarSize: CGFloat = 160

var avatarOffset: CGFloat {
    ScreenDimensionsManager.shared.avatarOffset
}

struct Avatar: View {
    var size: CGFloat = avatarSize
    @ObservedObject var participant: ParticipantViewModel
    var body: some View {
        Image(uiImage: participant.avatar)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)

    }
}

struct PulsatingAvatarView: View {
    var size: CGFloat = avatarSize
    let participant: ParticipantViewModel

    var body: some View {
        ZStack {
            // First pulsating ring
            PulsatingRing(color: Color.white.opacity(0.9),
                          delay: 0,
                          duration: 2.5,
                          maxScale: 2.2)
                .frame(width: size, height: size)

            // Second pulsating ring
            PulsatingRing(color: Color.white.opacity(0.7),
                          delay: 0.4,
                          duration: 2.5,
                          maxScale: 2.2)
                .frame(width: size, height: size)

            // Third pulsating ring
            PulsatingRing(color: Color.white.opacity(0.5),
                          delay: 0.8,
                          duration: 2.5,
                          maxScale: 2.2)
                .frame(width: size, height: size)

            // The actual avatar
            Avatar(participant: participant)
        }
        .accessibilityHidden(true)
    }
}

struct PulsatingRing: View {
    let color: Color
    let delay: Double
    let duration: Double
    let maxScale: CGFloat

    @SwiftUI.State private var scale: CGFloat = 1.0
    @SwiftUI.State private var opacity: Double = 0.8
    @SwiftUI.State private var rotation: Double = 0

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [color, color.opacity(0.1)]),
                center: .center,
                startRadius: 0,
                endRadius: 100
            )
            .clipShape(Circle())
            .scaleEffect(scale)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        Animation
                            .easeOut(duration: duration)
                            .repeatForever(autoreverses: false)
                    ) {
                        scale = maxScale
                        opacity = 0
                        rotation = 15
                    }
                }
            }
        }
    }
}

struct ContainerView: View {
    @ObservedObject var model: ContainerViewModel
    @SwiftUI.State var isAnimatingTopMainGrid = false
    @SwiftUI.State var showMainGridView = true
    @SwiftUI.State var showTopGridView = true
    @SwiftUI.State private var maxHeight = maxButtonsWidgetHeight
    @SwiftUI.State var buttonsVisible: Bool = true
    @SwiftUI.State var showInitialView: Bool = true
    @SwiftUI.State var audioCallViewIdentifier = "audioCallView_portrait"
    @Namespace var namespace
    
    @ObservedObject private var dimensionsManager = ScreenDimensionsManager.shared
    
    let capturedVideoId = "capturedVideoId"
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                if !showMainGridView && showTopGridView {
                    TopView(participants: $model.participants)
                }
                MainGridView(isAnimatingTopMainGrid: $isAnimatingTopMainGrid,
                             showMainGridView: $showMainGridView,
                             model: model.mainGridViewModel,
                             participants: $model.participants)
            }
            .onChange(of: model.layout) { _ in
                switch model.layout {
                case .one:
                    withAnimation {
                        self.showTopGridView = false
                    }
                case .grid:
                    self.showMainGridView = true
                    self.isAnimatingTopMainGrid = false
                    self.showTopGridView = false
                case .oneWithSmal:
                    self.showMainGridView = false
                    withAnimation {
                        self.isAnimatingTopMainGrid = true
                        self.showTopGridView = true
                    }
                }
            }
            .padding(5)

            if !model.hasIncomingVideo && !showInitialView {
                audioCallView()
            }

            if model.hasLocalVideo {
                if showInitialView {
                    initialVideoCallView()
                } else if !model.isSwarmCall {
                    DragableCaptureView(image: $model.localImage, namespace: namespace)
                }
            } else if showInitialView {
                initialAudioCallView()
            }

            ActionsView(maxHeight: $maxHeight, visible: $buttonsVisible) {
                BottomSheetContentView(maxHeight: $maxHeight, model: model.actionsViewModel, participants: $model.participants, pending: $model.pending)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                buttonsVisible.toggle()
            }
        }
        .onAppear {[weak model] in
            guard let model = model else { return }
            showInitialView = !model.callAnswered
        }
        .onChange(of: model.callAnswered) {[weak model] newValue in
            guard let model = model else { return }
            if newValue {
                if model.hasLocalVideo {
                    withAnimation(.dragableCaptureViewAnimation()) {
                        showInitialView = false
                    }
                } else {
                    showInitialView = false
                }
            }
        }
        .onChange(of: dimensionsManager.isLandscape) { isLandscape in
            audioCallViewIdentifier = isLandscape ? "audioCallView_landscape" : "audioCallView_portrait"
        }
    }

    @ViewBuilder
    func initialVideoCallView() -> some View {
        ZStack {
            Image(uiImage: model.localImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
            VisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
                .opacity(0.6)
            participantView()
        }
        .id(capturedVideoId)
        .matchedGeometryEffect(id: capturedVideoId, in: namespace)
        .transition(.scale(scale: 1))
        .frame(maxWidth: adaptiveScreenWidth, maxHeight: adaptiveScreenHeight)
        .ignoresSafeArea()
    }

    @ViewBuilder
    func initialAudioCallView() -> some View {
        ZStack {
            Color.gray
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
            participantView()
        }
        .id(audioCallViewIdentifier)
    }

    @ViewBuilder
    private func participantView() -> some View {
        if let participant = model.participants.first, model.participants.count == 1 {
            VStack {
                Spacer()
                PulsatingAvatarView(participant: participant)
                    .offset(y: avatarOffset)
                Spacer().frame(height: 50)
                participantText(participant.name, font: .title)
                Spacer().frame(height: 10)
                participantText(model.callState, font: .callout)
                Spacer()
            }
        }
    }

    private func participantText(_ text: String, font: Font) -> some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .foregroundColor(.white)
            .offset(y: avatarOffset)
            .frame(maxWidth: adaptiveScreenWidth - 50)
    }

    @ViewBuilder
    func audioCallView() -> some View {
        ZStack {
            Color.gray
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let participant = model.participants.first, model.participants.count == 1 {
                VStack {
                    Spacer()
                    Avatar(participant: participant)
                        .offset(y: avatarOffset)
                    Spacer().frame(height: 50)
                    participantText(participant.name, font: .title)
                    Spacer()
                }
            }
        }
        .id(audioCallViewIdentifier)
    }
}
