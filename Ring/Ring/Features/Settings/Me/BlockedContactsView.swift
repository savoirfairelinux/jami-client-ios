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

struct BlockedContactsView: View {
    @StateObject var model: BlockedContactsVM

    init(account: AccountModel, injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue: BlockedContactsVM(account: account, injectionBag: injectionBag))
    }

    var body: some View {
        List(model.blockedContacts) { contactViewModel in
            BlockedContactRowView(model: contactViewModel)
        }
        .navigationTitle(L10n.AccountPage.blockedContacts)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BlockedContactRowView: View {
    @ObservedObject var model: BlockedContactsRowVM

    var body: some View {
        HStack {
            AvatarSwiftUIView(source: model)

            Spacer()
                .frame(width: 15)

            VStack(alignment: .leading) {
                if !model.profileName.isEmpty {
                    Text(model.profileName)
                        .lineLimit(1)
                        .conditionalTextSelection()
                        .truncationMode(.middle)
                }
                if !model.registeredName.isEmpty {
                    Text(model.registeredName)
                        .font(model.profileName.isEmpty ? .footnote : .body)
                        .lineLimit(1)
                        .conditionalTextSelection()
                        .truncationMode(.middle)
                } else {
                    Text(model.id)
                        .font(.footnote)
                        .lineLimit(1)
                        .conditionalTextSelection()
                        .truncationMode(.middle)
                }
            }

            Spacer()
                .frame(width: 15)

            Spacer()

            Button(action: {
                model.unblock()
            }, label: {
                Text(L10n.AccountPage.unblockContact)
                    .foregroundColor(.jamiColor)
            })
        }
    }
}
