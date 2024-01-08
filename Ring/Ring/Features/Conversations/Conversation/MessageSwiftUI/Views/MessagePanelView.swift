/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

struct MessagePanelView: View {
    var model: MessagesListVM
    @SwiftUI.State private var text: String = ""

    private struct MessagePanelImageButton: View {
        let systemName: String
        let width: CGFloat
        let height: CGFloat

        var body: some View {
            Image(systemName: systemName)
                .resizable()
                .font(Font.title.weight(.light))
                .imageScale(.small)
                .scaledToFit()
                .padding(9)
                .frame(width: width, height: height)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }

    private struct CommonTextEditorStyle: ViewModifier {
        @Binding var text: String

        func body(content: Content) -> some View {
            content
                .padding(.horizontal, 12)
                .font(.footnote)
                .frame(minHeight: 38, maxHeight: 100)
                .background(Color(UIColor.secondarySystemBackground))
                .fixedSize(horizontal: false, vertical: true)
                .cornerRadius(18)
                .placeholder(when: text.isEmpty, alignment: .leading) {
                    Text("Send message to...")
                        .padding(.horizontal, 16)
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            Button(action: {
                self.model.showMoreActions()
            }, label: {
                MessagePanelImageButton(systemName: "plus.circle", width: 40, height: 40)
            })
            Button(action: {
                self.model.sendPhoto()
            }, label: {
                MessagePanelImageButton(systemName: "camera", width: 42, height: 40)
            })

            Spacer()
                .frame(width: 5)

            if #available(iOS 16.0, *) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .modifier(CommonTextEditorStyle(text: $text))
            } else {
                TextEditor(text: $text)
                    .modifier(CommonTextEditorStyle(text: $text))
            }
            Spacer()
                .frame(width: 5)
            Button(action: {
                let content = text.isEmpty ? "👍" : text
                self.model.sendMessage(content: content)
                text = ""
            }, label: {
                if text.isEmpty {
                    Text("👍")
                        .font(.title)
                        .frame(width: 36, height: 38)
                        .padding(.bottom, 2)
                } else {
                    MessagePanelImageButton(systemName: "paperplane", width: 40, height: 40)
                }
            })
            .animation(.default, value: text.isEmpty)
        }
        .padding(8)
        .background(
            VisualEffectBlur(effect: UIBlurEffect(style: .regular), content: {})
                .ignoresSafeArea(edges: [.leading, .trailing, .bottom])
        )
    }
}
