import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices

// MARK: - Main View

struct ShareView: View {
    // Extension data
    let items: [NSExtensionItem]
    
    // Account and conversations
    let accountList: [String]
    let conversationsByAccount: [String: [String]]
    
    // Actions from ViewController
    let closeAction: () -> Void
    let sendAction: (String, String, String, String) -> Void
    let sendFileAction: (String, String, String, String, String) -> Void
    
    @State private var expandedAccounts: Set<String> = []
    @State private var selectedConversation: String? = nil
    @State private var showAlert: Bool = false
    @ObservedObject var viewModel: ShareViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SharedItemsSection(items: items)

                    if !viewModel.fileTransferStatus.isEmpty {
                        Text("File Transfer Status: \(viewModel.fileTransferStatus)")
                            .font(.caption)
                            .padding()
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Divider()

                    AccountsSection(
                        accountList: accountList,
                        conversationsByAccount: conversationsByAccount,
                        expandedAccounts: $expandedAccounts,
                        sendAction: sendAllItems
                    )

                    Spacer()

                    Button("Close", action: closeAction)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Share Extension")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Unsupported Content"),
                      message: Text("The shared item type is not supported yet."),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private func sendAllItems(to convo: String, account: String) {
        for item in items {
            if let attachments = item.attachments {
                for provider in attachments {
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, _) in
                            if let text = data as? String {
                                sendAction(convo, account, text, "")
                            } else {
                                showAlert = true
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                let filename = url.lastPathComponent
                                sendFileAction(convo, account, url.absoluteString, filename, "")
                            } else {
                                showAlert = true
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                let filename = url.lastPathComponent
                                sendFileAction(convo, account, url.absoluteString, filename, "")
                            } else {
                                showAlert = true
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                sendAction(convo, account, url.absoluteString, "")
                            } else if let str = data as? String {
                                sendAction(convo, account, str, "")
                            } else {
                                showAlert = true
                            }
                        }
                    } else {
                        showAlert = true
                    }
                }
            } else {
                showAlert = true
            }
        }
    }
}


// MARK: - Shared Items Section

struct SharedItemsSection: View {
    let items: [NSExtensionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared Content")
                .font(.headline)

            if !items.isEmpty {
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

// MARK: - Accounts Section

struct AccountsSection: View {
    let accountList: [String]
    let conversationsByAccount: [String: [String]]
    @Binding var expandedAccounts: Set<String>
    let sendAction: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accounts & Conversations")
                .font(.headline)

            if accountList.isEmpty {
                Text("No accounts available.")
                    .foregroundColor(.gray)
            } else {
                ForEach(accountList, id: \.self) { account in
                    AccountDisclosureView(
                        account: account,
                        conversations: conversationsByAccount[account] ?? [],
                        isExpanded: Binding(
                            get: { expandedAccounts.contains(account) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedAccounts.insert(account)
                                } else {
                                    expandedAccounts.remove(account)
                                }
                            }
                        ),
                        onSelectConversation: { convo in
                            sendAction(convo, account)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Account Disclosure View

struct AccountDisclosureView: View {
    let account: String
    let conversations: [String]
    @Binding var isExpanded: Bool
    let onSelectConversation: (String) -> Void

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                if conversations.isEmpty {
                    Text("No conversations.")
                        .foregroundColor(.gray)
                        .padding(.leading, 10)
                } else {
                    ForEach(conversations, id: \.self) { convo in
                        Button(action: {
                            onSelectConversation(convo)
                        }) {
                            Text(convo)
                                .padding(.leading, 10)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            },
            label: {
                Text(account)
                    .font(.subheadline)
                    .bold()
            }
        )
        .padding(.vertical, 4)
    }
}

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
