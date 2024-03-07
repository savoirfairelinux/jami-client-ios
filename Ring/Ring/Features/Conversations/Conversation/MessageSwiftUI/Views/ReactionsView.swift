/*
 *  Copyright (C) 2023-2024 Savoir-faire Linux Inc.
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

struct ReactionsView: View {
    var currentJamiId: String
    @StateObject var model: ReactionsContainerModel
    @SwiftUI.State private var contentHeight: CGFloat = 100
    let defaultSize: CGSize = CGSize(width: 300, height: 300)

    var body: some View {
        ScrollView {
            VStack {
                ForEach(model.reactionsRow.indices) { index in
                    if index != 0 {
                        Divider()
                    }
                    let rowIn = model.reactionsRow[index]
                    ReactionRowView(doButtons: rowIn.jamiId == self.currentJamiId, author: rowIn.username, avatarImg: rowIn.avatarImage, parentMsg: rowIn.messageId, reactions: model.reactionsRow[index].content.map({ key, value in ReactionRowViewData(msgId: key, textValue: value) }))
//                    ReactionRowView(doButtons: model.reactionsRow[index].jamiId == self.currentJamiId, reaction: model.reactionsRow[index])
                }
            }
            .padding(.vertical)
            .background(
                GeometryReader { proxy -> Color in
                    DispatchQueue.main.async {
                        self.contentHeight = proxy.size.height
                    }
                    return Color.clear
                }
            )
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadowForConversation()
        .frame(maxWidth: defaultSize.width, maxHeight: min(contentHeight, defaultSize.height), alignment: .center)
    }
}
