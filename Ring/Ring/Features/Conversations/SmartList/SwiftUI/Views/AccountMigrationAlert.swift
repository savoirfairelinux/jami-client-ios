import SwiftUI

struct AccountMigrationAlert: View {
    @StateObject private var model: AccountMigrationModel
    @SwiftUI.State private var password: String = ""
    @Environment(\.presentationMode) private var presentationMode
    let stateEmitter = ConversationStatePublisher()
    let onCompletion: (() -> Void)?

    init(accountId: String, accountService: AccountsService, profileService: ProfilesService, onCompletion: (() -> Void)?) {
        _model = StateObject(wrappedValue: AccountMigrationModel(accountId: accountId,
                                                                 accountService: accountService,
                                                                 profileService: profileService))
        self.onCompletion = onCompletion
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Migrate your account to continue using it.")
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
                VStack(spacing: 20) {
                    AvatarImageView(model: model, width: 100, height: 100, textSize: 48)
                    if !model.profileName.isEmpty {
                        Text(model.profileName)
                            .font(.headline)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                        if let username = model.username {
                            HStack {
                                Text("Name:")
                                    .fontWeight(.medium)
                                Text(username)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            Divider()
                        }


                        if !model.jamiId.isEmpty {
                            HStack(alignment: .center) {
                                Text("Identifier:")
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

                if model.needsPassword {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your account password to migrate")
                            .font(.callout)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        WalkthroughPasswordView(text: $password, placeholder: L10n.Global.enterPassword, backgroundColor: Color(UIColor.secondarySystemBackground))
                    }
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        model.handleMigration(password: password)
                    }) {
                        Text("Migrate")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.jamiColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(model.needsPassword && password.isEmpty || model.isLoading)

                    Button(action: {
                        model.removeAccount()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Remove")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                    }
                    .disabled(model.isLoading)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Account Migration")
        .onChange(of: model.migrationCompleted) { newValue in
            if model.migrationCompleted {
                presentationMode.wrappedValue.dismiss()
                if let onCompletion = onCompletion {
                    onCompletion()
                }
                model.migrationCompleted = false
            }
        }
        .overlay(
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
        )
        .alert(item: Binding(
            get: { model.error.map { AlertItem(message: $0) } },
            set: { _ in model.error = nil }
        )) { alertItem in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Helper for alert binding
struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
