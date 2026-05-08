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
    @SwiftUI.State private var showToast = false

    init(account: AccountModel, accountService: AccountsService) {
        _model = StateObject(wrappedValue: EncryptAccountVM(account: account, accountService: accountService))
    }

    var body: some View {
        ZStack(alignment: .top) {
            List {
                if model.hasPassword() {
                    Section(header: explanationHeader, footer: errorFooter) {
                        PasswordFieldView(
                            text: $model.currentPassword,
                            placeholder: L10n.AccountPage.currentPasswordPlaceholder
                        )
                    }

                    Section(footer: validationFooter) {
                        PasswordFieldView(
                            text: $model.newPassword,
                            placeholder: L10n.AccountPage.newPasswordPlaceholder
                        )
                        PasswordFieldView(
                            text: $model.confirmPassword,
                            placeholder: L10n.AccountPage.newPasswordConfirmPlaceholder
                        )
                    }
                } else {
                    Section(header: explanationHeader, footer: validationFooter) {
                        PasswordFieldView(
                            text: $model.newPassword,
                            placeholder: L10n.AccountPage.newPasswordPlaceholder
                        )
                        PasswordFieldView(
                            text: $model.confirmPassword,
                            placeholder: L10n.AccountPage.newPasswordConfirmPlaceholder
                        )
                    }
                }

                if model.savingPasswordInProgress {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Button(action: {
                        model.savingPasswordInProgress = true
                        model.changePassword()
                        hideKeyboard()
                    }) {
                        Text(model.hasPassword()
                                ? L10n.AccountPage.changePassword
                                : L10n.AccountPage.createPassword)
                            .foregroundColor(Color(UIColor.label))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.jamiTertiaryControl)
                            .cornerRadius(10)
                    }
                    .disabled(!model.buttonEnabled)
                    .opacity(model.buttonEnabled ? 1 : 0.5)
                    .listRowBackground(Color.clear)
                    .optionalRowSeparator(hidden: true)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .listStyle(InsetGroupedListStyle())

            if showToast, let message = model.successMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(message)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.jamiSuccess)
                .cornerRadius(20)
                .shadow(radius: 4)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(L10n.AccountPage.encryptAccount)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.newPassword) { _ in model.validatePasswords() }
        .onChange(of: model.confirmPassword) { _ in model.validatePasswords() }
        .onChange(of: model.currentPassword) { _ in model.validatePasswords() }
        .onChange(of: model.successMessage) { message in
            if message != nil {
                withAnimation {
                    showToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
        }
    }

    var explanationHeader: some View {
        Text(L10n.AccountPage.passwordExplanation)
            .font(.footnote)
            .foregroundColor(.gray)
            .textCase(nil)
    }

    @ViewBuilder
    var errorFooter: some View {
        if let error = model.encryptError {
            Text(error)
                .foregroundColor(Color.jamiFailure)
        }
    }

    @ViewBuilder
    var validationFooter: some View {
        if let error = model.validationError {
            Text(error)
                .foregroundColor(Color.jamiFailure)
        }
    }
}
