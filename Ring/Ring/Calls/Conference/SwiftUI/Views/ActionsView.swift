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

enum MenuItem {
    case hangup
    case minimize
    case maximize
    case setModerator
    case muteAudio
    case lowerHand
}

struct ActionsConstants {
    static let indicatorHeight: CGFloat = 5
    static let indicatorPadding: CGFloat = 20
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView()
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

struct ActionsView<Content: View>: View {
    @Binding var maxHeight: CGFloat
    @Binding var visible: Bool
    let content: Content
    @SwiftUI.State var expanded: Bool = false
    let minHeight: CGFloat = 120
    let indicatorWidth: CGFloat = 60
    let radius: CGFloat = 40
    let snapRatio: CGFloat = 0.25
    let overshootValue: CGFloat = 0

    init(maxHeight: Binding<CGFloat>, visible: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._maxHeight = maxHeight
        self._visible = visible
        self.content = content()
    }

    private var offset: CGFloat {
        !visible ? maxHeight + overshootValue : expanded ? overshootValue : maxHeight + overshootValue - minHeight
    }

    @GestureState private var translation: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
                VStack(spacing: 0) {
                    Indicator(orientation: .horizontal).padding(ActionsConstants.indicatorPadding)
                    self.content
                }
            }
            .frame(width: geometry.size.width, height: self.maxHeight + overshootValue, alignment: .top)
            .background(Color(UIColor.secondaryLabel))
            .cornerRadius(radius: radius, corners: [.topLeft, .topRight])
            .frame(height: geometry.size.height, alignment: .bottom)
            .offset(y: max(self.offset + self.translation, 0))
            .animation(.interactiveSpring(), value: expanded)
            .animation(.interactiveSpring(), value: translation)
            .gesture(
                DragGesture().updating(self.$translation) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let snapDistance = self.maxHeight * snapRatio
                    guard abs(value.translation.height) > snapDistance else {
                        return
                    }
                    self.expanded = value.translation.height < 0
                }
            )
        }
        .onChange(of: visible) { newValue in
            if !newValue {
                self.expanded = false
            }
        }
        .onTapGesture {
            withAnimation {
                visible.toggle()
            }
        }
    }
}

struct BottomSheetContentView: View {
    @Binding var maxHeight: CGFloat
    let model: ActionsViewModel
    @Binding var participants: [ParticipantViewModel]
    @Binding var pending: [ParticipantViewModel]
    let margin: CGFloat = 20

    private var idiom: UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }

    var body: some View {
        VStack(alignment: .leading) {
            if idiom == .pad {
                createButtonRow(buttons: model.buttons)
                    .padding(.bottom, margin)
            } else {
                createButtonRow(buttons: model.firstLineButtons)
                    .padding(.bottom, margin)
                createButtonRow(buttons: model.secondLineButtons)
                    .padding(.bottom, margin)
            }
            ParticipantInfoListView(participants: $participants)
            if !pending.isEmpty {
                Divider()
                PendingInfoListView(pending: $pending)
            }
        }
        .padding(.bottom, margin)
        .background(
            GeometryReader { innerGeometry in
                Color.clear
                    .preference(
                        key: ContentHeightKey.self,
                        value: innerGeometry.size.height
                    )
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { newHeight in
            maxHeight = min(maxButtonsWidgetHeight, newHeight + ActionsConstants.indicatorHeight + ActionsConstants.indicatorPadding * 2)
        }
    }

    @ViewBuilder
    func createButtonRow(buttons: [ButtonInfoWrapper]) -> some View {
        HStack(spacing: margin) {
            Spacer()
            ForEach(buttons, id: \.name) { button in
                Button(action: {
                    self.model.perform(action: button.action)
                }, label: {
                    CallButtonView(buttonInfo: button)
                })
                .disabled(button.disabled)
            }
            Spacer()
        }
    }
}

struct CallButtonView: View {
    @ObservedObject var buttonInfo: ButtonInfoWrapper
    var size: CGFloat = 45
    var margin: CGFloat = 5

    var body: some View {
        Image(systemName: buttonInfo.name)
            .imageScale(.large)
            .foregroundColor(buttonInfo.disabled ? .gray : .white)
            .frame(width: size, height: size)
            .background(buttonInfo.background)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(buttonInfo.disabled ? .gray : buttonInfo.stroke, lineWidth: 2)
            )
            .frame(width: size + margin, height: size + margin)
    }
}

struct ParticipantActionView: View {
    @ObservedObject var buttonInfo: ButtonInfoWrapper
    var size: CGFloat = 40

    var body: some View {
        let image: Image
        if buttonInfo.isSystem {
            image = Image(systemName: buttonInfo.name)
        } else {
            image = Image(buttonInfo.name)
        }
        return image
            .imageScale(.large)
            .foregroundColor(buttonInfo.imageColor)
            .frame(width: size, height: size)
            .background(buttonInfo.background)
            .clipShape(Circle())
    }
}

struct ParticipantInfoListView: View {
    @Binding var participants: [ParticipantViewModel]
    @SwiftUI.State var contentHeight: CGFloat = 0
    let spacing: CGFloat = 30
    let margin: CGFloat = 20

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: spacing) {
                    /*
                     Use participants.indices to iterate over indices,
                     otherwise, if iterating directly over participants,
                     ForEach will retain a reference to participant.
                     */
                    ForEach(participants.indices, id: \.self) { index in
                        if index < participants.count {
                            ParticipantInfoRowView(participant: participants[index])
                        }
                    }
                }
                .padding(.horizontal, margin)
                .padding(.bottom, margin)
                .background(
                    GeometryReader { innerGeometry in
                        Color.clear
                            .preference(
                                key: ContentHeightKey.self,
                                value: innerGeometry.size.height
                            )
                    }
                )
                .onPreferenceChange(ContentHeightKey.self) { newHeight in
                    contentHeight = newHeight
                }
            }
        }
        .frame(height: min(maxButtonsWidgetHeight - 200, contentHeight))
    }
}

struct PendingInfoListView: View {
    @Binding var pending: [ParticipantViewModel]
    @SwiftUI.State var contentHeight: CGFloat = 0
    let spacing: CGFloat = 30
    let margin: CGFloat = 20
    var size: CGFloat = 50

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: spacing) {
                    ForEach(pending.indices, id: \.self) { index in
                        if index < pending.count {
                            let participant = pending[index]
                            HStack(spacing: 10) {
                                HStack(spacing: margin) {
                                    Image(uiImage: participant.avatar)
                                        .resizable()
                                        .frame(width: size, height: size)
                                        .mask(Circle())
                                    Text(participant.name)
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .layoutPriority(1)
                                    Spacer()
                                    Button(action: {
                                        participant.stopPendingCall()
                                    }, label: {
                                        Image("block_symbol")
                                            .imageScale(.large)
                                            .foregroundColor(.white)
                                            .frame(width: size, height: size)
                                            .background(Color.clear)
                                            .clipShape(Circle())
                                    })
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, margin)
                .padding(.bottom, margin)
                .background(
                    GeometryReader { innerGeometry in
                        Color.clear
                            .preference(
                                key: ContentHeightKey.self,
                                value: innerGeometry.size.height
                            )
                    }
                )
                .onPreferenceChange(ContentHeightKey.self) { newHeight in
                    contentHeight = newHeight
                }
            }
        }
        .frame(height: min(maxButtonsWidgetHeight - 200, contentHeight))
    }
}

struct ParticipantInfoRowView: View {
    @ObservedObject var participant: ParticipantViewModel
    var size: CGFloat = 50
    let margin: CGFloat = 20

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: margin) {
                Image(uiImage: participant.avatar)
                    .resizable()
                    .frame(width: size, height: size)
                    .mask(Circle())
                Text(participant.name)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
            }
            Spacer()
            ParticipantActionsView(participant: participant)
        }
    }
}

struct ParticipantActionsView: View {
    @ObservedObject var participant: ParticipantViewModel
    var buttonSize: CGFloat = 40
    @SwiftUI.State var viewSize: CGFloat = 0
    let space: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(participant.conferenceActions.indices, id: \.self) { index in
                    let button = participant.conferenceActions[index]
                    Button(action: {
                        participant.perform(action: button.action)
                    }, label: {
                        ParticipantActionView(buttonInfo: button)
                    })
                    .padding(.trailing, index == participant.conferenceActions.count - 1 ? space : 0)
                }
            }
        }
        .onChange(of: participant.conferenceActions.count) { _ in
            viewSize = CGFloat(participant.conferenceActions.count) * buttonSize +
                space * CGFloat(participant.conferenceActions.count - 1)
        }
        .frame(width: min(viewSize, adaptiveScreenWidth * 0.4))
    }
}
