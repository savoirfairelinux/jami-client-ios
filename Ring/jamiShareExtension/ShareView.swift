/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import UniformTypeIdentifiers
import CryptoKit

struct ShareView: View {

    let closeAction: () -> Void
    let items: [NSExtensionItem]
    @ObservedObject var viewModel: ShareViewModel

    @State private var showUnsupportedAlert: Bool = false
    @State private var showNoAccountAlert: Bool = false
    @State private var selectedAccountId: String?
    @State private var isSending: Bool = false

    init(items: [NSExtensionItem], viewModel: ShareViewModel, closeAction: @escaping () -> Void) {
        self.items = items
        self.viewModel = viewModel
        self.closeAction = closeAction
    }

    var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AccountsSection(
                            selectedAccountId: $selectedAccountId,
                            viewModel: viewModel,
                            sendAction: sendAllItems
                        )

                        if let selectedId = selectedAccountId {
                            ConversationSection(
                                selectedAccountId: selectedId,
                                viewModel: viewModel,
                                sendAction: sendAllItems
                            )
                        }

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

                    for item in items {
                        if let attachments = item.attachments {
                            for provider in attachments {
                                if !(
                                    provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ||
                                        provider.hasItemConformingToTypeIdentifier(UTType.zip.identifier)
                                ) {
                                    showUnsupportedAlert = true
                                    break
                                }
                            }
                        }
                    }

                }
                .alert(isPresented: $showNoAccountAlert) {
                    Alert(
                        title: Text("No Account Found"),
                        message: Text("Please create an account in the main app to continue."),
                        dismissButton: .default(Text("OK"), action: closeAction)
                    )
                }
                .alert(isPresented: $showUnsupportedAlert) {
                    Alert(
                        title: Text("Unsupported file type"),
                        message: Text("Jami doesn't currently support the file you want to share."),
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
        let supportedTypes: [(UTType, (NSItemProvider, Any?) -> Void)] = [
            (UTType.plainText, { _, data in
                if let text = data as? String {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: text)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.image, { _, data in
                if let url = data as? URL {
                    let filename = url.lastPathComponent
                    viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.fileURL, { _, data in
                if let url = data as? URL {
                    let filename = url.lastPathComponent
                    viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.url, { _, data in
                if let url = data as? URL {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: url.absoluteString)
                } else if let str = data as? String {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: str)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.pdf, { _, data in
                if let url = data as? URL {
                    let filename = url.lastPathComponent
                    viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.rtf, { _, data in
                if let url = data as? URL {
                    let filename = url.lastPathComponent
                    viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.html, { _, data in
                if let htmlString = data as? String {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: htmlString)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.audio, { _, data in
                if let url = data as? URL {
                    let filename = url.lastPathComponent
                    viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.movie, { _, data in
                if let url = data as? URL {
                    let filename = url.lastPathComponent
                    viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.zip, { _, data in
                if let url = data as? URL {
                    let filename = url.lastPathComponent
                    viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
                } else {
                    showUnsupportedAlert = true
                }
            })
        ]

        let fileHandler: (NSItemProvider, Any?) -> Void = { _, data in
            if let url = data as? URL {
                let filename = url.lastPathComponent
                viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
            } else {
                showUnsupportedAlert = true
            }
        }

        for item in items {
            guard let attachments = item.attachments else {
                showUnsupportedAlert = true
                continue
            }

            for provider in attachments {
                var handled = false

                for (type, handler) in supportedTypes {
                    if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                        provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { data, _ in
                            handler(provider, data)
                        }
                        handled = true
                        break
                    }
                }

                if !handled {
                    showUnsupportedAlert = true
                }
            }
        }

        isSending = true
    }

}

struct ConversationSection: View {
    let selectedAccountId: String
    let viewModel: ShareViewModel
    let sendAction: (String, String) -> Void

    var body: some View {
        if let conversations = viewModel.conversationsByAccount[selectedAccountId], !conversations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Conversations")
                    .font(.headline)

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

struct AccountRowView: View {
    @ObservedObject var account: AccountViewModel

    var body: some View {
        HStack(spacing: 12) {
            
            let bgColor = Color(backgroundColor(for: account.name))

            if account.avatarType == .single {
                if !account.avatar.isEmpty,
                   let avatarImage = imageFromBase64(account.avatar) {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(bgColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(account.name.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                }
            } else {
                Circle()
                    .fill(bgColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    )
            }
            
            Text(account.name)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Image(systemName: "chevron.down")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal)
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

                let bgColor = Color(backgroundColor(for: conversation.name))

                if conversation.avatarType == .single {
                    if !conversation.avatar.isEmpty,
                       let avatarImage = imageFromBase64(conversation.avatar) {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(bgColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(conversation.name.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    let systemName = conversation.avatarType == .group ? "person.2" : "person"
                    Circle()
                        .fill(bgColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: systemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        )
                }

                Text(conversation.name)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

            }
            .padding(.vertical, 8)
        }
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
