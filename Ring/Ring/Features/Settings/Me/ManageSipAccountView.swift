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

    @Environment(\.presentationMode) var presentation

    var removeAccount: (() -> Void)

    init(injectionBag: InjectionBag, account: AccountModel, removeAccount: @escaping (() -> Void)) {
        _model = StateObject(wrappedValue: SipAccountDetailModel(account: account, injectionBag: injectionBag))
        self.removeAccount = removeAccount
    }

    var body: some View {
        Form {
            Section(header: Text("account identity")) {
                NavigationLink(destination: EditableFieldView(value: $model.username, title: "Username", placeholder: "Enter username", onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: "Username", value: model.username)
                }

                NavigationLink(destination: EditableFieldView(value: $model.server, title: "Server", placeholder: "Enter server", onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: "Server", value: model.server)
                }

                NavigationLink(destination: EditPasswordView(password: $model.password, onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: "Password", value: "")
                }

                NavigationLink(destination: EditableFieldView(value: $model.proxy, title: "Proxy", placeholder: "Enter proxy", onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: "Proxy", value: model.proxy)
                }

                NavigationLink(destination: EditableFieldView(value: $model.port, title: "Port", placeholder: "Enter port", onDisappearAction: {
                    model.updateSipSettings()
                })) {
                    FieldRowView(label: "Port", value: model.port)
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
