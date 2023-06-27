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
    let indicatorHeight: CGFloat = 5
    let indicatorWidth: CGFloat = 60
    let radius: CGFloat = 40
    let snapRatio: CGFloat = 0.25
    let overshootValue: CGFloat = 20

    init(maxHeight: Binding<CGFloat>, visible: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._maxHeight = maxHeight
        self._visible = visible
        self.content = content()
    }

    private var offset: CGFloat {
        !visible ? maxHeight + overshootValue : expanded ? overshootValue : maxHeight + overshootValue - minHeight
    }

    private var indicator: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color(UIColor.lightGray))
            .frame(
                width: indicatorWidth,
                height: indicatorHeight
            )
    }

    @GestureState private var translation: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
                VStack(spacing: 0) {
                    self.indicator.padding()
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
    }
}

struct BottomSheetContentView: View {
    @Binding var maxHeight: CGFloat
    let model: ActionsViewModel
    @Binding var participants: [ParticipantViewModel]
    let margin: CGFloat = 0
    let linesMargin: CGFloat = 30

    private var idiom: UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }

    var body: some View {
        VStack(alignment: .leading) {
            if idiom == .pad {
                createButtonRow(buttons: model.buttons)
                Spacer()
                    .frame(height: linesMargin)
            } else {
                createButtonRow(buttons: model.firstLineButtons)
                Spacer()
                    .frame(height: linesMargin)
                createButtonRow(buttons: model.secondLineButtons)
            }
            ParticipantInfoListView(participants: $participants)
        }
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
            maxHeight = newHeight
        }
    }

    @ViewBuilder
    func createButtonRow(buttons: [ButtonInfoWrapper]) -> some View {
        HStack(spacing: 20) {
            Spacer()
            ForEach(buttons, id: \.name) { button in
                Button(action: {
                    self.model.perform(action: button.action)
                }, label: {
                    CallButtonView(buttonInfo: button)
                })
            }
            Spacer()
        }
    }
}

struct CallButtonView: View {
    @ObservedObject var buttonInfo: ButtonInfoWrapper

    var body: some View {
        Image(systemName: buttonInfo.name)
            .imageScale(.large)
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(buttonInfo.background)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(buttonInfo.stroke, lineWidth: 2)
            )
    }
}

struct ParticipantActionView: View {
    @ObservedObject var buttonInfo: ButtonInfoWrapper

    var body: some View {
        Image(systemName: buttonInfo.name)
            .imageScale(.large)
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(buttonInfo.background)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(buttonInfo.stroke, lineWidth: 2)
            )
    }
}

struct ParticipantInfoListView: View {
    @Binding var participants: [ParticipantViewModel]
    @SwiftUI.State var contentHeight: CGFloat = 0
    let margin: CGFloat = 20

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(participants, id: \.self) { participant in
                    ParticipantInfoRowView(participant: participant)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.size) { newValue in
                            contentHeight = newValue.height
                        }
                }
            )
        }
        .padding(margin)
        .frame(height: contentHeight + 70)
    }
}

struct ParticipantInfoRowView: View {
    @ObservedObject var participant: ParticipantViewModel

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "airplayaudio")
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .mask(Circle())
            Text(participant.name)
                .font(.body)
                .foregroundColor(.white)
            ParticipantActionsView(buttons: participant.conferenceActions)
        }
    }
}

struct ParticipantActionsView: View {
    let buttons: [ButtonInfoWrapper]

    var body: some View {
        HStack {
            ForEach(buttons, id: \.name) { button in
                Button(action: {
                }, label: {
                    ParticipantActionView(buttonInfo: button)
                })
            }
        }
    }
}
