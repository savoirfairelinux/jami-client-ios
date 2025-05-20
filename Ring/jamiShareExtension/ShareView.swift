import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import CryptoKit 




struct ShareView: View {
    
    let closeAction: () -> Void
    let items: [NSExtensionItem]
    @StateObject var viewModel: ShareViewModel
    
    
    @State private var showUnsupportedAlert: Bool = false
    @State private var showNoAccountAlert: Bool = false
    @State private var selectedAccountId: String? 
    @State private var isSending: Bool = false 
    
    
    
    
    
    init(items: [NSExtensionItem], viewModel: ShareViewModel, closeAction: @escaping () -> Void) {
        self.items = items
        self._viewModel = StateObject(wrappedValue: ShareViewModel(sharedItems: items)) 
        self.closeAction = closeAction
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SharedItemsSection(items: items)
                        
                        Divider()
                        
                        AccountsSection(
                            selectedAccountId: $selectedAccountId,
                            viewModel: viewModel,
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
            
            
            if isSending {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        ProgressView("Sending...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.8))
                            )
                    )
            }
        }
        .onChange(of: viewModel.transmissionSummary) { newValue in
            if !newValue.isEmpty {
                isSending = false
                viewModel.closeShareExtension()
                closeAction()
            }
        }
    }
    
    
    
    
    
    private func sendAllItems(to convoId: String, accountId: String) {
        
        for item in items {
            if let attachments = item.attachments {
                for provider in attachments {
                    
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (data, _) in
                            if let text = data as? String {
                                viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: text)
                            } else {
                                showUnsupportedAlert = true
                            }
                        }
                    }
                    
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
                    
                    else {
                        showUnsupportedAlert = true
                    }
                }
            }
            
            else {
                showUnsupportedAlert = true
            }
        }
        
        isSending = true
    }
}




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




struct AccountRowView: View {
    @ObservedObject var account: AccountViewModel

    var body: some View {
        HStack(spacing: 12) {
            
            if let avatarImage = imageFromBase64(account.avatar), !account.avatar.isEmpty {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                
                Circle()
                    .fill(Color(backgroundColor(for: account.name)))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(account.name.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }

            
            Text(account.name)
                .foregroundColor(.primary)

            Image(systemName: "chevron.down")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}




struct ConversationRowView: View {
    @ObservedObject var conversation: ConversationViewModel
    let sendAction: (String, String) -> Void

    var body: some View {
        Button(action: {
            sendAction(conversation.id, conversation.accountId)
        }) {
            HStack(spacing: 12) {
                
                if conversation.accountType == "single" {
                    if !conversation.avatar.isEmpty,
                       let avatarImage = imageFromBase64(conversation.avatar) {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(backgroundColor(for: conversation.name)))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(conversation.name.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    let systemName = conversation.accountType == "group" ? "person.2" : "person"
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: systemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.gray)
                        )
                }

                
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




struct AccountsSection: View {
    @Binding var selectedAccountId: String? 
    let viewModel: ShareViewModel 
    let sendAction: (String, String) -> Void 

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
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
                
                Text("No accounts loaded.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                
                Text("Select an account...")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            
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
            
            if selectedAccountId == nil, let firstAccount = viewModel.accountList.first {
                selectedAccountId = firstAccount.id
            }
        }
        
        .onChange(of: viewModel.accountList) { newAccountList in
            if selectedAccountId == nil, let firstAccount = newAccountList.first {
                selectedAccountId = firstAccount.id
            }
        }
    }
}



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

        let red = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgb & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

let defaultAvatarColor = UIColor(hexString: "808080")!


let avatarColors = [
    UIColor(hexString: "#f44336")!, 
    UIColor(hexString: "#e91e63")!, 
    UIColor(hexString: "#9c27b0")!, 
    UIColor(hexString: "#673ab7")!, 
    UIColor(hexString: "#3f51b5")!, 
    UIColor(hexString: "#2196f3")!, 
    UIColor(hexString: "#00bcd4")!, 
    UIColor(hexString: "#009688")!, 
    UIColor(hexString: "#4caf50")!, 
    UIColor(hexString: "#8bc34a")!, 
    UIColor(hexString: "#9e9e9e")!, 
    UIColor(hexString: "#cddc39")!, 
    UIColor(hexString: "#ffc107")!, 
    UIColor(hexString: "#ff5722")!, 
    UIColor(hexString: "#795548")!, 
    UIColor(hexString: "#607d8b")!  
]

func backgroundColor(for username: String) -> UIColor {
    
    let md5Data = Insecure.MD5.hash(data: Data(username.utf8))
    let md5HexString = md5Data.map { String(format: "%02hhx", $0) }.joined()

    let prefix = String(md5HexString.prefix(1))
    var index: UInt64 = 0
    let scanner = Scanner(string: prefix)
    if scanner.scanHexInt64(&index) {
        let colorIndex = Int(index) % avatarColors.count
        return avatarColors[colorIndex]
    }

    
    return defaultAvatarColor
}

func imageFromBase64(_ base64: String) -> UIImage? {
    guard let data = Data(base64Encoded: base64),
          let image = UIImage(data: data) else { return nil }
    return image
}
