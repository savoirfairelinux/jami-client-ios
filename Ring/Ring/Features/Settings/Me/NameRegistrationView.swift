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
            .onChange(of: model.state) { _ in
                if model.state != .success { return }
                withAnimation {
                    showAccountRegistration = false
                }
            }
    }

    @ViewBuilder
    func createNameRegistrationView() -> some View {
        switch model.state {
        case .initial:
            initialView()
        case .started:
            loadingView()
        case .error(let title, let message):
            errorView(title: title, message: message)
        case .success:
            EmptyView()
        }
    }

    @ViewBuilder
    func errorView(title: String, message: String) -> some View {
        VStack(spacing: padding) {
            Text(title)
                .font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        showAccountRegistration = false
                    }
                }, label: {
                    Text(L10n.Global.ok)
                        .foregroundColor(.jamiColor)
                        .padding(.horizontal)
                })
            }
        }
    }

    @ViewBuilder
    func loadingView() -> some View {
        VStack(spacing: padding) {
            Text(L10n.AccountPage.usernameRegistering)
                .font(.headline)
                .padding()
            SwiftUI.ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2)
                .padding(.bottom, 30)
        }
        .padding()
    }

    func initialView() -> some View {
        VStack(spacing: padding) {
            Text(L10n.Global.registerAUsername)
                .font(.headline)
            Text(L10n.AccountPage.registerNameExplanation)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            VStack {
                TextField(L10n.AccountPage.usernamePlaceholder, text: $model.name)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
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
                }, label: {
                    Text(L10n.Global.cancel)
                        .foregroundColor(Color(UIColor.label))
                })
                Spacer()
                Button(action: {
                    model.registerUsername()
                }, label: {
                    Text( L10n.AccountPage.usernameRegisterAction)
                        .foregroundColor(!model.registerButtonAvailable ?
                                            Color(UIColor.secondaryLabel) :
                                            .jamiColor)
                })
                .disabled(!model.registerButtonAvailable)
            }
        }
    }
}
