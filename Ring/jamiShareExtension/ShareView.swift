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
import UIKit
import UniformTypeIdentifiers
import CryptoKit

struct ShareView: View {

    let closeAction: () -> Void
    let items: [NSExtensionItem]
    @ObservedObject var viewModel: ShareViewModel

    @State private var showUnsupportedAlert: Bool = false
    @State private var selectedAccountId: String?
    @State private var isSending: Bool = false
    @State private var selectedConversationIds: Set<String> = []
    @State private var buttonHeight: CGFloat = 0
    @State private var showingAccountPicker: Bool = false
    @State private var searchText: String = ""

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
            ZStack(alignment: .top) {
                if let selectedId = selectedAccountId {
                    ConversationSection(
                        selectedAccountId: selectedId,
                        viewModel: viewModel,
                        selectedConversationIds: $selectedConversationIds,
                        buttonHeight: $buttonHeight,
                        isSending: $isSending,
                        searchText: $searchText,
                        sendSelected: sendSelected
                    )
                }
                if viewModel.isLoading {
                    LoadingStateView()
                }
                if isSending {
                    sendingOverlay()
                }
            }
            .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.rootView)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AccountNavigationButton(
                        selectedAccountId: $selectedAccountId,
                        viewModel: viewModel
                    )
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.close) {
                        closeAction()
                    }
                }
            }
            .modifier(SearchableModifier(searchText: $searchText))
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
    
    private func sendingOverlay() -> some View {
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
                    .accessibilityLabel(Text(L10n.ShareExtension.sending))
                    .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.sendingProgress)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            UIAccessibility.post(notification: .announcement, argument: L10n.ShareExtension.sending)
                        }
                    }
            )
            .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.sendingOverlay)
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

    private func sendSelected() {
        guard let accountId = selectedAccountId else { return }
        isSending = true
        for convoId in selectedConversationIds {
            sendAllItems(to: convoId, accountId: accountId)
        }
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

struct AccountNavigationButton: View {
    @Binding var selectedAccountId: String?
    @ObservedObject var viewModel: ShareViewModel
    @State private var showingAccountPicker: Bool = false

    var body: some View {
        VStack {
            if let selectedAccountId = selectedAccountId, !selectedAccountId.isEmpty,
               let selectedAccount = viewModel.accountList.first(where: { $0.id == selectedAccountId }) {
                Button(action: {
                    showingAccountPicker = true
                }) {
                    AccountMenuLabelView(account: selectedAccount)
                        .padding(.horizontal, 4)
                }
                .sheet(isPresented: $showingAccountPicker) {
                    AccountSelectionSheet(
                        accounts: viewModel.accountList,
                        selectedAccountId: $selectedAccountId,
                        isPresented: $showingAccountPicker
                    )
                }
                .accessibilityLabel("Selected account: \(selectedAccount.name). Tap to change account.")
                .accessibilityHint("Double tap to open account selection")
            } else {
                EmptyView()
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

struct ConversationSection: View {
    let selectedAccountId: String
    @ObservedObject var viewModel: ShareViewModel
    @Binding var selectedConversationIds: Set<String>
    @Binding var buttonHeight: CGFloat
    @Binding var isSending: Bool
    @Binding var searchText: String
    let sendSelected: () -> Void

    private var filteredConversations: [ConversationViewModel] {
        guard let conversations = viewModel.conversationsByAccount[selectedAccountId] else { return [] }

        if searchText.isEmpty {
            return conversations
        }

        return conversations.filter { conversation in
            conversation.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        if !filteredConversations.isEmpty {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    ForEach(filteredConversations) { conversation in
                        ConversationSelectableRow(
                            conversation: conversation,
                            isSelected: selectedConversationIds.contains(conversation.id),
                            toggleAction: {
                                if selectedConversationIds.contains(conversation.id) {
                                    selectedConversationIds.remove(conversation.id)
                                } else {
                                    selectedConversationIds.insert(conversation.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.conversationsList)
                if !(selectedConversationIds.isEmpty || isSending) {
                    VStack {
                        HStack {
                            Spacer()
                            Button("Share file with \(selectedConversationIds.count) contacts") {
                                UIAccessibility.post(notification: .announcement, argument: L10n.ShareExtension.sending)
                                sendSelected()
                            }
                            .disabled(selectedConversationIds.isEmpty || isSending)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(
                                ZStack {
                                    Color.accentColor
                                        .clipShape(Capsule())
                                }
                            )
                            .foregroundColor(.white)
                            .shadow(color: Color(.black).opacity(0.2), radius: 3, x: 0, y: 3)
                            Spacer()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        ZStack {
                            VisualEffectView(effect: UIBlurEffect(style: .regular))
                                .mask(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(.systemBackground).opacity(0.7),
                                            Color(.systemBackground).opacity(0.5),
                                            Color(.systemBackground).opacity(0.1)
                                        ]),
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .shadow(color: Color(.systemBackground), radius: 15, x: 0, y: 5)
                    )
                }
            }
        } else {
            VStack {
                if searchText.isEmpty {
                    Text(L10n.ShareExtension.noConversation)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text("No conversations found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                }
            }
        }
    }

}

struct ConversationSelectableRow: View {
    @ObservedObject var conversation: ConversationViewModel
    let isSelected: Bool
    let toggleAction: () -> Void

    var body: some View {
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

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleAction()
        }
        .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.conversationButtonPrefix + conversation.id)
        .accessibilityLabel(Text(conversation.name))
        .accessibilityHint("Double tap to select this conversation")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onAppear {
            conversation.loadDetailsIfNeeded()
        }
    }
}

struct AccountMenuLabelView: View {
    @ObservedObject var account: AccountViewModel

    var body: some View {
        HStack(spacing: 8) {
            AccountAvatarView(account: account, size: 30)

                Text(account.name)
                .font(.callout)
                .foregroundColor(.primary)
                .truncationMode(.middle)
                .lineLimit(1)
                .frame(maxWidth: 150)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Selected account: \(account.name). Tap to change account."))
        .accessibilityHint("Double tap to open account selection")
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
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ProgressView()
                .scaleEffect(1.5)
                .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.loadingProgress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.loadingView)
    }
}

struct ShareExtensionAccessibilityIdentifiers {
    static let title = "share_title"
    static let rootView = "share_root_view"
    static let closeButton = "share_close_button"
    static let sendingOverlay = "share_sending_overlay"
    static let sendingProgress = "share_sending_progress"

    static let accountsSectionMenu = "share_account_menu"
    static let accountPicker = "share_account_picker"
    static let selectedAccountRow = "share_selected_account_row"
    static let noAccountLabel = "share_no_account_label"
    static let selectAccountLabel = "share_select_account_label"

    static let conversationsTitle = "share_conversations_title"
    static let conversationsList = "share_conversation_list"
    static let conversationRowPrefix = "share_conversation_row_"
    static let conversationButtonPrefix = "share_conversation_button_"

    static let loadingView = "share_loading_view"
    static let loadingProgress = "share_loading_progress"
}

// MARK: - Account Selection Sheet
struct AccountSelectionSheet: View {
    let accounts: [AccountViewModel]
    @Binding var selectedAccountId: String?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select account")) {
                    ForEach(accounts) { account in
                        AccountSelectionRowView(
                            account: account,
                            isSelected: account.id == selectedAccountId
                        ) {
                            selectedAccountId = account.id
                            isPresented = false
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct AccountSelectionRowView: View {
    @ObservedObject var account: AccountViewModel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatarView(account: account, size: 45)

                Text(account.name)
                    .foregroundColor(.primary)
                    .truncationMode(.middle)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct AccountAvatarView: View {
    @ObservedObject var account: AccountViewModel
    let size: CGFloat

    var body: some View {
        if account.avatarType == .single {
            if let avatarImage = account.processedAvatar {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(account.bgColor)
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(account.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(.white)
                    )
            }
        } else {
            Circle()
                .fill(account.bgColor)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.5, height: size * 0.5)
                        .foregroundColor(.white)
                )
        }
    }
}

// MARK: - Visual Effect View
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

// MARK: - Searchable Modifier with iOS Version Check
struct SearchableModifier: ViewModifier {
    @Binding var searchText: String

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .searchable(text: $searchText, prompt: "Search conversations")
        } else {
            // Fallback for iOS 14.5-14.9: Use a custom search bar
            content
                .overlay(
                    VStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search conversations", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        Spacer()
                    }
                    .background(Color(.systemBackground))
                )
        }
    }
}
