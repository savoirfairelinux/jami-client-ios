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

struct ManageAccountView: View {
    @ObservedObject var model: AccountSummaryVM
    @Environment(\.presentationMode)
    var presentation
    @SwiftUI.State private var showRemovalAlert = false
    var body: some View {
        ZStack {
            Form {
                Section {
                    NavigationLink(destination: BlockedContactsView(account: model.account, injectionBag: model.injectionBag)) {
                        HStack {
                            Text(L10n.AccountPage.blockedContacts)
                        }
                    }
                    NavigationLink(destination: EncryptAccount(account: model.account, accountService: model.accountService)
                                    .background(Color(UIColor.systemGroupedBackground))) {
                        HStack {
                            Text(L10n.AccountPage.encryptAccount)
                        }
                    }

                    NavigationLink(destination: BackupAccount()
                        .background(Color(UIColor.systemGroupedBackground))) {
                            HStack {
                                Text("Backup account")
                            }
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
                }
            }
            if showRemovalAlert {
                removalAlert()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.manageAccount)
    }

    func removalAlert() -> some View {
        CustomAlert(content: { removalAlertContent() })
    }

    func removalAlertContent() -> some View {
        VStack(spacing: 20) {
            Text(L10n.Global.removeAccount)
                .font(.headline)
            Text(L10n.AccountPage.removeAccountMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            HStack {
                Button(action: {
                    withAnimation {
                        showRemovalAlert = false
                    }
                }, label: {
                    Text(L10n.Global.cancel)
                        .foregroundColor(Color(UIColor.label))
                })
                Spacer()
                Button(action: {
                    presentation.wrappedValue.dismiss()
                    model.removeAccount()
                }, label: {
                    Text(L10n.Global.remove)
                        .foregroundColor(Color(UIColor.jamiFailure))
                })
            }
        }
    }
}

struct EditPasswordView: View {
    @Binding var password: String
    var onDisappearAction: () -> Void

    var body: some View {
        Form {
            Section {
                PasswordFieldView(text: $password, placeholder: L10n.Global.password)
            }
        }
        .navigationTitle(L10n.Global.editPassword)
        .onDisappear {
            onDisappearAction()
        }
    }
}


struct BackupAccount: View {
    //@StateObject var model: EncryptAccountVM

    private let cornerRadius: CGFloat = 10
    private let shadowRadius: CGFloat = 1
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 12
    @SwiftUI.State private var showPicker = false
    @SwiftUI.State private var filePath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @SwiftUI.State private var name: String = "account.gz"
    @SwiftUI.State private var showAlert = false
    @SwiftUI.State private var password = ""
    @SwiftUI.State private var server: String = ""
    @SwiftUI.State private var isTextFieldFocused = true


    //    init(account: AccountModel, accountService: AccountsService) {
    //        _model = StateObject(wrappedValue: EncryptAccountVM(account: account, accountService: accountService))
    //    }

    var body: some View {
        ZStack {
            VStack {
                Text("Your Jami account is registered only on this device as an archive containing the keys of your account. Access to this archive can be protected by a password.")
                backupButton()
                Spacer()
            }

            if showAlert {
                encryptViewAlert()
            }
        }
        .sheet(isPresented: $showPicker) {
            DocumentPicker(fileURL: $filePath)
        }
        .onChange(of: filePath) { _ in
            withAnimation {
                isTextFieldFocused = true
                showAlert = true
            }
            //saveLogTo(path: filePath)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Backup account")
    }

    func saveLogTo() {
       // let filename = "name"
        guard filePath.startAccessingSecurityScopedResource() else {
            //showSaveError()
            return
        }
        print("export to \(filePath.absoluteString)")
//        let finalUrl = path.appendingPathComponent(filename)
//        do {
////            try self.systemService.currentLog.write(to: finalUrl, atomically: true, encoding: String.Encoding.utf8)
//        } catch {
//            path.stopAccessingSecurityScopedResource()
//           // showSaveError()
//            return
//        }
        filePath.stopAccessingSecurityScopedResource()
    }

    @ViewBuilder
    func encryptViewAlert() -> some View {
        CustomAlert(content: { encryptView() })
    }

    func encryptView() -> some View {
        VStack(spacing: 20) {
            Text("backup account")
                .font(.headline)
            Text("archive will be saved to \(filePath.absoluteString)")
                .font(.subheadline)
            WalkthroughFocusableTextView(text: $name,
                                         isTextFieldFocused: $isTextFieldFocused,
                                         placeholder: "file name")
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
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        HStack {
            Button(action: {
//                showEncryptView = false
//                if !passwordValidated {
//                    resetPasswords()
//                }
            }, label: {
                Text(L10n.Global.cancel)
                    .foregroundColor(.jamiColor)
            })

            Spacer()

            Button(action: {
                saveLogTo()
//                showEncryptView = false
//                withAnimation {
//                    encryptionEnabled = true
//                }
            }, label: {
                Text("backup")
                    .foregroundColor(.jamiColor)
            })
//            .disabled(!passwordValidated)
//            .opacity(passwordValidated ? 1 : 0.5)
        }
    }

    func backupButton() -> some View {
        Button(action: {
            withAnimation {
                showPicker = true
            }
        }, label: {
            Text("Backup account")
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(10)
        })
//        .listRowBackground(Color.clear)
//        .optionalRowSeparator(hidden: true)
//        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//        .listRowBackground(Color.clear)
    }
}
