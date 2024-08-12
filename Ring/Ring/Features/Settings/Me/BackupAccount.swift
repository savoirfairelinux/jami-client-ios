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

struct BackupAccount: View {
    @StateObject var model: BackupAccountModel

    private let cornerRadius: CGFloat = 12
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 12
    @SwiftUI.State private var presentDocumentPicker = false
    @SwiftUI.State private var filePath: URL? = nil
    @SwiftUI.State private var fileName: String = "account.gz"
    @SwiftUI.State private var password = ""

    init(account: AccountModel, accountService: AccountsService) {
        _model = StateObject(wrappedValue: BackupAccountModel(account: account, accountService: accountService))
    }

    var body: some View {
        ScrollView {
            VStack {
                Text("This Jami account exists only on this device. The account will be lost if this device is lost or the application is uninstalled. It is recommended to make a backup of this account.")
                    .padding(.vertical)

                if let error = model.errorMessage {
                    errorView(error)
                } else if let successMessage = model.successMessage {
                    successView(successMessage)
                } else {
                    mainContentView()
                }

                Spacer()
            }
            .sheet(isPresented: $presentDocumentPicker) {
                DocumentPicker(fileURL: $filePath, type: .folder)
            }
            .padding(.horizontal)
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Backup account")
    }

    // Error View
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        withAnimation {
            Text(message)
                .foregroundColor(.red)
                .opacity(1.0)
                .transition(.opacity)
        }
    }

    // Success View
    @ViewBuilder
    private func successView(_ message: String) -> some View {
        withAnimation {
            VStack {
                Image(systemName: "checkmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .foregroundColor(.green)
                Text(message)
                    .font(.title)
                    .foregroundColor(.green)
            }
            .opacity(1.0)
            .transition(.opacity)
        }
    }

    // Main Content View
    @ViewBuilder
    private func mainContentView() -> some View {
        if filePath != nil {
            VStack {
                Text("Select a name for archive:")
                TextField(
                    "Archive name",
                    text: $fileName
                )
                .padding(.vertical, verticalPadding)
                .padding(.horizontal)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(UIColor.secondaryLabel), lineWidth: 1)
                )

                if model.hasPassword() {
                    Text("Enter the password that was used to encrypt the account.")
                        .padding(.top)
                    passwordFieldsSection()
                }

                backupButton()
                    .padding(.vertical)
            }
            .opacity(1.0)
            .transition(.opacity)
        } else {
            selectLocationButton()
                .opacity(1.0)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func passwordFieldsSection() -> some View {
        VStack {
            PasswordFieldView(text: $password,
                              placeholder: L10n.Global.enterPassword)
           // .textFieldStyleInAlert()
        }
    }

    func backupButton() -> some View {
        Button(action: {
            model.exportToFile(filePath: filePath,
                               fileName: fileName,
                               password: password)
        }, label: {
            Text("Backup")
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(cornerRadius)
        })
    }

    func selectLocationButton() -> some View {
        Button(action: {
            withAnimation {
                presentDocumentPicker = true
            }
        }, label: {
            Text("Select Backup Location")
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(cornerRadius)
        })
    }
}
