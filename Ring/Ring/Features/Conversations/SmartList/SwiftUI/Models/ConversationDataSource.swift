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
    @Published var rows = [ConversationRowVM]()
    var blockedRows = [ConversationRowVM]()
    let conversationsService: ConversationsService
    let contactsService: ContactsService
    let accountsService: AccountsService
    var disposeBag = DisposeBag()
    let injectionBag: InjectionBag

    var onNewRowCreated: ((ConversationModel) -> Void)?
    var onConversationRestored: ((ConversationModel) -> Void)?
    var getTemporaryConversation: ((ConversationModel) -> ConversationRowVM?)?

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
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversations in
                guard let self = self else { return }
                self.rows = self.mapConversationsToRows(conversations)
            })
            .disposed(by: disposeBag)
    }

    private func mapConversationsToRows(_ conversations: [ConversationModel]) -> [ConversationRowVM] {
        var rowsByConversation = [ObjectIdentifier: ConversationRowVM]()
        for row in rows {
            if let conversation = row.conversation {
                rowsByConversation[ObjectIdentifier(conversation)] = row
            }
        }
        let bannedContacts = Set(contactsService.contacts.value.filter { $0.banned }.map { $0.hash })
        return conversations.compactMap { conversationModel -> ConversationRowVM? in
            let isBlocked = isConversationWithBlockedContact(conversationModel, bannedContacts: bannedContacts)
            if isBlocked,
               let existing = blockedRows.first(where: { $0.conversation == conversationModel }) {
                if existing.conversation !== conversationModel {
                    existing.conversation = conversationModel
                }
                return nil
            }
            guard let row = rowsByConversation[ObjectIdentifier(conversationModel)] ??
                    createOrRetrieveRow(for: conversationModel, isBlocked: isBlocked) else {
                return nil
            }

            if isBlocked {
                row.updateBlockedStatus()
                blockedRows.append(row)
                return nil
            }

            onNewRowCreated?(conversationModel)
            return row
        }
    }

    private func createOrRetrieveRow(for conversationModel: ConversationModel, isBlocked: Bool) -> ConversationRowVM? {
        if let row = rows.first(where: { $0.conversation == conversationModel }) {
            row.conversation = conversationModel
            return row
        }
        // Attempt to restore a blocked conversation if not blocked
        if !isBlocked,
           let jamiId = conversationModel.getParticipants().first?.jamiId,
           let restoredRow = restoreBlockedConversation(jamiId: jamiId) {
            return restoredRow
        }

        // Update temporary conversation if exists
        if let tempConversation = getTemporaryConversation?(conversationModel) {
            tempConversation.conversation = conversationModel
            return tempConversation
        }

        let newRow = ConversationRowVM(with: injectionBag)
        newRow.conversation = conversationModel
        return newRow
    }

    func restoreBlockedConversation(jamiId: String) -> ConversationRowVM? {
        guard let blockedIndex = blockedRows.firstIndex(where: { $0.isCoreConversationWith(jamiId: jamiId) }) else {
            return nil
        }
        let row = blockedRows.remove(at: blockedIndex)

        // Reset conversation to trigger didSet
        let conversation = row.conversation
        row.conversation = conversation

        // Notify if a conversation has been restored
        if let onConversationRestored = self.onConversationRestored,
           let conversation = conversation {
            onConversationRestored(conversation)
        }

        return row
    }

    private func observeContactAdded() {
        self.contactsService.sharedResponseStream
            .filter { $0.eventType == .contactAdded }
            .observe(on: MainScheduler.instance)
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
        guard let row = restoreBlockedConversation(jamiId: jamiId) else { return }
        // Retrieve the conversation and determine its correct index to maintain the order
        let storeConversations = conversationsService.currentConversations
        guard let targetIndex = storeConversations.firstIndex(where: { $0 == row.conversation }) else {
            self.blockedRows.append(row)
            return
        }
        let preceding = Set(storeConversations[..<targetIndex].map { ObjectIdentifier($0) })
        let insertIndex = self.rows.filter { visible in
            visible.conversation.map { preceding.contains(ObjectIdentifier($0)) } ?? false
        }.count
        self.rows.insert(row, at: insertIndex)
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
        if let index = self.rows.firstIndex(where: { $0.isCoreConversationWith(jamiId: jamiId) }) {
            let row = self.rows.remove(at: index)
            row.updateBlockedStatus()
            self.blockedRows.append(row)
        } else {
            // Ignore if already in the banned
            if self.blockedRows.contains(where: { $0.isCoreConversationWith(jamiId: jamiId) }) { return }
            // If not, check if the conversation exists in conversationsService
            if let conversationModel = self.conversationsService.getConversationForParticipant(jamiId: jamiId, accountId: accountId) {
                let newRow = ConversationRowVM(with: self.injectionBag)
                newRow.conversation = conversationModel
                self.blockedRows.append(newRow)
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
                      let accountId: String = event.getEventInput(.accountId) else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.rows.removeAll { $0.conversation.id == conversationId && $0.conversation.accountId == accountId
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    private func isConversationWithBlockedContact(_ conversation: ConversationModel,
                                                  bannedContacts: Set<String>) -> Bool {
        guard conversation.isCoredialog(),
              let jamiId = conversation.getParticipants().first?.jamiId else {
            return false
        }
        return bannedContacts.contains(jamiId)
    }
}
