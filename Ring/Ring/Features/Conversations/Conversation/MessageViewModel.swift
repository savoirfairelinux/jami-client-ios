/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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
    case sendContactRequest = "The invitation has been sent"
    case receivedContactRequest = "Contact request received"
    case contactRequestAccepted = "Contact accepted"
}

final class MessageViewModel {

    private let log = SwiftyBeaver.self

    private let accountService: NewAccountsService
    private let conversationsService: ConversationsService
    private var message: MessageModel
    private let ringId: String

    var timeStringShown: String?
    var sequencing: MessageSequencing = .unknown

    private let disposeBag = DisposeBag()

    init(withInjectionBag injectionBag: InjectionBag, withMessage message: MessageModel, ringId: String) {
        self.accountService = injectionBag.newAccountsService
        self.conversationsService = injectionBag.conversationsService
        self.message = message
        self.timeStringShown = nil
        self.status.onNext(message.status)
        self.ringId = ringId

        self.conversationsService.sharedResponseStream
            .filter { [weak self] (messageUpdateEvent) -> Bool in
                return messageUpdateEvent.eventType == ServiceEventType.messageStateChanged &&
                    messageUpdateEvent.getEventInput(.messageId) == self?.message.id
            }
            .subscribe(onNext: { [weak self] (messageUpdateEvent) in
                if let status: MessageStatus = messageUpdateEvent.getEventInput(.messageStatus) {
                    self?.status.onNext(status)
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
        return UInt64(self.message.id)!
    }

    var status = BehaviorSubject<MessageStatus>(value: .unknown)

    func bubblePosition() -> BubblePosition {
        if self.message.isGenerated {
            return .generated
        }

        if self.message.author == self.ringId {
            return .sent
        } else {
            return.received
        }
    }
}
