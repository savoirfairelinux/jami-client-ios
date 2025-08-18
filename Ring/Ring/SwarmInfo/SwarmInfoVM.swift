/*
 * Copyright (C) 2022 - 2025 Savoir-faire Linux Inc. *
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
    // MARK: - Public Properties

    @Published var participantsRows = [ParticipantRow]()
    @Published var selections: [String] = []
    @Published var title: String = ""
    @Published var description: String = ""

    @Published var finalColor: String = UIColor.defaultSwarm
    @Published var selectedColor: String = String()

    @Published var editableTitle: String = ""
    @Published var editableDescription: String = ""
    @Published var isShowingTitleAlert = false
    @Published var isShowingDescriptionAlert = false

    var swarmInfo: SwarmInfoProtocol
    var conversation: ConversationModel?

    // MARK: - Private Properties
    private let disposeBag = DisposeBag()
    private var contactsSubscriptionsDisposeBag = DisposeBag()

    private let accountService: AccountsService
    private let nameService: NameService
    let profileService: ProfilesService
    private let conversationService: ConversationsService
    private let contactsService: ContactsService
    let injectionBag: InjectionBag

    // MARK: - Computed Properties

    var isAdmin: Bool {
        guard let conversation = self.conversation else { return false }
        // No admin in one-to-one conversations
        if conversation.isCoredialog() {
            return false
        }

        guard let jamiId = accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId else {
            return false
        }

        let members = swarmInfo.participants.value
        return members.filter({ $0.role == .admin }).contains(where: { $0.jamiId == jamiId })
    }

    let provider: AvatarProvider

    // MARK: - Initialization

    init(with injectionBag: InjectionBag, swarmInfo: SwarmInfoProtocol) {
        self.injectionBag = injectionBag

        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.contactsService = injectionBag.contactsService

        self.swarmInfo = swarmInfo
        self.conversation = swarmInfo.conversation
        self.provider = AvatarProvider.from(swarmInfo: swarmInfo, profileService: self.profileService, size: Constants.AvatarSize.conversationInfo80)

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        Observable.combineLatest(
            swarmInfo.finalAvatarData,
            swarmInfo.finalTitle.startWith(swarmInfo.finalTitle.value),
            swarmInfo.description.startWith(swarmInfo.description.value),
            swarmInfo.color
        )
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] (_, newTitle, newDescription, newColor) in
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

    // MARK: - Contact Information Methods

    func getContactJamiId() -> String? {
        guard let conversation = self.conversation,
              conversation.isCoredialog(),
              let participant = conversation.getParticipants().first else {
            return nil
        }
        return participant.jamiId
    }

    func getContactDisplayName() -> String {
        guard let conversation = self.conversation,
              conversation.isCoredialog(),
              conversation.getParticipants().first != nil else {
            return ""
        }
        return title
    }

    func createShareInfo(for jamiId: String) -> String {
        return L10n.Swarm.shareContactMessage(jamiId)
    }

    // MARK: - Title and Description Editing

    func presentTitleEditView() {
        editableTitle = ""
        DispatchQueue.main.async { [weak self] in
            self?.isShowingTitleAlert = true
        }
    }

    func saveTitle() {
        DispatchQueue.main.async { [weak self] in
            self?.isShowingTitleAlert = false
        }
        if editableTitle == title { return }

        title = editableTitle
        updateSwarmInfo()
    }

    func presentDescriptionEditView() {
        editableDescription = ""
        DispatchQueue.main.async { [weak self] in
            self?.isShowingDescriptionAlert = true
        }
    }

    func saveDescription() {
        DispatchQueue.main.async { [weak self] in
            self?.isShowingDescriptionAlert = false
        }
        if editableDescription == description { return }

        description = editableDescription
        updateSwarmInfo()
    }

    // MARK: - Swarm Info Methods

    func updateSwarmInfo() {
        guard let conversationId = conversation?.id,
              let accountId = conversation?.accountId else { return }

        var conversationInfo = conversationService.getConversationInfo(conversationId: conversationId, accountId: accountId)
        conversationInfo[ConversationAttributes.description.rawValue] = description
        conversationInfo[ConversationAttributes.title.rawValue] = title
        self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: conversationInfo)
    }

    func updateSwarmAvatar(image: UIImage?) {
        guard let image = image,
              let data = image.convertToDataForSwarm(),
              let conversationId = conversation?.id,
              let accountId = conversation?.accountId else { return }

        var conversationInfo = conversationService.getConversationInfo(conversationId: conversationId, accountId: accountId)
        conversationInfo[ConversationAttributes.avatar.rawValue] = data.base64EncodedString()
        self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: conversationInfo)
        self.swarmInfo.avatarData.accept(data)
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

    func leaveSwarm(stateEmitter: ConversationStatePublisher) {
        guard let conversation = self.conversation else { return }

        let conversationId = conversation.id
        let accountId = conversation.accountId

        /*
         If it's a one-to-one conversation, remove the associated contact.
         This action will also remove the conversation.
         */
        if conversation.isCoredialog(),
           let participant = conversation.getParticipants().first {
            self.contactsService
                .removeContact(withId: participant.jamiId,
                               ban: false,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: {})
                .disposed(by: self.disposeBag)
        } else {
            self.conversationService
                .removeConversation(conversationId: conversationId, accountId: accountId)
        }
        stateEmitter.emitState(ConversationState.conversationRemoved)
    }

    func blockContact(stateEmitter: ConversationStatePublisher) {
        guard let conversation = self.conversation,
              let participantId = conversation.getParticipants().first?.jamiId else { return }

        let accountId = conversation.accountId

        contactsService
            .removeContact(withId: participantId,
                           ban: true,
                           withAccountId: accountId)
            .asObservable()
            .subscribe(onCompleted: {})
            .disposed(by: disposeBag)

        stateEmitter.emitState(ConversationState.conversationRemoved)
    }
}
