import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import CryptoKit

struct ShareView: View {
    // Extension data
    let items: [NSExtensionItem]
    
    // Account and conversations
    let accountList: [(id: String, name: String)]

    let conversationsByAccount: [String: [String]]
    
    // Actions from ViewController
    let closeAction: () -> Void
    let sendAction: (String, String, String, String) -> Void
    let sendFileAction: (String, String, String, String, String) -> Void
    
    @State private var selectedConversation: String? = nil
    @State private var showUnsupportedAlert: Bool = false
    @State private var showNoAccountAlert: Bool = false
    @ObservedObject var viewModel: ShareViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SharedItemsSection(items: items)

                    if !viewModel.transmissionSummary.isEmpty {
                        Text(viewModel.transmissionSummary)
                            .font(.caption)
                            .padding()
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                    }

                    Divider()

                    let acl = accountList.isEmpty
                        ? conversationsByAccount.keys.map { (id: $0, name: $0) }
                        : accountList

                    AccountsSection(
                        accountList: acl,
                        conversationsByAccount: conversationsByAccount,
                        sendAction: sendAllItems
                    )


                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Jami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        closeAction()
                    }
                }
            }
            .onAppear {
                if conversationsByAccount.isEmpty {
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
                                showUnsupportedAlert = true
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                let filename = url.lastPathComponent
                                sendFileAction(convo, account, url.absoluteString, filename, "")
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                let filename = url.lastPathComponent
                                sendFileAction(convo, account, url.absoluteString, filename, "")
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (data, _) in
                            if let url = data as? URL {
                                sendAction(convo, account, url.absoluteString, "")
                            } else if let str = data as? String {
                                sendAction(convo, account, str, "")
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    } else {
                        showUnsupportedAlert = true
                    }
                }
            } else {
                showUnsupportedAlert = true
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
    let accountList: [(id: String, name: String)]
    let conversationsByAccount: [String: [String]]
    @State private var selectedAccountId: String?

    let sendAction: (String, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Horizontal scroll of accounts
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(accountList, id: \.id) { account in
                        VStack {
                            Circle()
                                .fill(selectedAccountId == account.id ? Color.blue : Color(backgroundColor(for: account.name)))
                            
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(account.name.prefix(1).uppercased())
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                                .onTapGesture {
                                    selectedAccountId = account.id
                                }

                            Text(account.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 70)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Conversations for selected account
            if let selected = selectedAccountId {
                if let conversations = conversationsByAccount[selected], !conversations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(conversations, id: \.self) { convo in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(backgroundColor(for: convo)))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(convo.prefix(1).uppercased())
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    )

                                Text(convo)
                                    .font(.body)

                                Spacer()
                            }
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                sendAction(convo, selected)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .center, spacing: 12) {
                        Text("No conversation found")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                }
            }
        }
        .padding(.top)
        .onAppear {
            if selectedAccountId == nil {
                selectedAccountId = accountList.first?.id
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
    
    let prefix = String(md5HexString.prefix(8))
    var index: UInt64 = 0
    let scanner = Scanner(string: prefix)
    if scanner.scanHexInt64(&index) {
        let colorIndex = Int(index) % avatarColors.count
        return avatarColors[colorIndex]
    }
    
    // fallback color if something fails
    return defaultAvatarColor
}
