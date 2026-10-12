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
    @Published private(set) var selectedColor: String = String()
    @Published private(set) var isAdmin = false
    @Published private(set) var members = [ParticipantInfo]()

    let swarmInfo: SwarmInfoProtocol
    var conversation: ConversationModel {
        swarmInfo.conversation
    }

    /// Built when the documents tab is first shown, so a conversation that is
    /// never asked for its documents never asks the daemon for them.
    lazy var collabDocuments: CollabDocumentsVM = {
        return CollabDocumentsVM(with: self.injectionBag,
                                 accountId: self.conversation.accountId,
                                 conversationId: self.conversation.id,
                                 participants: self.swarmInfo.participants.asObservable())
    }()

    // MARK: - Private Properties
    private let disposeBag = DisposeBag()
    private var contactsSubscriptionsDisposeBag = DisposeBag()
    private var inviteCandidates: SwarmInviteCandidates?

    private let accountService: AccountsService
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
        return Self.profileEditingAllowed(isCoreDialog: conversation.isCoredialog(),
                                          hasRemoteParticipant: !conversation.isOnlyLocalParticipant(),
                                          isAdmin: isAdmin)
    }

    var canAddParticipants: Bool {
        return !conversation.isCoredialog()
    }

    var isGroupProfile: Bool {
        !conversation.isCoredialog()
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
        guard let uri = callService.outgoingCallURI(for: conversation) else { return nil }
        return (uri: uri, displayName: conversation.isCoredialog() ? title : "")
    }

    let provider: AvatarProvider

    var removeConversationText: String {
        return ConversationDestructiveAction.removeConversation.title(for: conversation)
    }

    var removeConversationConfirmation: String {
        return ConversationDestructiveAction.removeConversation.confirmationMessage(for: conversation)
    }

    var removeConversationAlertButton: String {
        return ConversationDestructiveAction.removeConversation.confirmationButtonTitle(for: conversation)
    }

    var blockContactIcon: String {
        ConversationDestructiveAction.blockContact.icon(for: conversation)
    }

    var removeContactIcon: String {
        ConversationDestructiveAction.removeContact.icon(for: conversation)
    }

    var removeConversationIcon: String {
        ConversationDestructiveAction.removeConversation.icon(for: conversation)
    }

    // MARK: - Initialization

    init(with injectionBag: InjectionBag, swarmInfo: SwarmInfoProtocol) {
        self.injectionBag = injectionBag

        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.profileService = injectionBag.profileService
        self.callService = injectionBag.callService
        self.destructiveActionExecutor = ConversationDestructiveActionExecutor(injectionBag: injectionBag)

        self.swarmInfo = swarmInfo
        self.provider = AvatarProvider.from(
            swarmInfo: swarmInfo,
            profileService: profileService,
            size: .conversationInfo120,
            supportsExpansion: true
        )
        self.isAdmin = currentUserIsAdmin(in: swarmInfo.participants.value)
        self.members = swarmInfo.participants.value

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        swarmInfo.participants
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] participants in
                self?.members = participants
            })
            .disposed(by: disposeBag)

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
        guard !conversation.isCoredialog(),
              let jamiId = accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId else {
            return false
        }
        return participants.contains { $0.role == .admin && $0.jamiId == jamiId }
    }

    // MARK: - Contact Information Methods

    func getContactJamiId() -> String? {
        guard conversation.isCoredialog() else {
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
        guard selectedColor != self.selectedColor,
              var prefsInfo = conversationService.getConversationPreferences(accountId: conversation.accountId, conversationId: conversation.id) else { return }
        self.selectedColor = selectedColor

        prefsInfo[ConversationPreferenceAttributes.color.rawValue] = selectedColor
        self.conversationService.updateConversationPrefs(accountId: conversation.accountId, conversationId: conversation.id, prefs: prefsInfo)
    }

    // MARK: - Participants Management

    func updateContactList() {
        self.contactsSubscriptionsDisposeBag = DisposeBag()
        let inviteCandidates = SwarmInviteCandidates(injectionBag: injectionBag,
                                                     accountId: conversation.accountId,
                                                     members: swarmInfo.participants.asObservable())
        self.inviteCandidates = inviteCandidates

        let contactUpdates = inviteCandidates.candidates
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
    }

    func removeExistingSubscription() {
        self.contactsSubscriptionsDisposeBag = DisposeBag()
        self.inviteCandidates = nil
    }

    func addMember() {
        for participant in selections {
            conversationService.addConversationMember(accountId: conversation.accountId, conversationId: conversation.id, memberId: participant)
        }
        selections.removeAll()
    }

    func removeMember(indexOffset: IndexSet) {
        let idsToDelete = indexOffset.map { members[$0].jamiId }

        for memberId in idsToDelete {
            conversationService.removeConversationMember(accountId: conversation.accountId, conversationId: conversation.id, memberId: memberId)
        }
    }

    func removeContact(stateEmitter: ConversationStatePublisher) {
        destructiveActionExecutor.perform(.removeContact,
                                          on: conversation,
                                          removeConversationAfterContactRemoval: false,
                                          fallbackToConversationRemoval: false)
        stateEmitter.emitState(ConversationState.conversationRemoved)
    }

    func removeConversation(stateEmitter: ConversationStatePublisher) {
        destructiveActionExecutor.perform(.removeConversation, on: conversation)
        stateEmitter.emitState(ConversationState.conversationRemoved)
    }

    func blockContact(stateEmitter: ConversationStatePublisher) {
        destructiveActionExecutor.perform(.blockContact,
                                          on: conversation,
                                          removeConversationAfterContactRemoval: false,
                                          fallbackToConversationRemoval: false)
        stateEmitter.emitState(ConversationState.conversationRemoved)
    }
}
