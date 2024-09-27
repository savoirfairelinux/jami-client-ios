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

struct ManageSipAccountView: View {
    @StateObject var model: SipAccountDetailModel
    @SwiftUI.State private var showRemovalAlert = false

    @Environment(\.presentationMode)
    var presentation

    var removeAccount: (() -> Void)

    init(injectionBag: InjectionBag, account: AccountModel, removeAccount: @escaping (() -> Void)) {
        _model = StateObject(wrappedValue: SipAccountDetailModel(account: account, injectionBag: injectionBag))
        self.removeAccount = removeAccount
    }

    var body: some View {
        Form {
            Section(header: Text(L10n.AccountPage.accountIdentity)) {
                NavigationLink(destination: EditableFieldView(value: $model.username, title: L10n.Global.username, placeholder: L10n.Global.username, onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: L10n.Global.username, value: model.username)
                }

                NavigationLink(destination: EditableFieldView(value: $model.server, title: L10n.Account.sipServer, placeholder: L10n.Account.sipServer, onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: L10n.Account.sipServer, value: model.server)
                }

                NavigationLink(destination: EditPasswordView(password: $model.password, onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: L10n.Global.password, value: model.password.maskedPassword)
                }

                NavigationLink(destination: EditableFieldView(value: $model.proxy, title: L10n.Account.proxyServer, placeholder: L10n.Account.proxyServer, onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: L10n.Account.proxyServer, value: model.proxy)
                }

                NavigationLink(destination: EditableFieldView(value: $model.port, title: L10n.Account.port, placeholder: L10n.Account.port, onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: L10n.Account.port, value: model.port)
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
                            removeAccount()
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
