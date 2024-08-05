/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

struct CreateAccountView: View {
    @StateObject var model: CreateAccountViewModel
    let dismissAction: () -> Void
    let createAction: (String, String) -> Void

    @SwiftUI.State private var isTextFieldFocused = true
    @SwiftUI.State private var name: String = ""
    @SwiftUI.State private var showEncryptView = false
    @SwiftUI.State private var password = ""
    @SwiftUI.State private var passwordConfirm = ""

    init(injectionBag: InjectionBag, dismissAction: @escaping () -> Void, createAction: @escaping (String, String) -> Void) {
        _model = StateObject(wrappedValue: CreateAccountViewModel(with: injectionBag))
        self.dismissAction = dismissAction
        self.createAction = createAction
    }

    var body: some View {
        ZStack {
            VStack {
                header
                ScrollView(showsIndicators: false) {
                    Text(L10n.CreateAccount.nameExplanation)
                        .padding(.bottom)
                    userNameView
                    footerView
                    if passwordValidated {
                        encryptionStatus
                    }
                    buttons
                }
                .padding(.horizontal)
            }
            if showEncryptView {
                encryptViewAlert()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: name) { newValue in
            model.usernameUpdated(to: newValue)
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                cancelButton
                Spacer()
                createButton
            }
            Text(L10n.CreateAccount.newAccount)
        }
        .padding()
    }

    private var encryptionStatus: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(UIColor.jamiSuccess))
            Text(L10n.CreateAccount.encryptionEnabled)
                .font(.footnote)
                .foregroundColor(Color(UIColor.jamiSuccess))
                .padding(.horizontal, 5)
            Spacer()
        }
        .padding(.top)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            encryptButton
            customizeButton
        }
    }

    private var userNameView: some View {
        CreateAccountFocusableTextEditView(text: $name, isTextFieldFocused: $isTextFieldFocused, placeholder: L10n.Global.username)
    }

    private var footerView: some View {
        if model.usernameValidationState.message.isEmpty {
            Text("valid name")
                .foregroundColor(.clear)
                .font(.footnote)
        } else {
            Text(model.usernameValidationState.message)
                .foregroundColor(Color(model.usernameValidationState.textColor))
                .font(.footnote)
        }
    }

    private var cancelButton: some View {
        Button(action: {
            dismissAction()
        }) {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        }
    }

    private var createButton: some View {
        Button(action: {
            createAction(name, password)
        }) {
            Text(L10n.Global.create)
                .foregroundColor(model.isJoinButtonDisabled ? Color(UIColor.secondaryLabel) : .jamiColor)
        }
    }

    private var encryptButton: some View {
        Button(action: {
            withAnimation {
                showEncryptView = true
            }
        }) {
            Text(L10n.CreateAccount.encrypt)
                .foregroundColor(.jamiColor)
                .padding()
        }
    }

    private var customizeButton: some View {
        Button(action: {
            withAnimation {
                showEncryptView = true
            }
        }) {
            Text(L10n.CreateAccount.customize)
                .foregroundColor(.jamiColor)
        }
    }

    @ViewBuilder
    func encryptViewAlert() -> some View {
        CustomAlert(content: { encryptView() })
    }

    func encryptView() -> some View {
        VStack(spacing: 20) {
            Text(L10n.CreateAccount.encryptTitle)
                .font(.headline)

            Text(L10n.CreateAccount.encryptExplanation)
                .font(.subheadline)

            passwordFieldsSection()

            actionButtons()
        }
    }

    @ViewBuilder
    private func passwordFieldsSection() -> some View {
        VStack {
            PasswordFieldView(text: $password, placeholder: L10n.Global.enterPassword)
                .textFieldStyleInAlert()

            PasswordFieldView(text: $passwordConfirm, placeholder: L10n.Global.enterPassword)
                .textFieldStyleInAlert()

            if passwordsDoNotMatch {
                Text(L10n.AccountPage.passwordsDoNotMatch)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.bottom)
            }
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        HStack {
            Button(action: {
                showEncryptView = false
                if !passwordValidated {
                    resetPasswords()
                }
            }, label: {
                Text(L10n.Global.cancel)
                    .foregroundColor(.jamiColor)
            })

            Spacer()

            Button(action: {
                showEncryptView = false
            }, label: {
                Text(L10n.Global.save)
                    .foregroundColor(.jamiColor)
            })
            .disabled(!passwordValidated)
            .opacity(passwordValidated ? 1 : 0.5)
        }
    }

    private var passwordValidated: Bool {
        !password.isEmpty && password != passwordConfirm
    }

    private var passwordsDoNotMatch: Bool {
        !passwordConfirm.isEmpty && passwordConfirm != password
    }

    private func resetPasswords() {
        password = ""
        passwordConfirm = ""
    }
}
