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

enum ActionsConstants {
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

    func makeUIView(context _: Context) -> UIVisualEffectView {
        return UIVisualEffectView()
    }

    func updateUIView(_ uiView: UIVisualEffectView, context _: Context) {
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
        _maxHeight = maxHeight
        _visible = visible
        self.content = content()
    }

    private var offset: CGFloat {
        !visible ? maxHeight + overshootValue : expanded ? overshootValue : maxHeight +
            overshootValue - minHeight
    }

    @GestureState private var translation: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(0.5)
                VisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
                VStack(spacing: 0) {
                    Indicator(orientation: .horizontal).padding(ActionsConstants.indicatorPadding)
                    self.content
                }
            }
            .frame(
                width: geometry.size.width,
                height: self.maxHeight + overshootValue,
                alignment: .top
            )
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
    @Binding var pending: [PendingConferenceCall]
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
        .cornerRadius(radius: 40, corners: [.topLeft, .topRight])
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
            maxHeight = min(
                maxButtonsWidgetHeight,
                newHeight + ActionsConstants.indicatorHeight + ActionsConstants.indicatorPadding * 2
            )
        }
    }

    @ViewBuilder
    func createButtonRow(buttons: [ButtonInfoWrapper]) -> some View {
        HStack(spacing: margin) {
            Spacer()
            ForEach(buttons, id: \.name) { buttonInfo in
                CustomButtonView(buttonInfo: buttonInfo, model: self.model)
            }
            Spacer()
        }
    }
}

struct CustomButtonView: View {
    @ObservedObject var buttonInfo: ButtonInfoWrapper
    var model: ActionsViewModel

    var body: some View {
        Button(action: {
            self.model.perform(action: buttonInfo.action)
        }, label: {
            CallButtonView(buttonInfo: buttonInfo)
        })
        .disabled(buttonInfo.disabled)
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
    let spacing: CGFloat = 40
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
        .frame(height: min(maxButtonsWidgetHeight - 300, contentHeight))
    }
}

struct PendingInfoListView: View {
    @Binding var pending: [PendingConferenceCall]
    @SwiftUI.State var contentHeight: CGFloat = 0
    let spacing: CGFloat = 40
    let margin: CGFloat = 20
    var size: CGFloat = 30

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
                                        .frame(width: 35, height: 35)
                                        .mask(Circle())
                                    Text(participant.name)
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .layoutPriority(1)
                                    Spacer()
                                    Button(action: {
                                        participant.stopPendingCall()
                                    }, label: {
                                        Image(systemName: "slash.circle")
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
        .frame(height: min(maxButtonsWidgetHeight - 300, contentHeight))
    }
}

struct ParticipantInfoRowView: View {
    @ObservedObject var participant: ParticipantViewModel
    var size: CGFloat = 35
    let margin: CGFloat = 20

    var body: some View {
        HStack(spacing: 15) {
            HStack(spacing: margin) {
                Image(uiImage: participant.avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .mask(Circle())
                Text(participant.name)
                    .font(.footnote)
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
    var buttonSize: CGFloat = 30
    @SwiftUI.State var viewSize: CGFloat = 0
    let space: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
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
}
