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
    @StateObject var model: MessagesListVM
    @SwiftUI.State private var text: String = ""
    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            Button(action: {
                self.model.showMoreActions()
            }) {
                Image(systemName: "plus.circle")
                    .resizable()
                    .font(Font.title.weight(.thin))
                    .imageScale(.small)
                    .scaledToFit()
                    .padding(8)
                    .frame(width: 40, height: 40)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }

            Button(action: {
                self.model.sendPhoto()
            }) {
                Image(systemName: "camera")
                    .resizable()
                    .font(Font.title.weight(.thin))
                    .imageScale(.small)
                    .scaledToFit()
                    .padding(8)
                    .frame(width: 42, height: 40)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }

            Spacer()
                .frame(width: 5)

            TextEditor(text: $text)
                .padding(.horizontal, 8)
                .frame(minHeight: 35, maxHeight: 100)
                .fixedSize(horizontal: false, vertical: true)
                .border(Color(UIColor.tertiaryLabel), width: 1, cornerRadius: 18)
                .placeholder(when: text.isEmpty, alignment: .leading) {
                    Text("Send message to...")
                        .padding(.horizontal, 12)
                        .foregroundColor(Color(UIColor.quaternaryLabel))
                        .font(.footnote)
                }
            Spacer()
                .frame(width: 5)
            Button(action: {
                let content = text.isEmpty ? "👍" : text
                self.model.sendMessage(content: content)
                text = ""
            }) {
                if text.isEmpty {
                    Text("👍")
                        .font(.title)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "paperplane")
                        .resizable()
                        .font(Font.title.weight(.thin))
                        .imageScale(.small)
                        .scaledToFit()
                        .padding(8)
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            .animation(.default, value: text.isEmpty)
        }
        .padding(8)
        .background(
            VisualEffectBlur(effect: UIBlurEffect(style: .regular), content: {})
                .ignoresSafeArea(edges: [.leading, .trailing, .bottom])
        )
    }
}
