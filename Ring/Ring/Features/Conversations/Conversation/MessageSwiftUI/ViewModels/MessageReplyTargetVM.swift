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

import Combine
import Foundation
import RxSwift
import SwiftUI

class MessageReplyTargetVM: ObservableObject, MessageAppearanceProtocol, AvatarImageObserver,
                            NameObserver {
    @Published var username: String = "" {
        didSet {
            updateInReplyMessage()
        }
    }

    var styling: MessageStyling = .init()

    @Published var avatarImage: UIImage?
    @Published var inReplyTo = ""

    let imageMaxHeight: CGFloat = 100
    let imageMinHeight: CGFloat = 20
    let sizeIndex: CGFloat = 0.5

    var targetReplyUsername = ""
    var localJamiId: String
    var replyAuthorJamiId: String
    var infoState: PublishSubject<State>?

    var alignment: HorizontalAlignment = .center

    var isIncoming: Bool

    var disposeBag = DisposeBag()

    var target: MessageContentVM? {
        didSet {
            if target != nil {
                subscription = target!.$username.sink { [weak self] newValue in
                    self?.targetReplyUsername = newValue
                    self?.updateInReplyMessage()
                }
                target!.updateUserName()
                updateUsernameForReply()
                updateInReplyMessage()
            }
        }
    }

    var subscription: AnyCancellable?

    var contextMenuState: PublishSubject<State>

    init(
        contextMenuState: PublishSubject<State>,
        localJamiId: String,
        replyAuthorJamiId: String,
        isIncoming: Bool
    ) {
        self.localJamiId = localJamiId
        self.replyAuthorJamiId = replyAuthorJamiId
        self.isIncoming = isIncoming
        alignment = isIncoming ? .leading : .trailing
        self.contextMenuState = contextMenuState
    }

    func setInfoState(state: PublishSubject<State>) {
        infoState = state
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
        requestName(jamiId: replyAuthorJamiId)
    }

    private func getInReplyMessage() -> String {
        let inReplyToSelf = L10n.Conversation.inReplyTo + " \(L10n.Account.me)"
        let inReplyToOther = L10n.Conversation.inReplyTo + " \(targetReplyUsername)"
        let repliedByOtherToSelf = "\(username) " + L10n.Conversation
            .repliedTo + " \(L10n.Account.me)"
        let repliedByOtherToOther = "\(username) " + L10n.Conversation
            .repliedTo + " \(targetReplyUsername)"

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
            contextMenuState.onNext(ContextMenu.scrollToReplyTarget(messageId: target.message.id))
        }
    }
}
