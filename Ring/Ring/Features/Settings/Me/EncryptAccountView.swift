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

struct EncryptAccount: View {
    @StateObject var model: EncryptAccountVM

    private let cornerRadius: CGFloat = 10
    private let shadowRadius: CGFloat = 1
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 12

    init(account: AccountModel, accountService: AccountsService) {
        _model = StateObject(wrappedValue: EncryptAccountVM(account: account, accountService: accountService))
    }

    var body: some View {
        List {
            if model.hasPassword() {
                PasswordFieldContainer(
                    text: $model.currentPassword,
                    placeholder: L10n.AccountPage.currentPasswordPlaceholder)
                    .padding(.bottom, 20)
            }

            PasswordFieldContainer(
                text: $model.newPassword,
                placeholder: L10n.AccountPage.newPasswordPlaceholder)
                .listRowBackground(Color.clear)
                .optionalRowSeparator(hidden: true)
                .padding(.vertical, 2)

            PasswordFieldContainer(
                text: $model.confirmPassword,
                placeholder: L10n.AccountPage.newPasswordConfirmPlaceholder)
                .listRowBackground(Color.clear)
                .optionalRowSeparator(hidden: true)

                .padding(.vertical, 2)

            if let errorMessage = model.validationError {
                ErrorMessageView(errorMessage: errorMessage)
            }
            Text(L10n.AccountPage.passwordExplanation)
                .font(.footnote)
                .foregroundColor(.gray)
                .listRowBackground(Color.clear)
                .optionalRowSeparator(hidden: true)
                .listRowInsets(EdgeInsets(top: model.validationError == nil ? 15 : 5, leading: 0, bottom: 0, trailing: 0))
                .accessibilityAutoFocusOnAppear()

            if let errorMessage = model.encryptError {
                ErrorMessageView(errorMessage: errorMessage)
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
            }
            if model.savingPasswordInProgress {
                SwiftUI.ProgressView()
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            if let successMessage = model.successMessage {
                SuccessMessageView(successMessage: successMessage)
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
            }
            updatePasswordButton()
        }
        .ignoresSafeArea(edges: [.bottom])
        .navigationTitle(L10n.AccountPage.encryptAccount)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.newPassword) { _ in model.validatePasswords() }
        .onChange(of: model.confirmPassword) { _ in model.validatePasswords() }
        .onChange(of: model.currentPassword) { _ in model.validatePasswords() }
    }

    func updatePasswordButton() -> some View {
        Button(action: {
            model.savingPasswordInProgress = true
            model.changePassword()
            hideKeyboard()
        }, label: {
            Text(L10n.Global.save)
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(cornerRadius)
        })
        .disabled(!model.buttonEnabled)
        .opacity(model.buttonEnabled ? 1 : 0.6)
        .listRowBackground(Color.clear)
        .optionalRowSeparator(hidden: true)
        .listRowInsets(EdgeInsets(top: model.encryptError == nil && model.successMessage == nil ? 40 : 20, leading: 0, bottom: 0, trailing: 0))
    }
}

struct PasswordFieldContainer: View {
    @Binding var text: String
    let placeholder: String

    private let cornerRadius: CGFloat = 10
    private let shadowRadius: CGFloat = 1
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundColor(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(radius: shadowRadius)
            PasswordFieldView(text: $text, placeholder: placeholder)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
        }
        .listRowInsets(EdgeInsets())
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .listRowBackground(Color.clear)
        .optionalRowSeparator(hidden: true)
    }
}

struct ErrorMessageView: View {
    let errorMessage: String

    var body: some View {
        HStack {
            Spacer()
            Text(errorMessage)
                .foregroundColor(Color(UIColor.jamiFailure))
                .font(.caption)
            Spacer()
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct SuccessMessageView: View {
    let successMessage: String

    var body: some View {
        HStack {
            Spacer()
            Group {
                Image(systemName: "checkmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15, height: 15)
                    .padding(.trailing, 5)
                Text(successMessage)
                    .font(.caption)
            }
            .foregroundColor(Color(UIColor.jamiSuccess))
            Spacer()
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}
