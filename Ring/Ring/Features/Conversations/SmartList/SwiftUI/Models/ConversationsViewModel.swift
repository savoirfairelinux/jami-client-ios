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
import RxRelay

class ConversationsViewModel: ObservableObject, FilterConversationDataSource {
    // filtered conversations to display
    @Published var conversations = [ConversationViewModel]()
    // temporary conversation for jami or sip
    @Published var temporaryConversation: ConversationViewModel?
    // jams search  result
    @Published var jamsSearchResult = [ConversationViewModel]()
    // all conversations
    var conversationViewModels = [ConversationViewModel]() {
        didSet {
            self.updateConversations()
        }
    }

    @Published var selectedSegment = 0
    @Published var unreadMessages = 0
    @Published var unreadRequests = 0
    @Published var searchingLabel = ""
    var disposeBag = DisposeBag()
    let conversationsService: ConversationsService
    let requestsService: RequestsService
    let accountsService: AccountsService
    let stateSubject: PublishSubject<State>
    let injectionBag: InjectionBag
    var searchModel: JamiSearchViewModel?
    var searchQuery: String = ""


    init(injectionBag: InjectionBag, stateSubject: PublishSubject<State>) {
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.accountsService = injectionBag.accountService
        self.injectionBag = injectionBag
        self.stateSubject = stateSubject
        self.searchModel = JamiSearchViewModel(with: injectionBag, source: self, searchOnlyExistingConversations: false)
        self.subscribeConversations()
        self.subscribeSearch()
        self.subscribeUnhandledRequests()
    }

    private func subscribeConversations() {
        let conversationObservable = self.conversationsService.conversations
            .share()
            .startWith(self.conversationsService.conversations.value)
        let conersationViewModels =
        conversationObservable.map { [weak self] conversations -> [ConversationViewModel] in
                guard let self = self else { return [] }

                // Reset conversationViewModels if conversations are empty
                if conversations.isEmpty {
                    self.conversationViewModels.removeAll()
                    return []
                }

                // Map conversations to view models, updating existing ones or creating new
                return conversations.compactMap { conversationModel in
                    // Check for existing conversation view model
                    if let existing = self.conversationViewModels.first(where: { $0.conversation == conversationModel }) {
                        return existing
                    }
                    // Check for temporary conversation
                    else if let tempConversation = self.temporaryConversation, tempConversation.conversation == conversationModel {
                        tempConversation.conversationCreated.accept(true)
                        self.conversationViewModels.append(tempConversation)
                        return tempConversation
                    }
                    // Create new conversation view model
                    else {
                        let newViewModel = ConversationViewModel(with: self.injectionBag)
                        newViewModel.conversation = conversationModel
                        self.conversationViewModels.append(newViewModel)
                        return newViewModel
                    }
                }
            }

        conersationViewModels
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] updatedViewModels in
                self?.conversationViewModels = updatedViewModels
            })
            .disposed(by: self.disposeBag)

        // Observe conversation removed
        self.conversationsService.sharedResponseStream
            .filter({ event in
                event.eventType == .conversationRemoved && event.getEventInput(.accountId) == self.accountsService.currentAccount?.id
            })
            .subscribe(onNext: { [weak self] event in
                guard let conversationId: String = event.getEventInput(.conversationId),
                      let accountId: String = event.getEventInput(.accountId) else { return }
                guard let index = self?.conversationViewModels.firstIndex(where: { conversationModel in
                    conversationModel.conversation.id == conversationId && conversationModel.conversation.accountId == accountId
                }) else { return }
                self?.conversationViewModels.remove(at: index)
                self?.updateConversations()
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeUnhandledRequests() {
        let conversationObservable = self.conversationsService.conversations
            .share()
            .startWith(self.conversationsService.conversations.value)

        let requestObservable = self.requestsService.requests.asObservable()

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
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] number in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.unreadRequests = number
                }
            })
            .disposed(by: self.disposeBag)

    }

    private func subscribeSearch() {
        searchModel?
            .filteredResults
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversations in
                guard let self = self else { return }
                self.updateConversations(with: conversations)
            })
            .disposed(by: self.disposeBag)

        searchModel?
            .temporaryConversation
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversation in
                guard let self = self else { return }
                withAnimation {
                    self.temporaryConversation = conversation
                }
            })
            .disposed(by: self.disposeBag)

        searchModel?
            .jamsTemporaryResults
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversations in
                guard let self = self else { return }
                withAnimation {
                    self.jamsSearchResult = conversations
                }
            })
            .disposed(by: self.disposeBag)
        searchModel?
            .searchStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                withAnimation {
                    self.searchingLabel = status.toString()
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func updateConversations(with filtered: [ConversationViewModel]? = nil) {
        withAnimation {
            // Use filtered conversations if provided; otherwise, fall back to all conversationViewModels
            self.conversations = filtered ?? self.conversationViewModels
        }
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

    func performSearch(query: String) {
        self.searchQuery = query
        if let searchModel = self.searchModel {
            searchModel.searchBarText.accept(query)
        }
    }
}
