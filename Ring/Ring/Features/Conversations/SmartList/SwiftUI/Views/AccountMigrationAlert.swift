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
            .navigationTitle("Account Migration")
            .onChange(of: model.migrationCompleted) { newValue in
                handleMigrationCompletion()
            }
            .padding(.horizontal)
            .overlay(loadingOverlay)
            .alert(item: Binding(
                get: { model.error.map { AlertItem(message: $0) } },
                set: { _ in model.error = nil }
            )) { alertItem in
                Alert(
                    title: Text(""),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var headerView: some View {
        Text("Migrate your account to continue using it.")
            .multilineTextAlignment(.center)
            .padding(.vertical)
    }
    
    private var profileSection: some View {
        VStack(spacing: 20) {
            AvatarImageView(model: model, width: 100, height: 100, textSize: 48)
            if !model.profileName.isEmpty {
                Text(model.profileName)
                    .font(.headline)
            }
        }
    }
    
    private var accountInfoSection: some View {
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
    }
    
    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter your account password to migrate")
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
        }) {
            Text("Migrate")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.jamiColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .disabled(model.needsPassword && password.isEmpty || model.isLoading)
    }
    
    private var removeButton: some View {
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
            onCompletion?()
            model.migrationCompleted = false
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
