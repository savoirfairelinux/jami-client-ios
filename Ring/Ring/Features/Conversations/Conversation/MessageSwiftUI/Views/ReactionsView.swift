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
    @StateObject var model: ReactionsContainerModel
    @SwiftUI.State private var contentHeight: CGFloat = 100
    let size: CGSize = CGSize(width: 100, height: 100)

    var body: some View {
        ScrollView {
            VStack {
                ForEach(model.reactionsRow) { reaction in
                    ReactionRowView(reaction: reaction)
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
        .frame(maxWidth: size.width, maxHeight: min(contentHeight, size.height), alignment: .center)
    }
}
