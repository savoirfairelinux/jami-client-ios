/*
 *  Copyright (C) 2025 - 2025 Savoir-faire Linux Inc.
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

struct AccountMigrationView: View {
    @StateObject private var model: AccountMigrationModel
    @SwiftUI.State private var password: String = ""
    @Environment(\.presentationMode) private var presentationMode
    let stateEmitter = ConversationStatePublisher()
    let onCompletion: ((Bool) -> Void)?

    init(accountId: String, accountService: AccountsService, profileService: ProfilesService, onCompletion: ((Bool) -> Void)?) {
        _model = StateObject(wrappedValue: AccountMigrationModel(accountId: accountId,
                                                                 accountService: accountService,
                                                                 profileService: profileService))
        self.onCompletion = onCompletion
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                profileSection
                accountInfoSection
                if model.needsPassword {
                    passwordSection
                }
                actionButtons
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.MigrateAccount.title)
            .onChange(of: model.migrationCompleted) { _ in
                handleMigrationCompletion()
            }
            .padding(.horizontal)
            .alert(isPresented: Binding(
                get: { model.error != nil },
                set: { isPresented in
                    if !isPresented {
                        model.error = nil
                    }
                }
            )) {
                Alert(
                    title: Text(""),
                    message: Text(model.error ?? ""),
                    dismissButton: .default(Text(L10n.Global.ok))
                )
            }
        }
        .overlay(loadingOverlay)
    }

    private var headerView: some View {
        Text(L10n.MigrateAccount.explanation)
            .multilineTextAlignment(.center)
            .padding(.vertical)
    }

    private var profileSection: some View {
        VStack(spacing: 20) {
            AvatarSwiftUIView(source: model)
            if !model.profileName.isEmpty {
                Text(model.profileName)
                    .font(.headline)
            }
        }
    }

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.registeredName.isEmpty {
                HStack {
                    Text(L10n.Global.name + ":")
                        .fontWeight(.medium)
                    Text(model.registeredName)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                Divider()
            }

            if !model.jamiId.isEmpty {
                HStack(alignment: .center) {
                    Text(L10n.Swarm.identifier + ":")
                        .fontWeight(.medium)
                    Text(model.jamiId)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .truncationMode(.middle)
                        .conditionalTextSelection()
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.MigrateAccount.passwordExplanation)
                .font(.callout)
                .foregroundColor(Color(UIColor.secondaryLabel))
            WalkthroughPasswordView(
                text: $password,
                placeholder: L10n.Global.enterPassword,
                backgroundColor: Color(UIColor.secondarySystemBackground)
            )
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 15) {
            migrateButton
            removeButton
        }
    }

    private var migrateButton: some View {
        Button(action: {
            model.handleMigration(password: password)
        }, label: {
            Text(L10n.MigrateAccount.migrateButton)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.jamiColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        })
        .disabled(model.needsPassword && password.isEmpty || model.isLoading)
    }

    private var removeButton: some View {
        Button(action: {
            model.removeAccount()
            presentationMode.wrappedValue.dismiss()
            onCompletion?(false)
        }, label: {
            Text(L10n.Global.removeAccount)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundColor(.red)
                .cornerRadius(12)
        })
        .disabled(model.isLoading)
    }

    private var loadingOverlay: some View {
        Group {
            if model.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        SwiftUI.ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
    }

    private func handleMigrationCompletion() {
        if model.migrationCompleted {
            presentationMode.wrappedValue.dismiss()
            onCompletion?(true)
            model.migrationCompleted = false
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
