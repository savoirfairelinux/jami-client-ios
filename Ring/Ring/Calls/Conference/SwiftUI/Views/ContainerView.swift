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

let maxButtonsWidgetHeight: CGFloat = screenHeight * 0.7
let avatarSize: CGFloat = 160

var avatarOffset: CGFloat {
    if UIDevice.current.userInterfaceIdiom == .pad {
        return UIDevice.current.orientation.isLandscape ? -(screenHeight / 3) + avatarSize : -(screenHeight / 2.5) + avatarSize
    } else {
        return UIDevice.current.orientation.isLandscape ? 0 : -(screenHeight / 3) + avatarSize
    }
}

struct Avatar: View {
    var size: CGFloat = avatarSize
    @ObservedObject var participant: ParticipantViewModel
    var body: some View {
        Image(systemName: "person")
            .resizable()
           // .aspectRatio(contentMode: .fill)
            .foregroundColor(.white)
           // .background(Color.blue)
            .padding(40)

            .frame(width: size, height: size)
            .background(Color.blue)
            .clipShape(Circle())
    }
}

struct PulsatingAvatarView: View {
    var size: CGFloat = avatarSize
    @SwiftUI.State private var scale: CGFloat = 1.0
    @SwiftUI.State private var opacity: Double = 0.6
    let participant: ParticipantViewModel

    var body: some View {
        ZStack {
            Color.white
                .frame(width: size, height: size)
                .clipShape(Circle())
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)) {
                        opacity = 0
                        scale = 2.2
                    }
                }
            Avatar(participant: participant)
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
    @SwiftUI.State var hasLocalVideo: Bool = false
    @SwiftUI.State var hasIncomingVideo: Bool = false
    @SwiftUI.State var showInitialView: Bool = true
    @SwiftUI.State var audioCallViewIdentifier = "audioCallView_"
    @Namespace var namespace
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
            if !hasIncomingVideo && !showInitialView {
                audioCallView()
            }

            if hasLocalVideo {
                if showInitialView {
                    initialVideoCallView()
                } else {
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
        .onTapGesture {
            withAnimation {
                buttonsVisible.toggle()
            }
        }
        .onChange(of: model.hasLocalVideo) { newValue in
            hasLocalVideo = newValue
        }
        .onChange(of: model.hasIncomingVideo) { newValue in
            hasIncomingVideo = newValue
        }
        .onChange(of: model.callAnswered) { newValue in
            if newValue {
                if hasLocalVideo {
                    withAnimation(.dragableCaptureViewAnimation()) {
                        showInitialView = false
                    }
                } else {
                    showInitialView = false
                }
            }
        }
        .onAppear {
            hasLocalVideo = model.hasLocalVideo
            hasIncomingVideo = model.hasIncomingVideo
            if model.callAnswered {
                showInitialView = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation.isLandscape ? "landscape" : "portrait"
            self.audioCallViewIdentifier = "audioCallView_" + orientation
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
