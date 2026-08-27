/*
 * Copyright (C) 2022 - 2026 Savoir-faire Linux Inc. *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import UIKit
import RxSwift
import RxRelay
import RxCocoa

class SwarmInfoVM: ObservableObject {
    typealias CallTarget = (uri: String, displayName: String)

    // MARK: - Public Properties

    @Published var participantsRows = [ParticipantRow]()
    @Published var selections: [String] = []
    @Published var title: String = ""
    @Published var description: String = ""

    @Published var finalColor: String = UIColor.defaultSwarmColorHex
    @Published var selectedColor: String = String()
    @Published private(set) var isAdmin = false

    var swarmInfo: SwarmInfoProtocol
    var conversation: ConversationModel?

    /// Built when the documents tab is first shown, so a conversation that is
    /// never asked for its documents never asks the daemon for them.
    lazy var collabDocuments: CollabDocumentsVM? = {
        guard let conversation = self.conversation else { return nil }
        return CollabDocumentsVM(with: self.injectionBag,
                                 accountId: conversation.accountId,
                                 conversationId: conversation.id,
                                 participants: self.swarmInfo.participants.asObservable())
    }()

    // MARK: - Private Properties
    private let disposeBag = DisposeBag()
    private var contactsSubscriptionsDisposeBag = DisposeBag()

    private let accountService: AccountsService
    private let nameService: NameService
    let profileService: ProfilesService
    private let conversationService: ConversationsService
    private let callService: CallService
    private let destructiveActionExecutor: ConversationDestructiveActionExecutor
    let injectionBag: InjectionBag

    // MARK: - Computed Properties

    static func profileEditingAllowed(isCoreDialog: Bool,
                                      hasRemoteParticipant: Bool,
                                      isAdmin: Bool) -> Bool {
        if isCoreDialog {
            return hasRemoteParticipant
        }
        return isAdmin
    }

    var canEditProfile: Bool {
        guard let conversation else { return false }
        return Self.profileEditingAllowed(isCoreDialog: conversation.isCoredialog(),
                                          hasRemoteParticipant: !conversation.isOnlyLocalParticipant(),
                                          isAdmin: isAdmin)
    }

    var isGroupProfile: Bool {
        conversation?.isCoredialog() == false
    }

    var conversationToEdit: ConversationModel? {
        guard canEditProfile else { return nil }
        return conversation
    }

    func editProfile(stateEmitter: ConversationStatePublisher) {
        guard let conversation = conversationToEdit else { return }
        stateEmitter.emitState(.editConversationProfile(conversation: conversation))
    }

    var callTarget: CallTarget? {
        guard let conversation,
              let uri = callService.outgoingCallURI(for: conversation) else { return nil }
        return (uri: uri, displayName: conversation.isCoredialog() ? title : "")
    }

    let provider: AvatarProvider

    var removeConversationText: String {
        guard let conversation = self.conversation else {
            return L10n.Swarm.removeConversation
        }
        return ConversationDestructiveAction.removeConversation.title(for: conversation)
    }

    var removeConversationConfirmation: String {
        guard let conversation = self.conversation else {
            return L10n.Alerts.confirmLeaveConversation
        }
        return ConversationDestructiveAction.removeConversation.confirmationMessage(for: conversation)
    }

    var removeConversationAlertButton: String {
        guard let conversation = self.conversation else {
            return L10n.Global.remove
        }
        return ConversationDestructiveAction.removeConversation.confirmationButtonTitle(for: conversation)
    }

    var blockContactIcon: String {
        destructiveActionIcon(.blockContact, fallback: "person.crop.circle.badge.xmark")
    }

    var removeContactIcon: String {
        destructiveActionIcon(.removeContact, fallback: "person.crop.circle.badge.minus")
    }

    var removeConversationIcon: String {
        destructiveActionIcon(.removeConversation, fallback: "trash")
    }

    // MARK: - Initialization

    init(with injectionBag: InjectionBag, swarmInfo: SwarmInfoProtocol) {
        self.injectionBag = injectionBag

        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.callService = injectionBag.callService
        self.destructiveActionExecutor = ConversationDestructiveActionExecutor(injectionBag: injectionBag)

        self.swarmInfo = swarmInfo
        self.conversation = swarmInfo.conversation
        self.provider = AvatarProvider.from(
            swarmInfo: swarmInfo,
            profileService: profileService,
            size: .conversationInfo120,
            supportsExpansion: true
        )
        self.isAdmin = currentUserIsAdmin(in: swarmInfo.participants.value)

        setupBindings()
    }

    private func destructiveActionIcon(_ action: ConversationDestructiveAction, fallback: String) -> String {
        guard let conversation = self.conversation else {
            return fallback
        }
        return action.icon(for: conversation)
    }

    // MARK: - Setup

    private func setupBindings() {
        swarmInfo.participants
            .map { [weak self] participants in
                self?.currentUserIsAdmin(in: participants) ?? false
            }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isAdmin in
                self?.isAdmin = isAdmin
            })
            .disposed(by: disposeBag)

        Observable.combineLatest(
            swarmInfo.finalTitle.startWith(swarmInfo.finalTitle.value),
            swarmInfo.description.startWith(swarmInfo.description.value),
            swarmInfo.color
        )
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] (newTitle, newDescription, newColor) in
            guard let self = self else { return }

            if self.title != newTitle {
                self.title = newTitle
            }

            if self.description != newDescription {
                self.description = newDescription
            }

            // Update color if not empty
            if !newColor.isEmpty {
                self.finalColor = newColor
                self.selectedColor = Constants.swarmColors.keys.contains(newColor) ? newColor : String()
            }
        })
        .disposed(by: disposeBag)
    }

    private func currentUserIsAdmin(in participants: [ParticipantInfo]) -> Bool {
        guard let conversation,
              !conversation.isCoredialog(),
              let jamiId = accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId else {
            return false
        }
        return participants.contains { $0.role == .admin && $0.jamiId == jamiId }
    }

    // MARK: - Contact Information Methods

    func getContactJamiId() -> String? {
        guard let conversation = self.conversation,
              conversation.isCoredialog() else {
            return nil
        }
        // For regular conversations, return the first non-local participant
        if let participant = conversation.getParticipants().first {
            return participant.jamiId
        }
        // For self-conversation, return the local participant's jamiId
        return conversation.getLocalParticipants()?.jamiId
    }

    func createShareInfo(for jamiId: String) -> String {
        return L10n.Swarm.shareContactMessage(jamiId)
    }

    func updateSwarmColor(selectedColor: String) {
        guard let conversationId = conversation?.id,
              let accountId = conversation?.accountId,
              var prefsInfo = conversationService.getConversationPreferences(accountId: accountId, conversationId: conversationId) else { return }

        prefsInfo[ConversationPreferenceAttributes.color.rawValue] = selectedColor
        self.conversationService.updateConversationPrefs(accountId: accountId, conversationId: conversationId, prefs: prefsInfo)
    }

    // MARK: - Participants Management

    func updateContactList() {
        self.contactsSubscriptionsDisposeBag = DisposeBag()

        let contactUpdates = swarmInfo.contacts
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .map { contacts -> [ParticipantRow] in
                return contacts.map { ParticipantRow(participantData: $0) }
            }
            .observe(on: MainScheduler.instance)

        contactUpdates
            .subscribe(onNext: { [weak self] rows in
                self?.participantsRows = rows
            })
            .disposed(by: self.contactsSubscriptionsDisposeBag)

        injectionBag.contactsService.contacts
            .subscribe(onNext: { [weak self] contacts in
                self?.swarmInfo.addContacts(contacts: contacts)
            })
            .disposed(by: self.contactsSubscriptionsDisposeBag)
    }

    func removeExistingSubscription() {
        self.contactsSubscriptionsDisposeBag = DisposeBag()
    }

    func addMember() {
        guard let conversationId = conversation?.id,
              let accountId = conversation?.accountId else { return }

        for participant in selections {
            conversationService.addConversationMember(accountId: accountId, conversationId: conversationId, memberId: participant)
        }
        selections.removeAll()
    }

    func removeMember(indexOffset: IndexSet) {
        guard let conversationId = conversation?.id,
              let accountId = conversation?.accountId else { return }

        let idsToDelete = indexOffset.map { swarmInfo.participants.value[$0].jamiId }

        for memberId in idsToDelete {
            conversationService.removeConversationMember(accountId: accountId, conversationId: conversationId, memberId: memberId)
        }
    }

    func removeContact(stateEmitter: ConversationStatePublisher) {
        guard let conversation = self.conversation else { return }
        destructiveActionExecutor.perform(.removeContact,
                                          on: conversation,
                                          removeConversationAfterContactRemoval: false,
                                          fallbackToConversationRemoval: false)
        stateEmitter.emitState(ConversationState.conversationRemoved)
    }

    func removeConversation(stateEmitter: ConversationStatePublisher) {
        guard let conversation = self.conversation else { return }
        destructiveActionExecutor.perform(.removeConversation, on: conversation)
        stateEmitter.emitState(ConversationState.conversationRemoved)
    }

    func blockContact(stateEmitter: ConversationStatePublisher) {
        guard let conversation = self.conversation else { return }
        destructiveActionExecutor.perform(.blockContact,
                                          on: conversation,
                                          removeConversationAfterContactRemoval: false,
                                          fallbackToConversationRemoval: false)
        stateEmitter.emitState(ConversationState.conversationRemoved)
    }
}
