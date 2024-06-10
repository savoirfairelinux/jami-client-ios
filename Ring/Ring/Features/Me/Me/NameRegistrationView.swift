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
    let textCornerRadius: CGFloat = 8
    let textPadding: CGFloat = 8
    let viewCornerRadius: CGFloat = 16

    init(injectionBag: InjectionBag, account: AccountModel, showAccountRegistration: Binding<Bool>, nameRegisteredCb: @escaping (() -> Void)) {
        _model = StateObject(wrappedValue: NameRegistrationVM(injectionBag: injectionBag, account: account, nameRegisteredCb: nameRegisteredCb))
        _showAccountRegistration = showAccountRegistration
    }

    var body: some View {
        Color.black.opacity(0.5)
            .edgesIgnoringSafeArea(.all)
        createNameRegistrationView()
    }

    func createNameRegistrationView() -> some View {
        VStack {
            VStack(spacing: padding) {
                Text(L10n.Global.registerAUsername)
                    .font(.headline)
                Text(L10n.AccountPage.registerNameExplanation)
                    .multilineTextAlignment(.center)
                VStack {
                    TextField(L10n.AccountPage.usernamePlaceholder, text: $model.name)
                        .modifier(TextFieldStyle())

                    if model.usernameValidationState.isVerifying {
                        SwiftUI.ProgressView()
                    } else if !model.usernameValidationState.message.isEmpty {
                        Text(model.usernameValidationState.message)
                            .font(.footnote)
                            .foregroundColor(Color(model.usernameValidationState.textColor))
                    }
                }
                if model.hasPassword() {
                    TextField(L10n.AccountPage.passwordPlaceholder, text: $model.password)
                        .modifier(TextFieldStyle())
                }
                HStack {
                    Button(action: {
                        withAnimation {
                            showAccountRegistration = false
                        }
                    }) {
                        Text(L10n.Global.cancel)
                    }
                    Spacer()
                    Button(action: {
                        model.registerUsername()
                    }) {
                        Text( L10n.AccountPage.usernameRegisterAction)
                    }
                    .disabled(!model.registerButtonAvailable)
                }
            }
            .padding(padding)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(viewCornerRadius)
        .padding()
        .shadow(radius: 10)
        .transition(.scale)
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

    private struct TextFieldStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .autocorrectionDisabled(true)
                .autocapitalization(.none)
        }
    }
}
