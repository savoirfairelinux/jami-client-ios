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
    @State private var selectedAccountId: String?
    @State private var isSending: Bool = false

    let supportedTypes: [UTType] = [
        .plainText, .image, .fileURL, .url,
        .pdf, .rtf, .html, .audio, .movie, .zip
    ]

    init(items: [NSExtensionItem], viewModel: ShareViewModel, closeAction: @escaping () -> Void) {
        self.items = items
        self.viewModel = viewModel
        self.closeAction = closeAction
    }

    private func handleOnAppear() {
        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                let isSupported = supportedTypes.contains {
                    provider.hasItemConformingToTypeIdentifier($0.identifier)
                }

                if !isSupported {
                    showUnsupportedAlert = true
                    return
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    LoadingStateView()
                } else {
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
                if isSending {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            ProgressView(L10n.ShareExtension.sending)
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
            .navigationTitle(L10n.ShareExtension.appName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.close) {
                        closeAction()
                    }
                }
            }
            .navigationBarHidden(false)
            .alert(isPresented: $showUnsupportedAlert) {
                Alert(
                    title: Text(L10n.ShareExtension.UnsupportedType.title),
                    message: Text(L10n.ShareExtension.UnsupportedType.description),
                    dismissButton: .default(Text(L10n.Global.ok), action: closeAction)
                )
            }
            .onAppear {
                handleOnAppear()
            }
            .onChange(of: viewModel.transmissionSummary) { newValue in
                if !newValue.isEmpty {
                    isSending = false
                    closeAction()
                }
            }
            .onChange(of: viewModel.shouldCloseExtension) { shouldClose in
                if shouldClose {
                    closeAction()
                }
            }
        }
    }

    private func sendAllItems(to convoId: String, accountId: String) {
        let supportedTypes = getSupportedTypes(convoId: convoId, accountId: accountId)

        for item in items {
            guard let attachments = item.attachments else {
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

    private func getSupportedTypes(convoId: String, accountId: String) -> [(UTType, (NSItemProvider, Any?) -> Void)] {
        return [
            (UTType.plainText, { [weak viewModel] _, data in
                guard let viewModel else { return }
                if let text = data as? String {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: text)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.image, handleFileURL(convoId: convoId, accountId: accountId)),
            (UTType.fileURL, handleFileURL(convoId: convoId, accountId: accountId)),
            (UTType.url, { [weak viewModel] _, data in
                guard let viewModel else { return }
                if let url = data as? URL {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: url.absoluteString)
                } else if let str = data as? String {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: str)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.pdf, handleFileURL(convoId: convoId, accountId: accountId)),
            (UTType.rtf, handleFileURL(convoId: convoId, accountId: accountId)),
            (UTType.html, { [weak viewModel] _, data in
                guard let viewModel else { return }
                if let htmlString = data as? String {
                    viewModel.sendMessage(accountId: accountId, conversationId: convoId, message: htmlString)
                } else {
                    showUnsupportedAlert = true
                }
            }),
            (UTType.audio, handleFileURL(convoId: convoId, accountId: accountId)),
            (UTType.movie, handleFileURL(convoId: convoId, accountId: accountId)),
            (UTType.zip, handleFileURL(convoId: convoId, accountId: accountId))
        ]
    }

    private func handleFileURL(convoId: String, accountId: String) -> (NSItemProvider, Any?) -> Void {
        return { [weak viewModel] _, data in
            guard let viewModel else { return }
            if let url = data as? URL {
                let filename = url.lastPathComponent
                viewModel.sendFile(accountId: accountId, conversationId: convoId, filePath: url, fileName: filename)
            } else {
                showUnsupportedAlert = true
            }
        }
    }
}

struct ConversationSection: View {
    let selectedAccountId: String
    @ObservedObject var viewModel: ShareViewModel
    let sendAction: (String, String) -> Void

    var body: some View {
        if let conversations = viewModel.conversationsByAccount[selectedAccountId], !conversations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.ShareExtension.conversations)
                    .font(.headline)
                ScrollView {
                    ForEach(conversations) { conversation in
                        ConversationRowView(conversation: conversation, sendAction: sendAction)
                    }
                }
            }
        } else {
            Text(L10n.ShareExtension.noConversation)
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
            if account.avatarType == .single {
                if let avatarImage = account.processedAvatar {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 45, height: 45)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(account.bgColor)
                        .frame(width: 45, height: 45)
                        .overlay(
                            Text(String(account.name.prefix(1)).uppercased())
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                }
            } else {
                Circle()
                    .fill(account.bgColor)
                    .frame(width: 45, height: 45)
                    .overlay(
                        Image(systemName: "person")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.white)
                    )
            }

            Text(account.name)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .truncationMode(.middle)
                .lineLimit(1)

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
                if conversation.avatarType == .single {
                    if let avatarImage = conversation.processedAvatar {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 45, height: 45)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(conversation.bgColor)
                            .frame(width: 45, height: 45)
                            .overlay(
                                Text(String(conversation.name.prefix(1)).uppercased())
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    let systemName = conversation.avatarType == .group ? "person.2" : "person"
                    let imageSize: CGFloat = conversation.avatarType == .group ? 20 : 15
                    Circle()
                        .fill(conversation.bgColor)
                        .frame(width: 45, height: 45)
                        .overlay(
                            Image(systemName: systemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: imageSize, height: imageSize)
                                .foregroundColor(.white)
                        )
                }

                Text(conversation.name)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.middle)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            conversation.loadDetailsIfNeeded()
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
                    Picker(L10n.ShareExtension.selectAccount, selection: $selectedAccountId) {
                        ForEach(viewModel.accountList) { account in
                            Text(account.name).tag(account.id as String?)
                                .truncationMode(.middle)
                                .lineLimit(1)
                        }
                    }
                } label: {
                    AccountRowView(account: selectedAccount)
                }
            } else if viewModel.accountList.isEmpty {
                Text(L10n.ShareExtension.NoAccount.title)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Text(L10n.ShareExtension.selectAccount)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .onAppear { [weak viewModel] in
            guard let viewModel = viewModel else { return }
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

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
        }
        .background(Color(.systemBackground))
    }
}
