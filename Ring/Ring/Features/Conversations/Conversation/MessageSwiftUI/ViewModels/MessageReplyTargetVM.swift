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

class MessageReplyTargetVM {

    @Published var avatarImage: UIImage?

    @Published var inReplyTo = ""
    var username = "" {
        didSet {
            if !username.isEmpty {
                updateInReplyMessage()
            }
        }
    }

    var replyUserName = "" {
        didSet {
            if !replyUserName.isEmpty {
                updateInReplyMessage()
            }
        }
    }

    var infoState: PublishSubject<State>

    var localJamiId: String

    var replyAuthorJamiId: String

    init(infoState: PublishSubject<State>, localJamiId: String, replyAuthorJamiId: String) {
        self.infoState = infoState
        self.localJamiId = localJamiId
        self.replyAuthorJamiId = replyAuthorJamiId
    }

    var target: MessageContentVM? {
        didSet {
            if let target = target {
                let jamiId = target.message.authorId
                if jamiId != localJamiId {
                    self.infoState.onNext(MessageInfo.updateAvatar(jamiId: jamiId))
                    self.infoState.onNext(MessageInfo.updateDisplayname(jamiId: jamiId))
                } else {
                    updateInReplyMessage()
                }

                if replyAuthorJamiId != localJamiId {
                    self.infoState.onNext(MessageInfo.updateAvatar(jamiId: replyAuthorJamiId))
                    self.infoState.onNext(MessageInfo.updateDisplayname(jamiId: replyAuthorJamiId))
                } else {
                    updateInReplyMessage()
                }
            }
        }
    }

    func updateInReplyMessage() {
        guard let target = self.target else { return }
        if localJamiId == replyAuthorJamiId {
            inReplyTo = L10n.Conversation.inReplyTo + " \(username)"
        } else if localJamiId == target.message.authorId {
            inReplyTo = "\(replyUserName) " + L10n.Conversation.repliedTo + " \(L10n.Account.me)"
        } else {
            inReplyTo = "\(replyUserName) " + L10n.Conversation.repliedTo + " \(username)"
        }
    }

}
