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

struct ManageAccountView: View {
    @ObservedObject var model: AccountSummaryVM
    @Environment(\.presentationMode) var presentation
    @SwiftUI.State private var showRemovalAlert = false
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: BlockedContactsView(account: model.account, injectionBag: model.injectionBag)) {
                    HStack {
                        Text(L10n.AccountPage.blockedContacts)
                    }
                }
                NavigationLink(destination: EncryptAccount(account: model.account, accountService: model.accountService)
                                .background(Color(UIColor.systemGroupedBackground))) {
                    HStack {
                        Text(L10n.AccountPage.encryptAccount)
                    }
                }
            }

            Section {
                Button {
                    showRemovalAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text(L10n.Global.removeAccount)
                            .foregroundColor(Color(UIColor.jamiFailure))
                        Spacer()
                    }
                }
                .alert(isPresented: $showRemovalAlert) {
                    Alert(
                        title: Text(L10n.Global.removeAccount),
                        message: Text(L10n.AccountPage.removeAccountMessage),
                        primaryButton: .destructive(Text(L10n.Global.remove)) {
                            presentation.wrappedValue.dismiss()
                            model.removeAccount()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.manageAccount)
    }
}

struct EditPasswordView: View {
    @Binding var password: String
    var onDisappearAction: () -> Void

    var body: some View {
        Form {
            Section {
                PasswordFieldView(text: $password, placeholder: L10n.Global.password)
            }
            .navigationTitle(L10n.Global.editPassword)
        }
        .onDisappear {
            onDisappearAction()
        }
    }
}
