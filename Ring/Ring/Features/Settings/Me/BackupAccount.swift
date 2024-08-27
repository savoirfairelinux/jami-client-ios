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

struct BackupAccount: View {
    @StateObject var model: BackupAccountModel

    private let cornerRadius: CGFloat = 12
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 12
    @SwiftUI.State private var presentDocumentPicker = false
    @SwiftUI.State private var filePath: URL?
    @SwiftUI.State private var fileName: String = ""
    @SwiftUI.State private var password = ""

    init(account: AccountModel, accountService: AccountsService) {
        _model = StateObject(wrappedValue: BackupAccountModel(account: account, accountService: accountService))
    }

    var body: some View {
        ScrollView {
            VStack {
                Text(L10n.BackupAccount.explanation)
                    .padding(.vertical)
                contentBasedOnModelState()
                Spacer()
            }
            .padding(.horizontal)
            .sheet(isPresented: $presentDocumentPicker) {
                DocumentPicker(fileURL: $filePath, type: .folder)
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.BackupAccount.title)
    }

    @ViewBuilder
    private func contentBasedOnModelState() -> some View {
        switch model.state {
        case .loading:
            loadingView()
        case .error(let message):
            errorView(message)
        case .success(let message):
            successView(message)
        case .idle:
            mainContentView()
        }
    }

    @ViewBuilder
    private func loadingView() -> some View {
        VStack(spacing: 20) {
            Text(L10n.BackupAccount.creating)
                .font(.headline)
                .padding()
            SwiftUI.ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2)
                .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        Text(message)
            .foregroundColor(Color(UIColor.jamiFailure))
            .transition(.scale)
    }

    @ViewBuilder
    private func successView(_ message: String) -> some View {
        VStack {
            Image(systemName: "checkmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)
                .foregroundColor(Color(UIColor.jamiSuccess))
            Text(message)
                .font(.title)
                .foregroundColor(Color(UIColor.jamiSuccess))
        }
        .transition(.scale)
    }

    @ViewBuilder
    private func mainContentView() -> some View {
        if filePath != nil {
            VStack(alignment: .leading) {
                archiveNameSection()

                if model.hasPassword() {
                    passwordFieldsSection()
                        .transition(.opacity)
                        .padding(.top)
                }

                backupButton()
                    .padding(.vertical, 25)
            }
        } else {
            selectLocationButton()
                .padding(.vertical, 5)
        }
    }

    @ViewBuilder
    private func archiveNameSection() -> some View {
        VStack(alignment: .leading) {
            Text(L10n.BackupAccount.archiveName)
            applyCommonFieldStyle(
                TextField(L10n.BackupAccount.archiveNamePlaceholder, text: $fileName)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            )
        }
    }

    @ViewBuilder
    private func passwordFieldsSection() -> some View {
        VStack(alignment: .leading) {
            Text(L10n.BackupAccount.passwordRequest)
            applyCommonFieldStyle(
                PasswordFieldView(text: $password, placeholder: L10n.Global.enterPassword)
            )
        }
    }

    func backupButton() -> some View {
        Button(action: {
            model.exportToFile(filePath: filePath,
                               fileName: fileName,
                               password: password)
        }, label: {
            styledButtonLabel(L10n.BackupAccount.backupButton)
        })
    }

    func selectLocationButton() -> some View {
        Button(action: {
            withAnimation {
                presentDocumentPicker = true
            }
        }, label: {
            styledButtonLabel(L10n.BackupAccount.documentPickerButton)
        })
    }

    private func applyCommonFieldStyle<V: View>(_ content: V) -> some View {
        content
            .padding(.vertical, verticalPadding)
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(UIColor.secondaryLabel), lineWidth: 1)
            )
    }

    private func styledButtonLabel(_ text: String) -> some View {
        Text(text)
            .foregroundColor(Color(UIColor.label))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .background(Color.jamiTertiaryControl)
            .cornerRadius(cornerRadius)
    }
}
