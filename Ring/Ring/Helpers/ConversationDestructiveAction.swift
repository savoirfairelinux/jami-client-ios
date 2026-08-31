/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

/// A destructive action that can be performed on a conversation. Shared by the
/// smart list (swipe actions / context menu) and Swarm Info (`SettingsView`)
enum ConversationDestructiveAction: CaseIterable, Identifiable {
    case blockContact
    case removeContact
    case removeConversation

    var id: Self { self }

    static func availableActions(for conversation: ConversationModel) -> [ConversationDestructiveAction] {
        if conversation.isSip() {
            return [.removeConversation]
        }

        if !conversation.isSwarm() {
            return conversation.getParticipants().first == nil ? [] : [.blockContact, .removeContact]
        }

        if conversation.isCoredialog(), conversation.getParticipants().first != nil {
            return [.blockContact, .removeContact, .removeConversation]
        }

        return [.removeConversation]
    }
}

// MARK: - Presentation

extension ConversationDestructiveAction {
    func title(for conversation: ConversationModel) -> String {
        switch self {
        case .blockContact:
            return L10n.Global.blockContact
        case .removeContact:
            return L10n.Swarm.removeContact
        case .removeConversation:
            switch ConversationRemovalPresentation(for: conversation) {
            case .remove:
                return L10n.Swarm.removeConversation
            case .leave:
                return L10n.Swarm.leaveConversation
            }
        }
    }

    func confirmationMessage(for conversation: ConversationModel) -> String {
        switch self {
        case .blockContact:
            return L10n.Alerts.confirmBlockContact
        case .removeContact:
            return L10n.Alerts.confimRemoveContact
        case .removeConversation:
            if conversation.isSip() {
                return L10n.Alerts.confirmDeleteConversation
            }
            if conversation.isCoredialog() {
                return L10n.Alerts.confirmRemoveOneToOneConversation
            }
            switch ConversationRemovalPresentation(for: conversation) {
            case .remove:
                return L10n.Alerts.confirmDeleteConversation
            case .leave:
                return L10n.Alerts.confirmLeaveConversation
            }
        }
    }

    func confirmationButtonTitle(for conversation: ConversationModel) -> String {
        switch self {
        case .blockContact:
            return L10n.Global.block
        case .removeContact:
            return L10n.Global.remove
        case .removeConversation:
            switch ConversationRemovalPresentation(for: conversation) {
            case .remove:
                return L10n.Global.remove
            case .leave:
                return L10n.Global.leave
            }
        }
    }

    func swipeActionTitle(for conversation: ConversationModel) -> String {
        switch self {
        case .blockContact:
            return L10n.Global.block
        case .removeContact:
            return L10n.Global.remove
        case .removeConversation:
            switch ConversationRemovalPresentation(for: conversation) {
            case .remove:
                return L10n.Actions.deleteAction
            case .leave:
                return L10n.Global.leave
            }
        }
    }

    func icon(for conversation: ConversationModel) -> String {
        switch self {
        case .blockContact:
            return "person.crop.circle.badge.xmark"
        case .removeContact:
            return "person.crop.circle.badge.minus"
        case .removeConversation:
            switch ConversationRemovalPresentation(for: conversation) {
            case .remove:
                return "trash"
            case .leave:
                return "arrow.right.circle"
            }
        }
    }
}

private enum ConversationRemovalPresentation {
    case remove
    case leave

    init(for conversation: ConversationModel) {
        self = conversation.isSip() || conversation.isDialog() || conversation.isOnlyLocalParticipant()
            ? .remove
            : .leave
    }
}

// MARK: - Execution

final class ConversationDestructiveActionExecutor {
    private let contactsService: ContactsService
    private let conversationsService: ConversationsService
    private let profileService: ProfilesService
    private let disposeBag = DisposeBag()

    init(contactsService: ContactsService,
         conversationsService: ConversationsService,
         profileService: ProfilesService) {
        self.contactsService = contactsService
        self.conversationsService = conversationsService
        self.profileService = profileService
    }

    convenience init(injectionBag: InjectionBag) {
        self.init(contactsService: injectionBag.contactsService,
                  conversationsService: injectionBag.conversationsService,
                  profileService: injectionBag.profileService)
    }

    func perform(_ action: ConversationDestructiveAction,
                 on conversation: ConversationModel,
                 removeConversationAfterContactRemoval: Bool = true,
                 fallbackToConversationRemoval: Bool = true,
                 completion: (() -> Void)? = nil) {
        switch action {
        case .blockContact:
            removeContact(conversation,
                          ban: true,
                          removeConversationAfterContactRemoval: removeConversationAfterContactRemoval,
                          fallbackToConversationRemoval: fallbackToConversationRemoval,
                          completion: completion)
        case .removeContact:
            removeContact(conversation,
                          ban: false,
                          removeConversationAfterContactRemoval: removeConversationAfterContactRemoval,
                          fallbackToConversationRemoval: fallbackToConversationRemoval,
                          completion: completion)
        case .removeConversation:
            removeConversation(conversation, completion: completion)
        }
    }

    private func removeConversation(_ conversation: ConversationModel,
                                    completion: (() -> Void)?) {
        // SIP conversations are local DB constructs, not daemon swarms, so the daemon
        // removeConversation call is a no-op for them — clear them from the DB instead.
        if conversation.isSip() {
            conversationsService.removeConversationFromDB(conversation: conversation,
                                                          keepConversation: false)
            completion?()
            return
        }

        conversationsService.removeConversation(conversationId: conversation.id,
                                                accountId: conversation.accountId)
        completion?()
    }

    private func removeContact(_ conversation: ConversationModel,
                               ban: Bool,
                               removeConversationAfterContactRemoval: Bool,
                               fallbackToConversationRemoval: Bool,
                               completion: (() -> Void)?) {
        guard conversation.isCoredialog(),
              let participantId = conversation.getParticipants().first?.jamiId else {
            if fallbackToConversationRemoval {
                removeConversation(conversation, completion: completion)
            } else {
                completion?()
            }
            return
        }

        contactsService
            .removeContact(withId: participantId,
                           ban: ban,
                           withAccountId: conversation.accountId)
            .asObservable()
            .subscribe(onCompleted: { [weak self, weak conversation] in
                guard let conversation = conversation else { return }
                if removeConversationAfterContactRemoval {
                    self?.conversationsService
                        .removeConversationFromDB(conversation: conversation,
                                                  keepConversation: false)
                } else {
                    self?.clearCustomProfile(for: conversation)
                }
                completion?()
            })
            .disposed(by: disposeBag)
    }

    private func clearCustomProfile(for conversation: ConversationModel) {
        guard let participantId = conversation.getParticipants().first?.jamiId else { return }
        let schema: URIType = conversation.isSip() ? .sip : .ring
        guard let uri = JamiURI(schema: schema, infoHash: participantId).uriString else { return }
        profileService.updateCustomProfile(uri: uri,
                                           accountId: conversation.accountId,
                                           alias: nil,
                                           photo: nil)
    }
}
