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
    @StateObject var viewModel: CreateAccountVM
    let dismissHandler = DismissHandler()
    let createAction: (String, String, String, UIImage?) -> Void

    @SwiftUI.State private var isTextFieldFocused = true
    @SwiftUI.State private var name: String = ""
    @SwiftUI.State private var showEncryptView = false
    @SwiftUI.State private var showProfileView = false
    @SwiftUI.State private var encryptionEnabled = false
    @SwiftUI.State private var password = ""
    @SwiftUI.State private var passwordConfirm = ""
    @SwiftUI.State private var profileImage: UIImage?
    @SwiftUI.State private var profileName: String = ""

    init(injectionBag: InjectionBag,
         createAction: @escaping (String, String, String, UIImage?) -> Void) {
        _viewModel = StateObject(wrappedValue:
                                    CreateAccountVM(with: injectionBag))
        self.createAction = createAction
    }

    var body: some View {
        ZStack {
            VStack {
                header
                ScrollView(showsIndicators: false) {
                    if profileCustomized() {
                        profileStatus
                    }
                    if encryptionEnabled {
                        encryptionStatus
                    }
                    Text(L10n.CreateAccount.nameExplanation)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)
                    userNameView
                    footerView
                    buttons
                }
                .frame(maxWidth: 500)
                .sheet(isPresented: $showProfileView) {
                    ProfileView(isPresented: $showProfileView,
                                initialName: profileName,
                                initialImage: $profileImage) { (name, photo) in
                        // Do not reset the photo if it was taken previously
                        withAnimation {
                            if photo != nil {
                                profileImage = photo
                            }
                            profileName = name
                        }
                    }
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
            viewModel.usernameUpdated(to: newValue)
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
                .font(.headline)
                .accessibilityIdentifier( AccessibilityIdentifiers.createAccountTitle)
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
        .padding(.bottom)
    }

    private var profileStatus: some View {
        HStack {
            Text(L10n.AccountPage.profileHeader)
                .font(.headline)
            HStack {
                if let image = self.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                }
                if !self.profileName.isEmpty {
                    Text(self.profileName)
                }
                Button(action: {
                    resetProfile()
                }, label: {
                    Image(systemName: "xmark")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .frame(width: 10, height: 10)
                        .padding(.horizontal)
                })
            }
            .padding(.leading)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 1)
                    .stroke(Color(UIColor.tertiaryLabel), lineWidth: 1)
            )
            Spacer()
        }
        .padding(.bottom)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            encryptButton
            customizeButton
        }
    }

    private var userNameView: some View {
        WalkthroughFocusableTextView(text: $name,
                                     isTextFieldFocused: $isTextFieldFocused, placeholder: L10n.Global.username,
                                     identifier: AccessibilityIdentifiers.usernameTextField)
    }

    @ViewBuilder private var footerView: some View {
        if viewModel.usernameValidationState.message.isEmpty {
            Text("valid name")
                .foregroundColor(.clear)
                .font(.footnote)
                .accessibilityLabel(L10n.Accessibility.createAccountVerifyUsernamePrompt)
        } else {
            Text(viewModel.usernameValidationState.message)
                .foregroundColor(Color(viewModel.usernameValidationState.textColor))
                .font(.footnote)
                .accessibilityIdentifier(AccessibilityIdentifiers.createAccountErrorLabel)
        }
    }

    private var cancelButton: some View {
        Button(action: {[weak dismissHandler] in
            dismissHandler?.dismissView()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
        .accessibilityIdentifier(AccessibilityIdentifiers.cancelCreatingAccount)
    }

    private var createButton: some View {
        Button(action: {[weak dismissHandler] in
            dismissHandler?.dismissView()
            createAction(name, password, profileName, profileImage)
        }, label: {
            Text(L10n.Global.create)
                .foregroundColor(viewModel.isJoinButtonDisabled ?
                                    Color(UIColor.secondaryLabel) :
                                    .jamiColor)
        })
        .disabled(viewModel.isJoinButtonDisabled)
        .accessibilityIdentifier(AccessibilityIdentifiers.joinButton)
    }

    private var encryptButton: some View {
        Button(action: {
            isTextFieldFocused = false
            withAnimation {
                showEncryptView = true
            }
        }, label: {
            Text(encryptionEnabled ?
                    L10n.AccountPage.changePassword :
                    L10n.CreateAccount.encrypt)
                .foregroundColor(.jamiColor)
                .padding()
        })
    }

    private var customizeButton: some View {
        Button(action: {
            withAnimation {
                showProfileView = true
            }
        }, label: {
            Text(L10n.CreateAccount.customize)
                .foregroundColor(.jamiColor)
        })
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
            PasswordFieldView(text: $password,
                              placeholder: L10n.Global.enterPassword)
                .textFieldStyleInAlert()

            PasswordFieldView(text: $passwordConfirm,
                              placeholder: L10n.Global.confirmPassword)
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
                withAnimation {
                    encryptionEnabled = true
                }
            }, label: {
                Text(L10n.Global.save)
                    .foregroundColor(.jamiColor)
            })
            .disabled(!passwordValidated)
            .opacity(passwordValidated ? 1 : 0.5)
        }
    }

    private var passwordValidated: Bool {
        !password.isEmpty && password == passwordConfirm
    }

    private var passwordsDoNotMatch: Bool {
        !passwordConfirm.isEmpty && passwordConfirm != password
    }

    private func resetPasswords() {
        password = ""
        passwordConfirm = ""
    }

    private func resetProfile() {
        withAnimation {
            self.profileName = ""
            self.profileImage = nil
        }
    }

    private func profileCustomized() -> Bool {
        return !profileName.isEmpty || profileImage != nil
    }
}
