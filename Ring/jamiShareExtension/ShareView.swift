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
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            UIAccessibility.post(notification: .announcement, argument: L10n.ShareExtension.sending)
                        }
                    }
            )
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
                }, label: {
                    AccountSelectionView(account: selectedAccount)
                        .padding(.horizontal, 4)
                })
                .sheet(isPresented: $showingAccountPicker) {
                    AccountSelectionSheet(
                        accounts: viewModel.accountList,
                        selectedAccountId: $selectedAccountId,
                        isPresented: $showingAccountPicker
                    )
                }
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
            ConversationsView(
                conversations: filteredConversations,
                selectedConversationIds: $selectedConversationIds,
                isSending: isSending,
                onSend: sendSelected
            )
        } else {
            EmptyStateView(searchText: searchText)
        }
    }
}

struct ConversationsView: View {
    let conversations: [ConversationViewModel]
    @Binding var selectedConversationIds: Set<String>
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ConversationScrollView(
                conversations: conversations,
                selectedConversationIds: $selectedConversationIds
            )

            if shouldShowShareButton {
                ShareButtonView(
                    selectedCount: selectedConversationIds.count,
                    isSending: isSending,
                    onSend: onSend
                )
            }
        }
    }

    private var shouldShowShareButton: Bool {
        !selectedConversationIds.isEmpty && !isSending
    }
}

struct ConversationScrollView: View {
    let conversations: [ConversationViewModel]
    @Binding var selectedConversationIds: Set<String>

    var body: some View {
        ScrollView(showsIndicators: false) {
            ForEach(conversations) { conversation in
                ConversationSelectableRow(
                    conversation: conversation,
                    isSelected: selectedConversationIds.contains(conversation.id),
                    toggleAction: {
                        toggleSelection(for: conversation.id)
                    }
                )
            }
            Spacer()
                .frame(height: 80)
        }
        .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.conversationsList)
        .padding(.horizontal)
    }

    private func toggleSelection(for conversationId: String) {
        if selectedConversationIds.contains(conversationId) {
            selectedConversationIds.remove(conversationId)
        } else {
            selectedConversationIds.insert(conversationId)
        }
    }
}

struct ShareButtonView: View {
    let selectedCount: Int
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    UIAccessibility.post(notification: .announcement, argument: L10n.ShareExtension.sending)
                    onSend()
                }, label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(buttonText)
                            .fontWeight(.semibold)
                    }
                })
                .buttonStyle(ShareButtonStyle())
                .accessibilityLabel(buttonText)
                .accessibilityHint(L10n.ShareExtension.accessibilitySendButton)
                .accessibilityAddTraits(.isButton)
                Spacer()
            }
        }
        .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.shareButton)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShareButtonBackground())
    }

    private var buttonText: String {
        if selectedCount == 1 {
            return L10n.ShareExtension.sendToConversation(selectedCount)
        } else {
            return L10n.ShareExtension.sendToConversationsPlural(selectedCount)
        }
    }
}

struct ShareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.9)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(Capsule())

                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
            )
            .foregroundColor(.white)
            .shadow(
                color: Color.accentColor.opacity(0.3),
                radius: configuration.isPressed ? 2 : 2,
                x: 0,
                y: configuration.isPressed ? 1 : 1
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ShareButtonBackground: View {
    var body: some View {
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
    }
}

struct EmptyStateView: View {
    let searchText: String

    var body: some View {
        VStack {
            if searchText.isEmpty {
                NoConversationsView()
            } else {
                NoSearchResultsView()
            }
        }
    }
}

struct NoConversationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(L10n.Smartlist.noConversation)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Smartlist.noConversation)
        .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.noConversationsView)
        .padding(.bottom, 80)
        .padding(.horizontal)
    }
}

struct NoSearchResultsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(L10n.ShareExtension.noSearchResults)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text(L10n.ShareExtension.tryDifferentFilter)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.ShareExtension.noSearchResults). \(L10n.ShareExtension.tryDifferentFilter)")
        .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.noSearchResultsView)
        .padding(.horizontal)
    }
}

struct ConversationSelectableRow: View {
    @ObservedObject var conversation: ConversationViewModel
    let isSelected: Bool
    let toggleAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ConversationAvatarView(conversation: conversation, size: 45)

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
        .accessibilityLabel(Text(conversation.name))
        .accessibilityHint(L10n.ShareExtension.accessibilitySelectConversation)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onAppear {
            conversation.loadDetailsIfNeeded()
        }
    }
}

struct AccountSelectionView: View {
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
        .accessibilityLabel(Text(L10n.ShareExtension.accessibilitySelectedAccount(account.name)))
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

    func darker(by percentage: CGFloat) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage))
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage / 100, 1.0),
                           green: min(green + percentage / 100, 1.0),
                           blue: min(blue + percentage / 100, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }
}

let defaultAvatarColor = UIColor(hexString: "808080")!

let avatarColors = [
    UIColor(hexString: "#2196f3")!, // Blue
    UIColor(hexString: "#f44336")!, // Red
    UIColor(hexString: "#e91e63")!, // Pink
    UIColor(hexString: "#9c27b0")!, // Purple
    UIColor(hexString: "#673ab7")!, // Deep Purple
    UIColor(hexString: "#3f51b5")!, // Indigo
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
                .accessibilityLabel(L10n.ShareExtension.sending)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(ShareExtensionAccessibilityIdentifiers.loadingView)
    }
}

// MARK: - Account Selection Sheet
struct AccountSelectionSheet: View {
    let accounts: [AccountViewModel]
    @Binding var selectedAccountId: String?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(L10n.ShareExtension.selectAccountTitle)) {
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
                    Button(L10n.Global.close) {
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
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityLabel(Text(account.name))
        .accessibilityHint(L10n.ShareExtension.accessibilitySelectAccount)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

// MARK: - Avatar View
struct UnifiedAvatarView: View {
    let name: String
    let avatarType: AvatarType
    let processedAvatar: UIImage?
    let bgColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            if avatarType == .single, let avatarImage = processedAvatar {
                Image(uiImage: avatarImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
            } else {
                monogramView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .fixedSize()
        .accessibilityHidden(true)
    }

    @ViewBuilder private var monogramView: some View {
        ZStack {
            bgColor
            let borderUIColor = UIColor(bgColor).darker(by: 1) ?? UIColor(bgColor)
            let borderLineWidth = min(max(size * 0.04, 1), 1)
            Circle()
                .stroke(Color(borderUIColor), lineWidth: borderLineWidth)

            if avatarType == .single {
                let computedFontSize = monogramFontSize(for: size)
                Text(extractFirstGraphemeCluster(from: name))
                    .font(.system(size: computedFontSize, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                let iconFontSize = max((size * 0.40).rounded(), 6)
                let systemName = avatarType == .group ? "person.2.fill" : "person.fill"
                Image(systemName: systemName)
                    .font(.system(size: iconFontSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private func monogramFontSize(for avatarSize: CGFloat) -> CGFloat {
        let factor: CGFloat = 0.44
        let raw = avatarSize * factor
        return min(max(raw.rounded(), 8), 50)
    }

    private func extractFirstGraphemeCluster(from text: String?) -> String {
        guard let text = text, !text.isEmpty else { return "" }
        let firstGrapheme = String(text.prefix(1))
        return firstGrapheme.uppercased()
    }
}

struct AccountAvatarView: View {
    @ObservedObject var account: AccountViewModel
    let size: CGFloat

    var body: some View {
        UnifiedAvatarView(
            name: account.name,
            avatarType: account.avatarType,
            processedAvatar: account.processedAvatar,
            bgColor: account.bgColor,
            size: size
        )
    }
}

struct ConversationAvatarView: View {
    @ObservedObject var conversation: ConversationViewModel
    let size: CGFloat

    var body: some View {
        UnifiedAvatarView(
            name: conversation.name,
            avatarType: conversation.avatarType,
            processedAvatar: conversation.processedAvatar,
            bgColor: conversation.bgColor,
            size: size
        )
    }
}

// MARK: - Searchable Modifier
struct SearchableModifier: ViewModifier {
    @Binding var searchText: String

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .searchable(text: $searchText, prompt: L10n.ShareExtension.searchConversations)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(.tertiaryLabel))
                    TextField(L10n.ShareExtension.searchConversations, text: $searchText)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
                .overlay(
                    Capsule().stroke(Color(.quaternaryLabel), lineWidth: 1)
                )
                .padding()

                content
                Spacer()
            }
        }
    }
}

struct ShareExtensionAccessibilityIdentifiers {
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
    static let shareButton = "share_send_button"
    static let noConversationsView = "share_no_conversations_view"
    static let noSearchResultsView = "share_no_search_results_view"
}
