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

import Foundation
import SwiftUI
import RxRelay
import SwiftyBeaver

class ContextMenuVM: ObservableObject {

    private let log = SwiftyBeaver.self

    private(set) var presentingMessageView: MessageBubbleView?
    private(set) var contentVM: MessageContentVM?
    private(set) var containerModel: MessageContainerModel?

    var sendEmojiUpdate = BehaviorRelay(value: [String: String]())
    @Published private(set) var menuItems = [ContextualMenuItem]()

    func configure(with message: MessageBubbleView) {
        self.presentingMessageView = message
        self.contentVM = message.model
        self.containerModel = message.messageModel

        let incoming = message.model.message.incoming
        menuItems = message.model.menuItems
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

    // MARK: - Layout constants

    let itemHeight: CGFloat = 42
    let menuPadding: CGFloat = 15
    let menuCornerRadius: CGFloat = 14
    let defaultVerticalPadding: CGFloat = 6
    let maxScaleFactor: CGFloat = 1.1
    let emojiBarHeight: CGFloat = 68
    let menuImageSize: CGFloat = 18

    private let minMenuWidth: CGFloat = 220
    private let screenPadding: CGFloat = 100
    private let menuBottomPadding: CGFloat = 80
    private let outgoingMessageTrailingMargin: CGFloat = 10
    private let emojiBarHorizontalPadding: CGFloat = 20
    private let maxEmojiColumns: CGFloat = 5
    private let emojiColumnWidth: CGFloat = 62

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

    private(set) var isShortMsg: Bool = true
    private(set) var incomingMessageMarginSize: CGFloat = 58
    private(set) var isOurMsg: Bool = false
    private(set) var preferencesColor: UIColor = .systemBlue

    var shadowColor: UIColor {
        return UITraitCollection.current.userInterfaceStyle == .light
            ? UIColor.tertiaryLabel
            : UIColor.black.withAlphaComponent(0.8)
    }

    var currentJamiAccountId: String?
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
        let height = CGFloat(menuItems.count) * itemHeight + menuPadding * 2
        let fontAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout)]
        var width = minMenuWidth
        for item in menuItems {
            let size = (item.toString() as NSString).size(withAttributes: fontAttributes)
            let newWidth = size.width + menuImageSize + menuPadding * 3
            if newWidth > width {
                width = newWidth
            }
        }
        let newHeight = min(height, screenHeight - screenPadding)
        let newWidth = min(width, screenWidth - screenPadding)
        menuSize = CGSize(width: newWidth, height: newHeight)
    }

    private func updateSizes() {
        if messageFrame == .zero || menuSize == .zero { return }
        let screenHeight = self.screenHeight
        let navBarHeight = Self.statusBarHeight() + UINavigationController.navBarHeight()
        let messageOffsetY = messageFrame.origin.y
        let maxMessageHeight = screenHeight - (menuSize.height + navBarHeight + menuBottomPadding)
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

    func handleUpdatedReaction() {
        guard let container = containerModel, let author = currentJamiAccountId else {
            log.error("[ContextMenu] Failed to update reaction on invalid presented message or Jami Id.")
            return
        }
        if let reactionMsg = getAuthoredReaction(withValue: selectedEmoji) {
            log.debug("[ContextMenu] Revoking reaction \(reactionMsg.content) for \(reactionMsg.author)")
            sendEmojiUpdate.accept(["reactionId": reactionMsg.id, "action": ReactionCommand.revoke.toString()])
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
        return container.message.reactions.contains { $0.author == sender && $0.content == emoji }
    }

    private func getAuthoredReaction(withValue: String) -> MessageAction? {
        guard let sender = currentJamiAccountId, let container = containerModel else {
            log.error("[ContextMenu] Jami account ID invalid while attempting to read message reactions.")
            return nil
        }
        return container.message.reactions.first { $0.author == sender && $0.content == withValue }
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
