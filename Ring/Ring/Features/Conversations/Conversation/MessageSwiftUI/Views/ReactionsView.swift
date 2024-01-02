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
    var reactions: [ReactionsRowViewModel]
    @SwiftUI.State private var contentHeight: CGFloat = 100
    let defailtSize: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack {
                ForEach(reactions) { reaction in
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
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color(UIColor.quaternaryLabel), radius: 2, x: 1, y: 2)
        .frame(maxWidth: defailtSize, maxHeight: min(contentHeight, defailtSize), alignment: .center)
    }
}
