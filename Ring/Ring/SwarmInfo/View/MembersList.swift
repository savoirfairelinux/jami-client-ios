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
    @StateObject var viewmodel: SwarmInfoVM
    @SwiftUI.State private var editMode = EditMode.inactive

    var body: some View {
        List {
            ForEach(viewmodel.swarmInfo.participants.value, id: \.self) {
                MemberItem(
                    image: $0.avatar.value,
                    name: $0.finalName.value.isEmpty ? $0.jamiId : $0.finalName.value,
                    role: $0.role == .member ? "" : $0.role.stringValue,
                    isInvited: $0.role == .invited
                )
                .deleteDisabled($0.role == .admin)
            }
            .onDelete(perform: viewmodel.isAdmin ? delete : nil)
            if #available(iOS 15.0, *) {
                Spacer()
                    .frame(height: 60)
                    .listRowSeparator(.hidden)
            } else {
                Spacer()
                    .frame(height: 60)
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: viewmodel.swarmInfo.participants.value) { _ in
            if editMode == .active {
                editMode = .inactive
            }
        }
        .listStyle(PlainListStyle())
    }

    func delete(at indexSet: IndexSet) {
        viewmodel.removeMember(indexOffset: indexSet)
    }
}

struct MemberItem: View {
    var image: UIImage?
    var name: String
    var role: String
    var isInvited: Bool

    var body: some View {
        HStack(alignment: .center) {
            Image(uiImage: image ?? UIImage(asset: Asset.fallbackAvatar)!)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50, alignment: .center)
                .clipShape(Circle())
            Text(name)
                .font(.system(size: 15.0, weight: .regular, design: .default))
                .padding(.leading, 8.0)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            HStack {
                Text(role)
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.light)
                    .frame(width: nil, height: nil, alignment: .trailing)
            }
        }
        .opacity(isInvited ? 0.5 : 1)
    }
}
