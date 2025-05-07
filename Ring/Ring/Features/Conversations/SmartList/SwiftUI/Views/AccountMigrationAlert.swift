import SwiftUI

struct AccountMigrationAlert: View {
    @StateObject private var model: AccountMigrationModel
    @Binding var isPresented: Bool
    @SwiftUI.State private var password: String = ""
    //  let stateEmitter: ConversationStatePublisher

    init(accountId: String, accountService: AccountsService, profileService: ProfilesService, isPresented: Binding<Bool>) {
        _model = StateObject(wrappedValue: AccountMigrationModel(accountId: accountId,
                                                                 accountService: accountService,
                                                                 profileService: profileService))
        _isPresented = isPresented
        // self.stateEmitter = stateEmitter
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(uiImage: model.avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                if !model.profileName.isEmpty {
                    Text(model.profileName)
                        .font(.headline)
                }

                if !model.registeredName.isEmpty {
                    Text(model.registeredName)
                        .font(.headline)
                }

                if !model.jamiId.isEmpty {
                    Text(model.jamiId)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            .padding(.top, 8)

            Text("Migrate your account to continue using it.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .padding(.horizontal)

            if model.needsPassword {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Text("Enter your account password to migrate")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding(.horizontal)
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
                        .background(Color(UIColor.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(model.needsPassword && password.isEmpty || model.isLoading)

                Button(action: {
                    model.removeAccount()
                    isPresented = false
                    //stateEmitter.emitState(ConversationState.conversationRemoved)
                }) {
                    Text("Remove")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                .disabled(model.isLoading)
            }
            Spacer()
        }
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Account Migration")
        .overlay(
            Group {
                if model.isLoading {
                    Color.black.opacity(0.4)
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
