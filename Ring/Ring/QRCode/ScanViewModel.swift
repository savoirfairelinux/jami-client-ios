//
//  ScanViewModel.swift
//  Ring
//
//  Created by Quentin on 2018-09-21.
//  Copyright © 2018 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift

class ScanViewModel: ViewModel, Stateable {

    // MARK: variables
    private var injectionBag: InjectionBag
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
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
        let accountHelper = AccountModelHelper(withAccount: currentAccount)
        //Create new converation
        let conversation = ConversationModel(withRecipientRingId: recipientRingId, accountId: currentAccount.id, accountUri: accountHelper.ringId!)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = Variable<ConversationModel>(conversation)
        self.showConversation(withConversationViewModel: newConversation)
    }

    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
            conversationViewModel))
    }
}
