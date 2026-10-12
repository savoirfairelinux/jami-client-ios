/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import Combine
import Foundation
import SwiftUI
import RxRelay
import SwiftyBeaver

enum ContextMenuMode {
    case actions
    case reactions
    case editHistory
}

class ContextMenuVM: ObservableObject {

    private let log = SwiftyBeaver.self

    private(set) var presentingMessageView: MessageBubbleView?
    private(set) var contentVM: MessageContentVM?
    private(set) var containerModel: MessageContainerModel?

    var sendEmojiUpdate = BehaviorRelay(value: [String: String]())
    @Published private(set) var menuItems = [ContextualMenuItem]()
    @Published private(set) var messageDateText = ""
    @Published private(set) var mode: ContextMenuMode = .actions
    @Published private(set) var listEmptied = false
    @Published private(set) var pendingReactionRemovals = Set<String>()
    @Published private(set) var editHistory = [MessageVersion]()
    private(set) var avatarFactory: AvatarProviderFactory?
    private var reactionsSubscription: AnyCancellable?
    private var editHistorySubscription: AnyCancellable?

    func configure(with message: MessageBubbleView, mode: ContextMenuMode, localJamiId: String?, avatarFactory: AvatarProviderFactory) {
        self.currentJamiAccountId = localJamiId
        self.presentingMessageView = message
        self.contentVM = message.model
        self.containerModel = message.messageModel
        self.avatarFactory = avatarFactory
        self.mode = mode
        listEmptied = false
        pendingReactionRemovals = []
        reactionsSubscription = nil
        editHistorySubscription = nil
        if mode == .reactions {
            observeReactions(message.messageModel.reactionsModel)
        }
        editHistory = []
        if mode == .editHistory {
            observeEditHistory(message.model)
        }

        let incoming = message.model.message.incoming
        menuItems = message.model.menuItems
        messageDateText = message.model.fullDateText
        actionsAnchor = incoming ? .topLeading : .topTrailing
        messsageAnchor = incoming ? .bottomLeading : .bottomTrailing
        isOurMsg = !incoming
        preferencesColor = message.model.preferencesColor

        updateContextMenuSize()

        if let sender = currentJamiAccountId, let container = containerModel {
            myAuthoredReactionIds = container.message.reactionsMessageIdsBySender(jamiId: sender)
            let authoredContents = Set(
                container.reactionsModel.message.reactions
                    .filter { myAuthoredReactionIds.contains($0.id) }
                    .map(\.content)
            )
            uniqueAuthoredReactions = Array(authoredContents.subtracting(preferredUserReactions))
        }
    }

    var messageFrame: CGRect = .zero {
        didSet {
            updateSizes()
        }
    }

    private(set) var menuSize: CGSize = .zero {
        didSet {
            updateSizes()
        }
    }

    // MARK: - Layout constants (scaled for Dynamic Type)

    private static let bodyMetrics = UIFontMetrics(forTextStyle: .body)
    private static let title2Metrics = UIFontMetrics(forTextStyle: .title2)

    var itemHeight: CGFloat {
        Self.bodyMetrics.scaledValue(for: 42)
    }
    let menuPadding: CGFloat = 15
    let messageDateVerticalPadding: CGFloat = 10
    let menuCornerRadius: CGFloat = 14
    let defaultVerticalPadding: CGFloat = 6
    let maxScaleFactor: CGFloat = 1.1
    var emojiBarHeight: CGFloat {
        Self.title2Metrics.scaledValue(for: 68)
    }
    var menuImageSize: CGFloat {
        Self.bodyMetrics.scaledValue(for: 18)
    }

    private var minMenuWidth: CGFloat {
        Self.bodyMetrics.scaledValue(for: 220)
    }
    private var maxListHeight: CGFloat {
        Self.bodyMetrics.scaledValue(for: 330)
    }
    private var minListWidth: CGFloat {
        Self.bodyMetrics.scaledValue(for: 200)
    }
    private let screenPadding: CGFloat = 100
    private let menuBottomPadding: CGFloat = 80
    private let emojiBarHorizontalPadding: CGFloat = 20
    private let maxEmojiColumns: CGFloat = 5
    private var emojiColumnWidth: CGFloat {
        Self.title2Metrics.scaledValue(for: 62)
    }

    // MARK: - Computed / derived layout

    private(set) var bottomOffset: CGFloat = 0
    private(set) var menuOffsetX: CGFloat = 0
    private(set) var scaleMessageUp = true
    private(set) var actionsAnchor: UnitPoint = .center
    private(set) var messsageAnchor: UnitPoint = .center
    private(set) var messageHeight: CGFloat = 0 {
        didSet {
            isShortMsg = messageHeight < screenHeight / 4.0
        }
    }

    private(set) var emojiVerticalPadding: CGFloat = 6
    var emojiBarMaxWidth: CGFloat {
        return max(0, min(screenWidth - emojiBarHorizontalPadding, emojiColumnWidth * maxEmojiColumns))
    }
    let emojiBarHorizontalInset: CGFloat = 8

    var showsEmojiBar: Bool {
        mode != .editHistory
    }

    private(set) var isShortMsg: Bool = true
    private(set) var incomingMessageMarginSize: CGFloat = 58
    private(set) var outgoingMessageTrailingMargin: CGFloat = 10
    private(set) var isOurMsg: Bool = false
    private(set) var preferencesColor: UIColor = .systemBlue

    var shadowColor: UIColor {
        return UITraitCollection.current.userInterfaceStyle == .light
            ? UIColor.tertiaryLabel
            : UIColor.black.withAlphaComponent(0.8)
    }

    private(set) var currentJamiAccountId: String?
    private var myAuthoredReactionIds: [String] = []

    var screenWidth: CGFloat {
        return ScreenDimensionsManager.shared.adaptiveWidth
    }

    var screenHeight: CGFloat {
        return ScreenDimensionsManager.shared.adaptiveHeight
    }

    let preferredUserReactions: [String] = [
        0x1F44D, 0x1F44E, 0x1F606, 0x1F923, 0x1F615
    ].map { String(UnicodeScalar($0)!) }

    private(set) var uniqueAuthoredReactions: [String] = []
    @Published var selectedEmoji: String = ""
    @Published var isEmojiPickerPresented: Bool = false

    // MARK: - Size calculations

    private func updateContextMenuSize() {
        switch mode {
        case .reactions:
            updateReactionsListSize()
            return
        case .editHistory:
            updateEditHistorySize()
            return
        case .actions:
            break
        }
        let fontAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        let messageDateAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .footnote)]
        let messageDate = messageDateText as NSString
        var width = max(minMenuWidth, messageDate.size(withAttributes: messageDateAttributes).width + menuPadding * 2)
        for item in menuItems {
            let size = (item.toString() as NSString).size(withAttributes: fontAttributes)
            let newWidth = size.width + menuImageSize + menuPadding * 3
            if newWidth > width {
                width = newWidth
            }
        }
        let newWidth = min(width, screenWidth - screenPadding)
        let messageDateHeight = messageDate.boundingRect(with: CGSize(width: newWidth - menuPadding * 2, height: .greatestFiniteMagnitude),
                                                         options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                         attributes: messageDateAttributes,
                                                         context: nil).height
        let height = CGFloat(menuItems.count) * itemHeight + menuPadding * 2 + ceil(messageDateHeight) + messageDateVerticalPadding * 2
        let newHeight = min(height, screenHeight - screenPadding)
        menuSize = CGSize(width: newWidth, height: newHeight)
    }

    private func updateReactionsListSize() {
        let usesAccessibilitySize = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
        let rows = containerModel?.reactionsModel.reactionsRow ?? []
        var rowsHeight: CGFloat = 0
        var rowsWidth: CGFloat = 0
        for row in rows {
            let isLocal = row.jamiId == currentJamiAccountId
            let emojis = row.reactions.map(\.emoji)
            rowsHeight += ReactionRowView.height(count: emojis.count,
                                                 isLocal: isLocal,
                                                 usesAccessibilitySize: usesAccessibilitySize)
            rowsWidth = max(rowsWidth, ReactionRowView.idealWidth(name: isLocal ? row.username.withYourselfSuffix() : row.username,
                                                                  emojis: emojis,
                                                                  isLocal: isLocal,
                                                                  usesAccessibilitySize: usesAccessibilitySize))
        }
        let separatorsHeight = CGFloat(max(0, rows.count - 1)) / UIScreen.main.scale
        let height = min(rowsHeight + separatorsHeight, maxListHeight) + ReactionsView.verticalPadding * 2
        menuSize = CGSize(width: min(maxListWidth, max(minListWidth, rowsWidth)),
                          height: min(height, screenHeight - screenPadding))
    }

    private func updateEditHistorySize() {
        let idealWidth = editHistory.map { MessageVersionRow.idealWidth(of: $0) }.max() ?? 0
        let width = min(maxListWidth, max(minListWidth, idealWidth))
        let rowsHeight = editHistory.reduce(CGFloat(0)) { $0 + MessageVersionRow.height(of: $1, width: width) }
        let separatorsHeight = CGFloat(max(0, editHistory.count - 1)) / UIScreen.main.scale
        let height = min(rowsHeight + separatorsHeight, maxListHeight) + MessageEditHistoryView.verticalPadding * 2
        menuSize = CGSize(width: width, height: min(height, screenHeight - screenPadding))
    }

    private var maxListWidth: CGFloat {
        let placementInset = isOurMsg ? max(10, screenWidth - messageFrame.maxX) : messageFrame.minX
        let availableWidth = screenWidth - placementInset - emojiBarHorizontalPadding
        return min(emojiBarMaxWidth + emojiBarHorizontalInset * 2, availableWidth)
    }

    func showEditHistory() {
        guard let contentVM = contentVM else { return }
        mode = .editHistory
        observeEditHistory(contentVM)
        if editHistory.isEmpty {
            listEmptied = true
            return
        }
        updateContextMenuSize()
    }

    private func observeEditHistory(_ contentVM: MessageContentVM) {
        editHistory = Self.versions(of: contentVM)
        // @Published emits before the value is stored, so read the message on the next main-queue pass.
        editHistorySubscription = contentVM.$editions
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak contentVM] _ in
                guard let self = self, let contentVM = contentVM else { return }
                let versions = Self.versions(of: contentVM)
                if versions.isEmpty {
                    self.listEmptied = true
                } else if versions != self.editHistory {
                    self.editHistory = versions
                    self.updateEditHistorySize()
                }
            }
    }

    private static func versions(of message: MessageContentVM) -> [MessageVersion] {
        if message.messageDeleted { return [] }
        return MessageEditHistory.versions(current: message.content, editions: message.editions)
    }

    func observeReactions(_ reactions: ReactionsContainerModel) {
        // Rows are rebuilt one by one, so read the final state on the next main-queue pass.
        reactionsSubscription = reactions.$reactionsRow
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak reactions] _ in
                guard let self = self, let reactions = reactions else { return }
                if reactions.reactionsRow.isEmpty {
                    self.listEmptied = true
                } else {
                    self.objectWillChange.send()
                    self.updateReactionsListSize()
                }
            }
    }

    func stopObserving() {
        reactionsSubscription = nil
        editHistorySubscription = nil
    }

    private let minMessageDisplayHeight: CGFloat = 400

    private func updateSizes() {
        if messageFrame == .zero || menuSize == .zero { return }
        let screenHeight = self.screenHeight
        let navBarHeight = Self.statusBarHeight() + UINavigationController.navBarHeight()
        let messageOffsetY = messageFrame.origin.y
        let fittingHeight = screenHeight - (menuSize.height + navBarHeight + menuBottomPadding)
        // Guarantee at least minMessageDisplayHeight so the message stays visible
        // even when menu items take a lot of space. The outer ScrollView handles overflow.
        let maxMessageHeight = max(fittingHeight, minMessageDisplayHeight)
        messageHeight = min(maxMessageHeight, messageFrame.height)
        let diff = screenHeight - (messageOffsetY + menuSize.height + navBarHeight + messageFrame.height)
        let diffOffset = max(0, messageFrame.height - messageHeight)
        bottomOffset = diff < 0 ? diff + diffOffset : 0
        let isIncoming = containerModel?.message.incoming ?? false
        if isIncoming {
            menuOffsetX = 0
        } else {
            menuOffsetX = messageFrame.width - menuSize.width
        }
        let totalNeeded = messageFrame.height + navBarHeight + menuSize.height - screenHeight
        scaleMessageUp = totalNeeded <= 0
        if scaleMessageUp {
            let heightDiff = messageHeight * maxScaleFactor - messageHeight
            /*
             Because the messageAnchor for the scale is at the bottom,
             the message will expand upwards. Therefore, it is necessary
             to add scaled space.
             */
            emojiVerticalPadding = defaultVerticalPadding + heightDiff
        }
        // set the left margin for incoming messages when reactions are opened
        incomingMessageMarginSize = messageFrame.minX
        // set the right margin for outgoing messages to respect safe area in landscape
        outgoingMessageTrailingMargin = max(10, screenWidth - messageFrame.maxX)
    }

    private static func statusBarHeight() -> CGFloat {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            return scene.statusBarManager?.statusBarFrame.height ?? 0
        }
        return 0
    }

    // MARK: - Reaction handling

    func sendReaction(value: String) {
        guard let container = containerModel else { return }
        sendEmojiUpdate.accept([
            "messageId": container.id,
            "author": container.message.authorId,
            "data": value,
            "action": ReactionCommand.apply.toString()
        ])
    }

    func removeReaction(id: String) {
        guard pendingReactionRemovals.insert(id).inserted else { return }
        sendEmojiUpdate.accept(["reactionId": id, "action": ReactionCommand.revoke.toString()])
    }

    func handleUpdatedReaction() {
        guard let container = containerModel, let author = currentJamiAccountId else {
            log.error("[ContextMenu] Failed to update reaction on invalid presented message or Jami Id.")
            return
        }
        if let reactionMsg = getAuthoredReaction(withValue: selectedEmoji) {
            log.debug("[ContextMenu] Revoking reaction \(reactionMsg.content) for \(reactionMsg.author)")
            removeReaction(id: reactionMsg.id)
        } else {
            log.debug("[ContextMenu] Applying reaction \(selectedEmoji) for \(author)")
            sendEmojiUpdate.accept([
                "parentMessageId": container.id,
                "author": author,
                "data": selectedEmoji,
                "action": ReactionCommand.apply.toString()
            ])
        }
    }

    func localUserAuthoredReaction(emoji: String) -> Bool {
        guard let sender = currentJamiAccountId, let container = containerModel else {
            log.error("[ContextMenu] Jami account ID invalid while attempting to read message reactions.")
            return false
        }
        return container.message.reactions.contains {
            $0.author == sender && $0.content == emoji && !pendingReactionRemovals.contains($0.id)
        }
    }

    private func getAuthoredReaction(withValue: String) -> MessageAction? {
        guard let sender = currentJamiAccountId, let container = containerModel else {
            log.error("[ContextMenu] Jami account ID invalid while attempting to read message reactions.")
            return nil
        }
        return container.message.reactions.first {
            $0.author == sender && $0.content == withValue && !pendingReactionRemovals.contains($0.id)
        }
    }
}

enum ReactionCommand {
    case apply
    case revoke

    func toString() -> String {
        switch self {
        case .apply:
            return "apply"
        case .revoke:
            return "revoke"
        }
    }
}
