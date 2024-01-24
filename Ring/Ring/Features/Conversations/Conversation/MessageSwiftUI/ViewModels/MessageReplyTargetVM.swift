/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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
import RxSwift

class MessageReplyTargetVM: ObservableObject {

    @Published var avatarImage: UIImage?
    @Published var inReplyTo = ""

    let imageMaxHeight: CGFloat = 100
    let imageMinHeight: CGFloat = 20
    let sizeIndex: CGFloat = 0.5

    var targetReplyUsername = ""
    var replyUserName = ""
    var localJamiId: String
    var replyAuthorJamiId: String
    var infoState: PublishSubject<State>

    var alignment: HorizontalAlignment = .center

    var isIncoming: Bool

    var target: MessageContentVM? {
        didSet {
            if target != nil {
                updateUsernameForTargetReply()
                updateUsernameForReply()
                updateInReplyMessage()
            }
        }
    }

    var contextMenuState: PublishSubject<State>

    init(infoState: PublishSubject<State>, contextMenuState: PublishSubject<State>, localJamiId: String, replyAuthorJamiId: String, isIncoming: Bool) {
        self.infoState = infoState
        self.localJamiId = localJamiId
        self.replyAuthorJamiId = replyAuthorJamiId
        self.isIncoming = isIncoming
        self.alignment = isIncoming ? .leading : .trailing
        self.contextMenuState = contextMenuState
    }

    func updateUsername(name: String, jamiId: String) {
        guard let target = self.target, !name.isEmpty else { return }
        if target.message.authorId == jamiId {
            targetReplyUsername = name
        }
        if replyAuthorJamiId == jamiId {
            replyUserName = name
        }
        updateInReplyMessage()
    }

    private func replyIsIncoming() -> Bool {
        return replyAuthorJamiId == localJamiId || replyAuthorJamiId.isEmpty
    }

    private func targetReplyIsIncoming() -> Bool {
        guard let target = target else { return false }
        let jamiId = target.message.authorId
        return jamiId == localJamiId || jamiId.isEmpty
    }

    private func updateUsernameForReply() {
        if replyIsIncoming() { return }
        self.infoState.onNext(MessageInfo.updateDisplayname(jamiId: replyAuthorJamiId))
    }

    private func updateUsernameForTargetReply() {
        guard let target = target, !targetReplyIsIncoming() else { return }
        let jamiId = target.message.authorId
        self.infoState.onNext(MessageInfo.updateDisplayname(jamiId: jamiId))
    }

    private func getInReplyMessage() -> String {
        let inReplyToSelf = L10n.Conversation.inReplyTo + " \(L10n.Account.me)"
        let inReplyToOther = L10n.Conversation.inReplyTo + " \(targetReplyUsername)"
        let repliedByOtherToSelf = "\(replyUserName) " + L10n.Conversation.repliedTo + " \(L10n.Account.me)"
        let repliedByOtherToOther = "\(replyUserName) " + L10n.Conversation.repliedTo + " \(targetReplyUsername)"

        switch (replyIsIncoming(), targetReplyIsIncoming()) {
        case (true, true):
            return inReplyToSelf
        case (true, false):
            return inReplyToOther
        case (false, true):
            return repliedByOtherToSelf
        case (false, false):
            return repliedByOtherToOther
        }
    }

    private func updateInReplyMessage() {
        inReplyTo = getInReplyMessage()
    }

    func scrollToReplyTarget() {
        if let target = target {
            self.contextMenuState.onNext(ContextMenu.scrollToReplyTarget(messageId: target.message.id))
        }
    }
}
