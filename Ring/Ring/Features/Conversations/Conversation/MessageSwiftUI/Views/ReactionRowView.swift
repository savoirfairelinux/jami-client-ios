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

struct ReactionRowView: View {
    @ObservedObject var reaction: ReactionsRowViewModel
    let padding: CGFloat = 20

    var body: some View {
        HStack {
            Image(uiImage: reaction.avatarImage!)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .cornerRadius(20)

            Spacer()
                .frame(width: padding)

            Text(reaction.username)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(0.5)
                .multilineTextAlignment(.leading)

            Spacer()

            ScrollView {
                Text(reaction.toString())
                    .bold()
                    .font(.title3)
                    .lineLimit(nil)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxHeight: 60)
            .frame(minWidth: 30)
            .layoutPriority(0.5)
        }
        .padding(.horizontal, padding)
    }
}
