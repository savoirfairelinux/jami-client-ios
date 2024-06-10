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

struct NameRegistrationView: View {
    @Binding var showAccountRegistration: Bool
    @StateObject var model: NameRegistrationVM

    let padding: CGFloat = 20

    init(injectionBag: InjectionBag, account: AccountModel, showAccountRegistration: Binding<Bool>, nameRegisteredCb: @escaping (() -> Void)) {
        _model = StateObject(wrappedValue: NameRegistrationVM(injectionBag: injectionBag, account: account, nameRegisteredCb: nameRegisteredCb))
        _showAccountRegistration = showAccountRegistration
    }

    var body: some View {
        CustomAlert(content: { createNameRegistrationView() })
    }

    func createNameRegistrationView() -> some View {
        VStack(spacing: padding) {
            Text(L10n.Global.registerAUsername)
                .font(.headline)
            Text(L10n.AccountPage.registerNameExplanation)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            VStack {
                TextField(L10n.AccountPage.usernamePlaceholder, text: $model.name)
                    .textFieldStyleInAlert()

                if model.usernameValidationState.isVerifying {
                    SwiftUI.ProgressView()
                } else if !model.usernameValidationState.message.isEmpty {
                    Text(model.usernameValidationState.message)
                        .font(.footnote)
                        .foregroundColor(Color(model.usernameValidationState.textColor))
                }
            }
            if model.hasPassword() {
                PasswordFieldView(text: $model.password, placeholder: L10n.AccountPage.passwordPlaceholder)
                    .textFieldStyleInAlert()
            }
            HStack {
                Button(action: {
                    withAnimation {
                        showAccountRegistration = false
                    }
                }) {
                    Text(L10n.Global.cancel)
                        .foregroundColor(Color(UIColor.label))
                }
                Spacer()
                Button(action: {
                    model.registerUsername()
                }) {
                    Text( L10n.AccountPage.usernameRegisterAction)
                        .foregroundColor(Color.jamiColor)
                }
                .disabled(!model.registerButtonAvailable)
            }
        }
        .alert(isPresented: $model.showErrorAlert) {
            Alert(title: Text(""),
                  message: Text(model.errorAlertMessage),
                  dismissButton: .default(Text(L10n.Global.ok)))
        }
        .onChange(of: model.nameRegistrationCompleted) { _ in
            if model.nameRegistrationCompleted {
                withAnimation {
                    showAccountRegistration = false
                }
            }
        }
    }
}
