/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
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

import UIKit
import RxSwift
import RxCocoa

class ScanViewModel: ViewModel, Stateable {

    // MARK: variables
    private var injectionBag: InjectionBag
    private let stateSubject = PublishSubject<State1>()
    lazy var state: Observable<State1> = {
        return self.stateSubject.asObservable()
    }()

    // MARK: functions
    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
    }

    func createNewConversation(recipientRingId: String) {
        guard let currentAccount = self.injectionBag.accountService.currentAccount else {
            return
        }
        // Create new converation
        let conversation = ConversationModel(withParticipantUri: JamiURI.init(schema: URIType.ring,
                                                                              infoHach: recipientRingId),
                                             accountId: currentAccount.id)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        self.showConversation(withConversationViewModel: newConversation)
    }

    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
                                                                        conversationViewModel))
    }
}
