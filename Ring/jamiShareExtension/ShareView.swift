import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import CryptoKit // Assuming CryptoKit is used for imageFromBase64 or similar.

// MARK: - ShareView

/// The main view for the share extension.
struct ShareView: View {
    // Action to close the share extension
    let closeAction: () -> Void
    
    // State variables for UI alerts and selections
    @State private var showUnsupportedAlert: Bool = false
    @State private var showNoAccountAlert: Bool = false
    @State private var selectedAccountId: String? // Tracks the ID of the currently selected account

    // Shared items received by the extension
    let items: [NSExtensionItem]
    // The main ViewModel for managing share extension logic and data
    @StateObject var viewModel: ShareViewModel
    
    /// Initializes the ShareView.
    /// - Parameters:
    ///   - items: The array of `NSExtensionItem` objects shared with the extension.
    ///   - closeAction: A closure to execute when the extension needs to be closed.
    init(items: [NSExtensionItem], closeAction: @escaping () -> Void) {
        self.items = items
        self.closeAction = closeAction
        _viewModel = StateObject(wrappedValue: ShareViewModel(sharedItems: items))

    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Section to display the content of the shared items
                    SharedItemsSection(items: items)

                    // Optional: Uncomment to display the transmission summary once available
                    // if !viewModel.transmissionSummary.isEmpty {
                    //    Text(viewModel.transmissionSummary)
                    //        .font(.caption)
                    //        .padding()
                    //        .background(Color.yellow.opacity(0.2))
                    //        .cornerRadius(8)
                    // }

                    Divider() // Visual separator

                    // Section to display accounts and conversations for selection
                    AccountsSection(
                        selectedAccountId: $selectedAccountId, // Pass binding for selection
                        viewModel: viewModel, // Pass the entire viewModel
                        sendAction: sendAllItems // Pass the action to send items
                    )

                    Spacer() // Pushes content to the top
                }
                .padding()
            }
            .navigationTitle("Jami") // Navigation bar title
            .navigationBarTitleDisplayMode(.inline) // Compact title display
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { // Close button in the navigation bar
                        closeAction()
                    }
                }
            }
            // Logic to show alerts based on ViewModel state
            .onAppear {
                // Show "No Account" alert if no accounts are available initially
                if viewModel.accountList.isEmpty {
                    showNoAccountAlert = true
                }
            }
            .alert(isPresented: $showUnsupportedAlert) {
                Alert(title: Text("Unsupported Content"),
                      message: Text("The shared item type is not supported yet."),
                      dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showNoAccountAlert) {
                Alert(
                    title: Text("No Account Found"),
                    message: Text("Please create an account in the main app to continue."),
                    dismissButton: .default(Text("OK"), action: closeAction)
                )
            }
        }
        // Observe changes in transmissionSummary to automatically close the extension
        .onChange(of: viewModel.transmissionSummary) { newValue in
            if !newValue.isEmpty {
                closeAction()
            }
        }
    }

    /// Handles sending all shared items to the selected conversation and account.
    /// - Parameters:
    ///   - convoId: The ID of the conversation to send to.
    ///   - accountId: The ID of the account to send from.
    private func sendAllItems(to convoId: String, accountId: String) {
        // Iterate through all shared items and handle them based on their type
        for item in items {
            if let attachments = item.attachments {
                for provider in attachments {
                    // Handle plain text
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, _) in
                            if let text = data as? String {
                                viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: text)
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    }
                    // Handle images
                    else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                let filename = url.lastPathComponent
                                viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url.absoluteString, fileName: filename)
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    }
                    // Handle generic file URLs
                    else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                let filename = url.lastPathComponent
                                viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url.absoluteString, fileName: filename)
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    }
                    // Handle general URLs (e.g., web links)
                    else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: url.absoluteString)
                            } else if let str = data as? String {
                                viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: str)
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    }
                    // If item type is not supported
                    else {
                        showUnsupportedAlert = true
                    }
                }
            }
            // If no attachments are found
            else {
                showUnsupportedAlert = true
            }
        }
    }
}


// MARK: - Shared Items Section

/// A view responsible for displaying the content of shared `NSExtensionItem`s.
struct SharedItemsSection: View {
    let items: [NSExtensionItem] // The shared items to display

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared Content")
                .font(.headline)

            if !items.isEmpty {
                // Iterate through each shared item and display its content
                ForEach(items.indices, id: \.self) { index in
                    ItemView(item: items[index])
                        .padding(.vertical, 8)
                }
            } else {
                Text("No items shared.")
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Account Row View

/// A view that displays a single account row with avatar and name
struct AccountRowView: View {
    @ObservedObject var account: AccountViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Display account avatar
            if let avatarImage = imageFromBase64(account.avatar), !account.avatar.isEmpty {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                // Fallback to a circular placeholder with first letter of the name
                Circle()
                    .fill(Color(backgroundColor(for: account.name)))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(account.name.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }

            // Display account name
            Text(account.name)
                .foregroundColor(.primary)

            Image(systemName: "chevron.down")
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Conversation Row View

/// A view that displays a single conversation row with avatar, name and send button
struct ConversationRowView: View {
    @ObservedObject var conversation: ConversationViewModel
    let sendAction: (String, String) -> Void
    
    var body: some View {
        Button(action: {
            sendAction(conversation.accountId, conversation.id)
        }) {
            HStack(spacing: 12) {
                // Display conversation avatar
                if !conversation.avatar.isEmpty, let avatarImage = imageFromBase64(conversation.avatar) {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    // Fallback to a circular placeholder with first letter of the name
                    Circle()
                        .fill(Color(backgroundColor(for: conversation.name)))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(conversation.name.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                }

                // Display conversation name
                Text(conversation.name)
                    .foregroundColor(.primary)

                Spacer()

            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

// MARK: - Accounts Section

/// A view that displays a list of accounts and their conversations, allowing selection.
struct AccountsSection: View {
    @Binding var selectedAccountId: String? // Binding to the selected account's ID in ShareView
    let viewModel: ShareViewModel // The entire viewModel
    let sendAction: (String, String) -> Void // Action to send items

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Account selector menu
            if let selectedAccount = viewModel.accountList.first(where: { $0.id == selectedAccountId }) {
                Menu {
                    Picker("Select Account", selection: $selectedAccountId) {
                        ForEach(viewModel.accountList) { account in
                            Text(account.name).tag(account.id as String?)
                        }
                    }
                } label: {
                    AccountRowView(account: selectedAccount)
                }
                .padding(.horizontal)
            } else if viewModel.accountList.isEmpty {
                // Message when no accounts are loaded yet (or ever)
                Text("No accounts loaded.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Fallback for when no account is selected yet, but list is not empty
                Text("Select an account...")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            // Conversations for the selected account
            if let selectedId = selectedAccountId {
                if let conversations = viewModel.conversationsByAccount[selectedId], !conversations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Conversations")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(conversations) { conversation in
                            ConversationRowView(conversation: conversation, sendAction: sendAction)
                        }
                    }
                } else {
                    Text("No conversations available.")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
        }
        .onAppear {
            // Set the initial selected account if none is selected yet and accounts are available
            if selectedAccountId == nil, let firstAccount = viewModel.accountList.first {
                selectedAccountId = firstAccount.id
            }
        }
        // React to changes in the accountList (e.g., if accounts load after initial empty state)
        .onChange(of: viewModel.accountList) { newAccountList in
            if selectedAccountId == nil, let firstAccount = newAccountList.first {
                selectedAccountId = firstAccount.id
            }
        }
    }
}


// MARK: - Helper Views and Functions

// MARK: - ItemView and Preview Models

struct ItemView: View {
    let item: NSExtensionItem
    @State private var contentPreviews: [ContentPreview] = []
    @State private var showAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Item:")
                .font(.subheadline)
                .bold()

            if contentPreviews.isEmpty {
                Text("Loading content...")
                    .foregroundColor(.gray)
                    .onAppear { loadContent() }
            } else {
                ForEach(contentPreviews) { preview in
                    switch preview.type {
                    case .text(let string):
                        VStack(alignment: .leading) {
                            Text("Type: Text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(string)
                                .padding(6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                    case .image(let image, let url):
                        VStack(alignment: .leading) {
                            Text("Type: Image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 150)
                                .cornerRadius(8)
                            if let url = url {
                                Text(url.absoluteString)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    case .file(let url):
                        VStack(alignment: .leading) {
                            Text("Type: File")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(url.lastPathComponent)
                                .italic()
                                .foregroundColor(.blue)
                        }
                    case .url(let url):
                        VStack(alignment: .leading) {
                            Text("Type: URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(url.absoluteString)
                                .underline()
                                .foregroundColor(.blue)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Unsupported Content"),
                  message: Text("Could not load item content."),
                  dismissButton: .default(Text("OK")))
        }
    }

    func loadContent() {
        guard let attachments = item.attachments else {
            showAlert = true
            return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, _) in
                    if let text = data as? String {
                        DispatchQueue.main.async {
                            contentPreviews.append(ContentPreview(.text(text)))
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (data, _) in
                    if let url = data as? URL, let uiImage = UIImage(contentsOfFile: url.path) {
                        DispatchQueue.main.async {
                            contentPreviews.append(ContentPreview(.image(Image(uiImage: uiImage), url)))
                        }
                    } else if let uiImage = data as? UIImage {
                        DispatchQueue.main.async {
                            contentPreviews.append(ContentPreview(.image(Image(uiImage: uiImage), nil)))
                        }
                    } else {
                        DispatchQueue.main.async { showAlert = true }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
                    if let url = data as? URL {
                        DispatchQueue.main.async {
                            contentPreviews.append(ContentPreview(.file(url)))
                        }
                    } else {
                        DispatchQueue.main.async { showAlert = true }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (data, _) in
                    if let url = data as? URL {
                        DispatchQueue.main.async {
                            contentPreviews.append(ContentPreview(.url(url)))
                        }
                    } else {
                        DispatchQueue.main.async { showAlert = true }
                    }
                }
            } else {
                DispatchQueue.main.async { showAlert = true }
            }
        }
    }
}

enum ContentPreviewType: Identifiable {
    case text(String)
    case image(Image, URL?)
    case file(URL)
    case url(URL)

    var id: UUID { UUID() }
}

struct ContentPreview: Identifiable {
    let id = UUID()
    let type: ContentPreviewType
    init(_ type: ContentPreviewType) { self.type = type }
}

extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

let defaultAvatarColor = UIColor(hexString: "808080")!

// Colors from material.io
let avatarColors = [
    UIColor(hexString: "#f44336")!, // Red
    UIColor(hexString: "#e91e63")!, // Pink
    UIColor(hexString: "#9c27b0")!, // Purple
    UIColor(hexString: "#673ab7")!, // Deep Purple
    UIColor(hexString: "#3f51b5")!, // Indigo
    UIColor(hexString: "#2196f3")!, // Blue
    UIColor(hexString: "#00bcd4")!, // Cyan
    UIColor(hexString: "#009688")!, // Teal
    UIColor(hexString: "#4caf50")!, // Green
    UIColor(hexString: "#8bc34a")!, // Light Green
    UIColor(hexString: "#9e9e9e")!, // Grey
    UIColor(hexString: "#cddc39")!, // Lime
    UIColor(hexString: "#ffc107")!, // Amber
    UIColor(hexString: "#ff5722")!, // Deep Orange
    UIColor(hexString: "#795548")!, // Brown
    UIColor(hexString: "#607d8b")!  // Blue Grey
];

func backgroundColor(for username: String) -> UIColor {
    // Compute MD5 hash of username
    let md5Data = Insecure.MD5.hash(data: Data(username.utf8))
    let md5HexString = md5Data.map { String(format: "%02hhx", $0) }.joined()
    
    let prefix = String(md5HexString.prefix(1))
    var index: UInt64 = 0
    let scanner = Scanner(string: prefix)
    if scanner.scanHexInt64(&index) {
        let colorIndex = Int(index) % avatarColors.count
        return avatarColors[colorIndex]
    }
    
    // fallback color if something fails
    return defaultAvatarColor
}

func imageFromBase64(_ base64: String) -> UIImage? {
    guard let data = Data(base64Encoded: base64),
          let image = UIImage(data: data) else { return nil }
    return image
}
