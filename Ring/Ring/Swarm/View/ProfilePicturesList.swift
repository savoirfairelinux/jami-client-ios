/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import SwiftUI

struct MemberList: View {

    @SwiftUI.State var members = [ParticipantInfo]()

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(members, id: \.self) {
                    ProfileItem(image: $0.avatar.value, name: $0.name.value.isEmpty ? $0.jamiId : $0.name.value, role: $0.role == .member ? "" : $0.role.stringValue, isInvited: $0.role == .invited)
                }
            }
        }
    }
}

struct ProfileItem: View {
    var image: UIImage?
    var name: String
    var role: String
    var isInvited: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: image ?? UIImage(asset: Asset.fallbackAvatar)!)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50, alignment: .center)
                .clipShape(Circle())

            HStack {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(role)
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.light)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .opacity(isInvited ? 0.5 : 1)
    }
}

struct MemberList_Previews: PreviewProvider {
    static var previews: some View {
        MemberList()
            .previewLayout(.sizeThatFits)
    }
}
