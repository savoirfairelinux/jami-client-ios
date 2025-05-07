import SwiftUI

struct AccountMigrationAlert: View {
    @StateObject private var model: AccountMigrationModel
    @Binding var isPresented: Bool
    @SwiftUI.State private var password: String = ""

    init(accountId: String, accountService: AccountsService, profileService: ProfilesService, isPresented: Binding<Bool>) {
        _model = StateObject(wrappedValue: AccountMigrationModel(accountId: accountId, 
                                                               accountService: accountService, 
                                                               profileService: profileService))
        _isPresented = isPresented
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                if let profileImage = model.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                }
                
                Text(model.accountName)
                    .font(.headline)
                
                if !model.jamiId.isEmpty {
                    Text(model.jamiId)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                
                if !model.username.isEmpty {
                    Text(model.username)
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            .padding(.top, 8)
            
            // Explanation
            Text("Please migrate your account to continue using it.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .padding(.horizontal)
            
            // Password field if needed
            if model.needsPassword {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Text("Please enter your account password to migrate")
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
                }) {
                    Text("Remove")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                .disabled(model.isLoading)
                
                if model.canCancel {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(Color(UIColor.label))
                            .cornerRadius(8)
                    }
                    .disabled(model.isLoading)
                }
                }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
        .frame(maxWidth: 400)
        .padding()
//        .overlay(
//            Group {
//                if model.isLoading {
//                    Color.black.opacity(0.4)
//                        .overlay(
//                            ProgressView()
//                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                        )
//                }
//            }
//        )
//        .alert(item: Binding(
//            get: { model.error.map { AlertItem(message: $0) } },
//            set: { _ in model.error = nil }
//        )) { alertItem in
//            Alert(
//                title: Text("Error"),
//                message: Text(alertItem.message),
//                dismissButton: .default(Text("OK"))
//            )
//        }
    }
}

// Helper for alert binding
struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
