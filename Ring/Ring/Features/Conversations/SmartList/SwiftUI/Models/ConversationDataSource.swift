/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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
import RxRelay

class ConversationDataSource: ObservableObject {
    @Published var conversationViewModels = [ConversationViewModel]()
    var bannedConversations = [ConversationViewModel]()
    let conversationsService: ConversationsService
    let contactsService: ContactsService
    let accountsService: AccountsService
    var disposeBag = DisposeBag()
    let injectionBag: InjectionBag

    var onNewConversationViewModelCreated: ((ConversationModel) -> Void)?

    init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.conversationsService = injectionBag.conversationsService
        self.accountsService = injectionBag.accountService
        self.contactsService = injectionBag.contactsService
        self.subscribeToConversations()
        self.subscribeToConversationRemovals()
        self.observeContactAdded()
        self.observeContactRemoved()
    }

    private func subscribeToConversations() {
        self.conversationsService.conversations
            .share()
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .map { [weak self] conversations in
                self?.mapConversationsToViewModels(conversations) ?? []
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] updatedViewModels in
                self?.conversationViewModels = updatedViewModels
            })
            .disposed(by: disposeBag)
    }

    private func mapConversationsToViewModels(_ conversations: [ConversationModel]) -> [ConversationViewModel] {
        conversations.compactMap { conversationModel -> ConversationViewModel? in
            guard let newViewModel = createOrRetrieveViewModel(for: conversationModel) else {
                return nil
            }

            if isConversationWithBannedContact(conversationModel) {
                bannedConversations.append(newViewModel)
                return nil
            }

            onNewConversationViewModelCreated?(conversationModel)
            return newViewModel
        }
    }

    private func createOrRetrieveViewModel(for conversationModel: ConversationModel) -> ConversationViewModel? {
        if let existingViewModel = conversationViewModels.first(where: { $0.conversation == conversationModel }) {
            return existingViewModel
        } else {
            let newViewModel = ConversationViewModel(with: injectionBag)
            newViewModel.conversation = conversationModel
            return newViewModel
        }
    }

    private func observeContactAdded() {
        self.contactsService.sharedResponseStream
            .filter { $0.eventType == .contactAdded }
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let peerUri: String = event.getEventInput(.peerUri),
                      let account = self.accountsService.currentAccount,
                      account.id == accountId else { return }

                // Contact added; move conversation from banned to active if needed
                DispatchQueue.main.async {[weak self] in
                    guard let self = self else { return }
                    self.moveConversation(jamiId: peerUri)
                }
            })
            .disposed(by: disposeBag)
    }

    private func moveConversation(jamiId: String) {
        if let index = self.bannedConversations.firstIndex(where: { $0.isCoreConversationWith(jamiId: jamiId) }) {
            let conversationViewModel = self.bannedConversations.remove(at: index)
            self.conversationViewModels.append(conversationViewModel)
        }
    }

    private func observeContactRemoved() {
        self.contactsService.sharedResponseStream
            .filter { $0.eventType == .contactRemoved }
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let peerUri: String = event.getEventInput(.peerUri),
                      let account = self.accountsService.currentAccount,
                      account.id == accountId else { return }

                // Contact removed; if the contact is banned, move or add the conversation to banned
                if let contact = self.contactsService.contact(withHash: peerUri), contact.banned {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.moveOrAddConversationToBanned(jamiId: peerUri, accountId: accountId)
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    private func moveOrAddConversationToBanned(jamiId: String, accountId: String) {
        // Check if the conversation is already in active conversations
        if let index = self.conversationViewModels.firstIndex(where: { $0.isCoreConversationWith(jamiId: jamiId) }) {
            let conversationViewModel = self.conversationViewModels.remove(at: index)
            self.bannedConversations.append(conversationViewModel)
        } else {
            // Ignore if already in the banned
            if self.bannedConversations.contains(where: { $0.isCoreConversationWith(jamiId: jamiId) }) { return}
            // If not, check if the conversation exists in conversationsService
            if let conversationModel = self.conversationsService.getConversationForParticipant(jamiId: jamiId, accountId: accountId) {
                let newViewModel = ConversationViewModel(with: self.injectionBag)
                newViewModel.conversation = conversationModel
                self.bannedConversations.append(newViewModel)
            }
        }
    }

    private func subscribeToConversationRemovals() {
        self.conversationsService.sharedResponseStream
            .filter { event in
                event.eventType == .conversationRemoved && event.getEventInput(.accountId) == self.accountsService.currentAccount?.id
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let conversationId: String = event.getEventInput(.conversationId),
                      let accountId: String = event.getEventInput(.accountId),
                      let index = self.conversationViewModels.firstIndex(where: { $0.conversation.id == conversationId && $0.conversation.accountId == accountId }) else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.conversationViewModels.remove(at: index)
                }
            })
            .disposed(by: disposeBag)
    }

    private func isConversationWithBannedContact(_ conversation: ConversationModel) -> Bool {
        guard conversation.isCoredialog(),
              let jamiId = conversation.getParticipants().first?.jamiId,
              let contact = self.contactsService.contact(withHash: jamiId) else {
            return false
        }
        return contact.banned
    }
}
