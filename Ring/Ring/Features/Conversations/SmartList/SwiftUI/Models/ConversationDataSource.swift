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
    var blockedConversation = [ConversationViewModel]()
    let conversationsService: ConversationsService
    let contactsService: ContactsService
    let accountsService: AccountsService
    var disposeBag = DisposeBag()
    let injectionBag: InjectionBag

    var onNewConversationViewModelCreated: ((ConversationModel) -> Void)?
    var onConversationRestored: ((ConversationModel) -> Void)?

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
            let isBlocked = isConversationWithBlockedContact(conversationModel)
            guard let newViewModel = createOrRetrieveViewModel(for: conversationModel,
                                                               isBlocked: isBlocked) else {
                return nil
            }

            if isBlocked {
                newViewModel.updateBlockedStatus()
                blockedConversation.append(newViewModel)
                return nil
            }

            onNewConversationViewModelCreated?(conversationModel)
            return newViewModel
        }
    }

    private func createOrRetrieveViewModel(for conversationModel: ConversationModel, isBlocked: Bool) -> ConversationViewModel? {
        if let viewModel = conversationViewModels.first(where: { $0.conversation == conversationModel }) {
            return viewModel
        } else if let viewModel = blockedConversation.first(where: { $0.conversation == conversationModel }) {
            if !isConversationWithBlockedContact(conversationModel) {
                viewModel.conversation = conversationModel
                blockedConversation.removeAll(where: { $0 === viewModel })
                if let onConversationRestored = self.onConversationRestored, let conversation = viewModel.conversation {
                    onConversationRestored(conversation)
                }
            }
            return viewModel
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

                self.restoreConversation(jamiId: peerUri, accountId: accountId)
            })
            .disposed(by: disposeBag)
    }

    private func restoreConversation(jamiId: String, accountId: String) {
        // If the conversation is not banned, it is a new contact that will be added when conversation ready, skip it.
        guard let blockedIndex = blockedConversation.firstIndex(where: { $0.isCoreConversationWith(jamiId: jamiId) }) else {
            return
        }
        let viewModel = blockedConversation.remove(at: blockedIndex)
        let conversation = viewModel.conversation

        // Retrieve the conversation and determine its correct index to maintain the order
        guard let targetIndex = conversationsService.conversations.value.firstIndex(where: { $0 == conversation }) else {
            return
        }

        // Reset conversation for view model, to trigger conversation didSet.
        viewModel.conversation = conversation
        if let onConversationRestored = self.onConversationRestored, let conversation = conversation {
            onConversationRestored(conversation)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let safeIndex = min(targetIndex, self.conversationViewModels.count)
            self.conversationViewModels.insert(viewModel, at: safeIndex)
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
            conversationViewModel.updateBlockedStatus()
            self.blockedConversation.append(conversationViewModel)
        } else {
            // Ignore if already in the banned
            if self.blockedConversation.contains(where: { $0.isCoreConversationWith(jamiId: jamiId) }) { return}
            // If not, check if the conversation exists in conversationsService
            if let conversationModel = self.conversationsService.getConversationForParticipant(jamiId: jamiId, accountId: accountId) {
                let newViewModel = ConversationViewModel(with: self.injectionBag)
                newViewModel.conversation = conversationModel
                self.blockedConversation.append(newViewModel)
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

    private func isConversationWithBlockedContact(_ conversation: ConversationModel) -> Bool {
        guard conversation.isCoredialog(),
              let jamiId = conversation.getParticipants().first?.jamiId,
              let contact = self.contactsService.contact(withHash: jamiId) else {
            return false
        }
        return contact.banned
    }
}
