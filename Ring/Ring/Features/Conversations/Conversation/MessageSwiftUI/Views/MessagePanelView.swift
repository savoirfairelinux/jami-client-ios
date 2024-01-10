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
    @StateObject var model: MessagePanelVM
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
        @Binding var placeholder: String

        func body(content: Content) -> some View {
            content
                .padding(.horizontal, 12)
                .font(.footnote)
                .frame(minHeight: 38, maxHeight: 100)
                .background(Color(UIColor.secondarySystemBackground))
                .fixedSize(horizontal: false, vertical: true)
                .cornerRadius(18)
                .placeholder(when: text.isEmpty, alignment: .leading) {
                    Text(placeholder)
                        .padding(.horizontal, 16)
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
        }
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Reply to name")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Text("Message.....")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                Spacer()
                Button(action: {
                    //
                }, label: {
                    MessagePanelImageButton(systemName: "circle.grid.cross.fill", width: 40, height: 40)
                })
            }
            Spacer()
                .frame(height: 10)
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
                        .modifier(CommonTextEditorStyle(text: $text, placeholder: $model.placeholder))
                } else {
                    TextEditor(text: $text)
                        .modifier(CommonTextEditorStyle(text: $text, placeholder: $model.placeholder))
                }
                Spacer()
                    .frame(width: 5)
                Button(action: {
                    self.model.sendMessage(text: text)
                    text = ""
                }, label: {
                    if text.isEmpty {
                        Text(model.defaultEmoji)
                            .font(.title)
                            .frame(width: 36, height: 36)
                            .padding(.bottom, 2)
                    } else {
                        MessagePanelImageButton(systemName: "paperplane", width: 40, height: 40)
                    }
                })
                .animation(.default, value: text.isEmpty)
            }
        }
        .padding(8)
        .padding(.top, 10)
        .background(
            VisualEffect(style: .regular, withVibrancy: false)
                .ignoresSafeArea(edges: [.leading, .trailing, .bottom])
        )
    }
}
