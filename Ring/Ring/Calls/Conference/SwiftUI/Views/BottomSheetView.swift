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

struct BottomSheetView<Content: View>: View {
    @Binding var maxHeight: CGFloat
    let content: Content
    @SwiftUI.State var expanded: Bool = false
    let minHeight: CGFloat = 100
    let indicatorHeight: CGFloat = 6
    let indicatorWidth: CGFloat = 60
    let radius: CGFloat = 16
    let snapRatio: CGFloat = 0.25

    init(maxHeight: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._maxHeight = maxHeight
        self.content = content()
    }

    private var offset: CGFloat {
        expanded ? 0 : maxHeight - minHeight
    }

    private var indicator: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.secondary)
            .frame(
                width: indicatorWidth,
                height: indicatorHeight
            )
    }

    @GestureState private var translation: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                self.indicator.padding()
                self.content
            }
            .frame(width: geometry.size.width, height: self.maxHeight, alignment: .top)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(radius)
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
    }
}

struct BottomSheetContentView: View {
    @Binding var maxHeight: CGFloat
    let margin: CGFloat = 20

    struct ButtonInfo {
        let background: Color
        let stroke: Color
        let name: String
    }

    let firstLineButtons: [ButtonInfo] = [
        ButtonInfo(background: .red, stroke: .red, name: "phone.down"),
        ButtonInfo(background: .clear, stroke: .white, name: "pause.fill"),
        ButtonInfo(background: .clear, stroke: .white, name: "arrow.triangle.2.circlepath.camera"),
        ButtonInfo(background: .clear, stroke: .white, name: "speaker.wave.2"),
        ButtonInfo(background: .clear, stroke: .white, name: "person.fill.badge.plus")
    ]

    let secondLineButtons: [ButtonInfo] = [
        ButtonInfo(background: .clear, stroke: .white, name: "mic"),
        ButtonInfo(background: .clear, stroke: .white, name: "video")
    ]

    var body: some View {
        GeometryReader { _ in
            VStack(alignment: .center) {
                createButtonRow(buttons: firstLineButtons)
                createButtonRow(buttons: secondLineButtons)
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
                maxHeight = newHeight + margin
            }
        }
    }

    @ViewBuilder
    func createButtonRow(buttons: [ButtonInfo]) -> some View {
        HStack(spacing: 20) {
            Spacer()
            ForEach(buttons, id: \.name) { button in
                Button(action: {}) {
                    imageForButton(button)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    func imageForButton(_ buttonInfo: ButtonInfo) -> some View {
        Image(systemName: buttonInfo.name)
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
