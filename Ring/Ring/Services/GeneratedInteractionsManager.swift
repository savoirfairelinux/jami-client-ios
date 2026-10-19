/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import RxSwift

/*
 This class generates interactions for call events. Only for SIP conversations
 */

class GeneratedInteractionsManager {
    let accountService: AccountsService
    let conversationService: ConversationsService
    let callService: CallService
    let disposeBag = DisposeBag()

    init(accountService: AccountsService, conversationService: ConversationsService, callService: CallService) {
        self.accountService = accountService
        self.conversationService = conversationService
        self.callService = callService
        self.subscribeToCallEvents()
    }

    private func subscribeToCallEvents() {
        self.callService
            .sharedResponseStream
            .subscribe(onNext: { [weak self] callEvent in
                guard let self = self else { return }
                if self.accountService.boothMode() {
                    return
                }
                guard let accountID: String = callEvent.getEventInput(.accountId) else {
                    return
                }

                guard let jamiId: String = callEvent.getEventInput(.peerUri) else {
                    return
                }

                guard let account = self.accountService.getAccount(fromAccountId: accountID),
                      account.type == .sip,
                      let uri = JamiURI.init(schema: .sip, infoHash: jamiId, account: account).uriString else {
                    return
                }
                self.conversationService.createSipConversation(uri: uri, accountId: accountID)

                guard let time: Int = callEvent.getEventInput(.callTime) else {
                    return
                }

                guard let callType: Int = callEvent.getEventInput(.callType) else {
                    return
                }

                var shouldUpdateConversations = false
                if let currentAccount = self.accountService.currentAccount,
                   currentAccount.id == account.id {
                    shouldUpdateConversations = true
                }
                let message = callType == CallType.incoming.rawValue
                    ? (time > 0) ? GeneratedMessage.incomingCall.toString() : GeneratedMessage.missedIncomingCall.toString() :
                    (time > 0) ? GeneratedMessage.outgoingCall.toString() :
                    GeneratedMessage.missedOutgoingCall.toString()
                self.conversationService
                    .generateMessage(messageContent: message,
                                     duration: Int64(time),
                                     contactUri: uri,
                                     accountId: account.id,
                                     date: Date(),
                                     interactionType: InteractionType.call,
                                     shouldUpdateConversation: shouldUpdateConversations)

            })
            .disposed(by: disposeBag)
    }
}
