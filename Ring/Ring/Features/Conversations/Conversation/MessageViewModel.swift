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
import SwiftyBeaver

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
    case receivedContactRequest = "Contact request received"
    case contactAdded = "Contact added"
    case missedIncomingCall = "Missed incoming call"
    case missedOutgoingCall = "Missed outgoing call"
    case incomingCall = "Incoming call"
    case outgoingCall = "Outgoing call"
}

class MessageViewModel {

    fileprivate let log = SwiftyBeaver.self

    fileprivate let accountService: AccountsService
    fileprivate let conversationsService: ConversationsService
    fileprivate var message: MessageModel

    var timeStringShown: String?
    var sequencing: MessageSequencing = .unknown

    private let disposeBag = DisposeBag()

    init(withInjectionBag injectionBag: InjectionBag,
         withMessage message: MessageModel) {
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.message = message
        self.timeStringShown = nil
        self.status.onNext(message.status)

        // subscribe to message status updates for outgoing messages
        self.conversationsService
            .sharedResponseStream
            .filter({ messageUpdateEvent in
                let account = self.accountService.getAccount(fromAccountId: messageUpdateEvent.getEventInput(.id)!)
                let accountHelper = AccountModelHelper(withAccount: account!)
                return messageUpdateEvent.eventType == ServiceEventType.messageStateChanged &&
                    messageUpdateEvent.getEventInput(.messageId) == self.message.daemonId &&
                    accountHelper.ringId == self.message.author
            })
            .subscribe(onNext: { [unowned self] messageUpdateEvent in
                if let status: MessageStatus = messageUpdateEvent.getEventInput(.messageStatus) {
                    self.status.onNext(status)
                }
            })
            .disposed(by: self.disposeBag)
    }

    var content: String {
        return self.message.content
    }

    var receivedDate: Date {
        return self.message.receivedDate
    }

    var id: UInt64 {
        return UInt64(self.message.daemonId)!
    }

    var status = BehaviorSubject<MessageStatus>(value: .unknown)

    func bubblePosition() -> BubblePosition {
        if self.message.isGenerated {
            return .generated
        }

        if self.message.incoming {
            return.received
        } else {
            return .sent
        }
    }
}
