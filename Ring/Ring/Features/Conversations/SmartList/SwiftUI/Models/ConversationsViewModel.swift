//
//  ConversationsViewModel.swift
//  Ring
//
//  Created by kateryna on 2024-03-19.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI
import RxSwift


class ConversationsViewModel: ObservableObject {
    @Published var conversations = [ConversationViewModel]()
    @Published var selectedSegment = 0
    @Published var unreadMessages = 0
    @Published var unreadRequests = 0
    var disposeBag = DisposeBag()
    let conversationsService: ConversationsService
    let requestsService: RequestsService
    let accountsService: AccountsService
    let stateSubject: PublishSubject<State>


    init(injectionBag: InjectionBag, stateSubject: PublishSubject<State>) {
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.accountsService = injectionBag.accountService
        self.stateSubject = stateSubject
    }

    func subscribe(conversations: Observable<[ConversationViewModel]>) {
        conversations
            .subscribe(onNext: { [weak self] conv in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.conversations = conv
                }
            })
            .disposed(by: self.disposeBag)
        conversationsService.conversations
            .share()
            .flatMap { conversations -> Observable<[Int]> in
                return Observable.combineLatest(conversations.map({ $0.numberOfUnreadMessages }))
            }
            .map { unreadMessages in
                return unreadMessages.reduce(0, +)
            }
            .subscribe(onNext: { [weak self] number in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.unreadMessages = number
                }
            })
            .disposed(by: self.disposeBag)

        let requestObservable = self.requestsService.requests.asObservable()

        let conversationObservable = self.conversationsService
            .conversations
            .share()
            .startWith(self.conversationsService.conversations.value)

        let unhandeledRequests = Observable.combineLatest(requestObservable,
                                                          conversationObservable) { [weak self] (requests, conversations) -> Int in
            guard let self = self,
                  let account = self.accountsService.currentAccount else {
                return 0
            }
            let accountId = account.id
            // filter out existing conversations
            let conversationIds = conversations.map { $0.id }
            let filteredRequests = requests.filter {
                $0.accountId == accountId && !conversationIds.contains($0.conversationId)
            }
            return filteredRequests.count
        }

        unhandeledRequests
            .subscribe(onNext: { [weak self] number in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.unreadRequests = number
                }
            })
            .disposed(by: self.disposeBag)
    }

    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
                                                                        conversationViewModel))
    }


    func newMessage() {
        self.stateSubject.onNext(ConversationState.presentNewMessage)
    }

    func openSettings() {
        self.stateSubject.onNext(ConversationState.showAccountSettings)
    }

    func openRequests() {
        self.stateSubject.onNext(ConversationState.presentRequestsController)
    }
}
