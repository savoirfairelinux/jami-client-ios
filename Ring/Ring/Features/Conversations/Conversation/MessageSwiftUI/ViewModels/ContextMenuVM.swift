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

class ContextMenuVM {
    var sendEmojiUpdate = BehaviorRelay(value: [String: String]())
    @Published var menuItems = [ContextualMenuItem]()
    var presentingMessage: MessageBubbleView! {
        didSet {
            menuItems = presentingMessage.model.menuItems
            actionsAnchor = presentingMessage.model.message.incoming ? .topLeading : .topTrailing
            messsageAnchor = presentingMessage.model.message.incoming ? .bottomLeading : .bottomTrailing
            updateContextMenuSize()
            isOurMsg = !presentingMessage.model.message.incoming
        }
    }
    var messageFrame: CGRect = CGRect.zero {
        didSet {
            updateSizes()
        }
    }

    var menuSize: CGSize = CGSize.zero {
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
    var emojiVerticalPadding: CGFloat = 6

    var emojiBarHeight: CGFloat = 68
    var isShortMsg: Bool = true
    var incomingMessageMarginSize: CGFloat = 58
    var isOurMsg: Bool?

    var shadowColor: UIColor {
        return UITraitCollection.current.userInterfaceStyle == .light ? UIColor.tertiaryLabel : UIColor.black.withAlphaComponent(0.8)
    }

    var currentJamiAccountId: String? = nil

    func updateContextMenuSize() {
        let height: CGFloat = CGFloat(menuItems.count) * itemHeight + menuPadding * 2
        let fontAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout)]
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
        let navBarHeight = UINavigationController.navBarHeight() + ( UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0)
        let messageOffsetY = messageFrame.origin.y
        let maxMessageHeight = screenHeight - (menuSize.height + navBarHeight + 80)
        messageHeight = min(maxMessageHeight, messageFrame.height)
        let diff = screenHeight - (messageOffsetY + menuSize.height + navBarHeight + messageFrame.height)
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
        if let msg = self.presentingMessage {
            self.sendEmojiUpdate.accept(["messageId":msg.messageModel.id,"author":msg.messageModel.message.authorId,"data":value,"action":"apply"])
        }
    }
   
    func revokeReaction(value: String, reactionId: String) {
        if let msg = self.presentingMessage {
            self.sendEmojiUpdate.accept(["reactionId":reactionId,"author":msg.messageModel.message.authorId,"data":value,"action":"revoke"])
        }
    }

    func localUserAuthoredReaction(emoji: String) -> Bool {
        if let sender = self.currentJamiAccountId, let message: MessageAction = self.presentingMessage.messageModel.message.reactions.first(where: { item in item.author == sender && item.content == emoji }) {
            return true
        }
        return false
    }

    func containsEmojiReaction(emoji: String) -> Bool {
        return presentingMessage.messageModel.reactionsModel.displayValue.containsCaseInsensitive(string: emoji)
    }
}
