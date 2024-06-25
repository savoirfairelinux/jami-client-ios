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
import RxRelay
import SwiftUI
import SwiftyBeaver

class ContextMenuVM: ObservableObject {
    private let log = SwiftyBeaver.self

    var sendEmojiUpdate = BehaviorRelay(value: [String: String]())
    @Published var menuItems = [ContextualMenuItem]()
    var presentingMessage: MessageBubbleView! {
        didSet {
            menuItems = presentingMessage.model.menuItems
            actionsAnchor = presentingMessage.model.message.incoming ? .topLeading : .topTrailing
            messsageAnchor = presentingMessage.model.message
                .incoming ? .bottomLeading : .bottomTrailing
            updateContextMenuSize()
            isOurMsg = !presentingMessage.model.message.incoming
            myAuthoredReactionIds = presentingMessage.messageModel.message
                .reactionsMessageIdsBySender(jamiId: currentJamiAccountId!)
            uniqueAuthoredReactions =
                Array(Set(presentingMessage.messageModel.reactionsModel.message.reactions
                            .filter { item in myAuthoredReactionIds.contains(item.id) }
                            .map { item in item.content }).subtracting(preferredUserReactions))
        }
    }

    var messageFrame: CGRect = .zero {
        didSet {
            updateSizes()
        }
    }

    var menuSize: CGSize = .zero {
        didSet {
            updateSizes()
        }
    }

    let itemHeight: CGFloat = 42
    let menuPadding: CGFloat = 15
    let minWidth: CGFloat = 220
    let menuImageSize: CGFloat = 18
    let menuItemFont = Font.callout
    let screenPadding: CGFloat = 100
    let menuCornerRadius: CGFloat = 3
    let defaultVerticalPadding: CGFloat = 6
    let maxScaleFactor: CGFloat = 1.1
    var bottomOffset: CGFloat = 0 // move message up
    var menuOffsetX: CGFloat = 0
    var menuOffsetY: CGFloat = 0
    var scaleMessageUp = true
    var actionsAnchor: UnitPoint = .center
    var messsageAnchor: UnitPoint = .center
    var messageHeight: CGFloat = 0 {
        didSet {
            isShortMsg = messageHeight < screenHeight / 4.0
        }
    }

    // TODO: remove this var and just use emojiBarHeight
    var emojiVerticalPadding: CGFloat = 6
    var emojiBarHeight: CGFloat = 68
    var emojiBarMaxWidth: CGFloat = max(0, min(screenWidth - 20, 62 * 5))

    var isShortMsg: Bool = true
    var incomingMessageMarginSize: CGFloat = 58
    var isOurMsg: Bool?

    var shadowColor: UIColor {
        return UITraitCollection.current.userInterfaceStyle == .light ? UIColor
            .tertiaryLabel : UIColor.black.withAlphaComponent(0.8)
    }

    var currentJamiAccountId: String?
    var myAuthoredReactionIds: [String] =
        [] // list of MessageIds for local user's authored reactions
    var preferredUserReactions: [String] = [
        0x1F44D, 0x1F44E, 0x1F606, 0x1F923, 0x1F615
    ].map { String(UnicodeScalar($0)!) }
    var uniqueAuthoredReactions: [String] =
        [] // a list of emojis (excluding defaults) that can be revoked via tap in emojibar
    @Published var selectedEmoji: String = ""
    @Published var isEmojiPickerPresented: Bool = false

    func updateContextMenuSize() {
        let height = CGFloat(menuItems.count) * itemHeight + menuPadding * 2
        let fontAttributes =
            [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout)]
        var width = minWidth
        for item in menuItems {
            let size = (item.toString() as NSString).size(withAttributes: fontAttributes)
            let newWidth: CGFloat = size.width + menuImageSize + menuPadding * 3
            if newWidth > width {
                width = newWidth
            }
        }
        let newHeight: CGFloat = min(height, UIScreen.main.bounds.height - screenPadding)
        let newWidth: CGFloat = min(width, UIScreen.main.bounds.width - screenPadding)
        menuSize = CGSize(width: newWidth, height: newHeight)
    }

    func updateSizes() {
        if messageFrame == CGRect.zero || menuSize == CGSize.zero { return }
        let screenHeight = UIScreen.main.bounds.height
        let navBarHeight = UINavigationController
            .navBarHeight() +
            (UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame
                .height ?? 0)
        let messageOffsetY = messageFrame.origin.y
        let maxMessageHeight = screenHeight - (menuSize.height + navBarHeight + 80)
        messageHeight = min(maxMessageHeight, messageFrame.height)
        let diff = screenHeight -
            (messageOffsetY + menuSize.height + navBarHeight + messageFrame.height)
        let diffOffset = max(0, messageFrame.height - messageHeight)
        bottomOffset = diff < 0 ? diff + diffOffset : 0
        if presentingMessage.messageModel.message.incoming {
            menuOffsetX = 0
        } else {
            menuOffsetX = messageFrame.width - menuSize.width
        }
        let difff = messageFrame.height + navBarHeight + menuSize.height - screenHeight
        scaleMessageUp = difff <= 0
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

    func sendReaction(value: String) {
        if let msg = presentingMessage {
            sendEmojiUpdate.accept([
                "messageId": msg.messageModel.id,
                "author": msg.messageModel.message.authorId,
                "data": value,
                "action": ReactionCommand.apply.toString()
            ])
        }
    }

    func handleUpdatedReaction() {
        if let msg = presentingMessage, let author = currentJamiAccountId {
            if let reactionMsg = getAuthoredReaction(withValue: selectedEmoji) {
                // revoke reaction
                log
                    .debug(
                        "[ContextMenu] Revoking reaction \(reactionMsg.content) for \(reactionMsg.author)"
                    )
                sendEmojiUpdate.accept([
                    "reactionId": reactionMsg.id,
                    "action": ReactionCommand.revoke.toString()
                ])
            } else { // add reaction
                log.debug("[ContextMenu] Applying reaction \(selectedEmoji) for \(author)")
                sendEmojiUpdate.accept([
                    "parentMessageId": msg.messageModel.id,
                    "author": author,
                    "data": selectedEmoji,
                    "action": ReactionCommand.apply.toString()
                ])
            }
        } else {
            log
                .error(
                    "[ContextMenu] Failed to update reaction on invalid presented message or Jami Id."
                )
        }
    }

    func localUserAuthoredReaction(emoji: String) -> Bool {
        if let sender = currentJamiAccountId {
            if let _ = presentingMessage.messageModel.message.reactions
                .first(where: { item in item.author == sender && item.content == emoji }) {
                return true
            } else {
                return false
            }
        } else {
            log
                .error(
                    "[ContextMenu] Jami account ID invaled while trying to read message reactions."
                )
            return false
        }
    }

    func getAuthoredReaction(withValue: String) -> MessageAction? {
        if let sender = currentJamiAccountId {
            return presentingMessage.messageModel.message.reactions
                .first(where: { item in item.author == sender && item.content == withValue })
        } else {
            log
                .error(
                    "[ContextMenu] Jami account ID invaled while trying to read message reactions."
                )
            return nil
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
