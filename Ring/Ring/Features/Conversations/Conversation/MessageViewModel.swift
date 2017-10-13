/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

import RxSwift

enum BubblePosition {
    case received
    case sent
    case generated
}

enum MessageSequencing {
    case singleMessage
    case firstOfSequence
    case lastOfSequence
    case middleOfSequence
    case unknown
}

enum GeneratedMessageType: String {
    case sendContactRequest = "The invitation has been sent"
    case receivedContactRequest = "Contact request received"
    case contactRequestAccepted = "ACCEPTED"
}

class MessageViewModel {

    fileprivate let accountService: AccountsService
    fileprivate var message: MessageModel

    var timeStringShown: String?
    var sequencing: MessageSequencing = .unknown

    init(withInjectionBag injectionBag: InjectionBag,
         withMessage message: MessageModel) {
        self.accountService = injectionBag.accountService
        self.message = message
        self.timeStringShown = nil
    }

    var content: String {
        return self.message.content
    }

    var receivedDate: Date {
        return self.message.receivedDate
    }

    var id: Int64 {
        return self.message.id
    }

    var status: MessageStatus {
        return self.message.status
    }

    func bubblePosition() -> BubblePosition {
        if self.message.isGenerated {
            return .generated
        }
        let accountHelper = AccountModelHelper(withAccount: accountService.currentAccount!)

        if self.message.author == accountHelper.ringId! {
            return .sent
        } else {
            return.received
        }
    }
}
