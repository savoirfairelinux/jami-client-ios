/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 * Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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

class SwarmInfoStateEmmiter: Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    func emitState(newState: ConversationState) {
        self.stateSubject.onNext(newState)
    }
}

class SwarmInfoVM: ObservableObject {
    @Published var participantsRows = [ParticipantRow]()
    @Published var selections: [String] = []
    @Published var finalAvatar: UIImage = UIImage()
    @Published var finalTitle: String = ""
    @Published var finalColor: String = UIColor.defaultSwarm
    @Published var selectedColor: String = String()
    @Published var showColorSheet = false

    private let disposeBag = DisposeBag()
    private var contactsSubscriptionsDisposeBag = DisposeBag()
    let injectionBag: InjectionBag
    private let accountService: AccountsService
    private let nameService: NameService
    private let profileService: ProfilesService
    private let conversationService: ConversationsService
    private let contactsService: ContactsService

    var swarmInfo: SwarmInfoProtocol
    var conversation: ConversationModel?
    var description: String = "" {
        didSet {
            if shouldTriggerDescriptionDidSet {
                updateSwarmInfo()
            }
        }
    }
    var title: String = "" {
        didSet {
            if shouldTriggerDescriptionDidSet {
                updateSwarmInfo()
            }
        }
    }
    var isAdmin: Bool {
        guard let accountId = self.conversation?.accountId,
              let jamiId = accountService.getAccount(fromAccountId: accountId)?.jamiId else {
            return false
        }
        let members = swarmInfo.participants.value
        return members.filter({ $0.role == .admin }).contains(where: { $0.jamiId == jamiId })
    }
    private var shouldTriggerDescriptionDidSet: Bool = false
    var colorPickerStatus = BehaviorRelay<Bool>(value: false)
    var navBarColor = BehaviorRelay<String>(value: "")

    init(with injectionBag: InjectionBag, swarmInfo: SwarmInfoProtocol) {
        self.injectionBag = injectionBag
        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.contactsService = injectionBag.contactsService
        self.swarmInfo = swarmInfo
        self.conversation = swarmInfo.conversation
        self.swarmInfo.finalAvatar
            .subscribe(onNext: { [weak self] newValue in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.finalAvatar = newValue
                }
            })
            .disposed(by: disposeBag)
        self.swarmInfo.finalTitle
            .subscribe(onNext: { [weak self] newValue in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.finalTitle = newValue
                }
            })
            .disposed(by: disposeBag)
        self.swarmInfo.color
            .subscribe(onNext: { [weak self] newValue in
                DispatchQueue.main.async {
                    guard let self = self, !newValue.isEmpty else { return }
                    self.finalColor = newValue
                    if Constants.swarmColors.contains(newValue) {
                        self.selectedColor = newValue
                    } else {
                        self.selectedColor = String()
                    }
                    self.navBarColor.accept(newValue)
                }
            })
            .disposed(by: disposeBag)
        if !shouldTriggerDescriptionDidSet {
            description = swarmInfo.description.value
            title = swarmInfo.title.value
            shouldTriggerDescriptionDidSet = true
        }
    }

    func updateSwarmInfo() {
        if let conversationId = conversation?.id,
           let accountId = conversation?.accountId {
            var conversationInfo = conversationService.getConversationInfo(conversationId: conversationId, accountId: accountId)
            conversationInfo[ConversationAttributes.description.rawValue] = description
            conversationInfo[ConversationAttributes.title.rawValue] = title
            self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: conversationInfo)
        }
    }

    func updateSwarmAvatar(image: UIImage?) {
        guard let image = image, let data = image.convertToDataForSwarm() else { return }
        if let conversationId = conversation?.id,
           let accountId = conversation?.accountId {
            var conversationInfo = conversationService.getConversationInfo(conversationId: conversationId, accountId: accountId)
            conversationInfo[ConversationAttributes.avatar.rawValue] = data.base64EncodedString()
            self.conversationService.updateConversationInfos(accountId: accountId, conversationId: conversationId, infos: conversationInfo)
            self.finalAvatar = image
        }
    }
    func updateSwarmColor(selectedColor: String) {
        if let conversationId = conversation?.id,
           let accountId = conversation?.accountId {
            let prefsInfo = conversationService.getConversationPreferences(accountId: accountId, conversationId: conversationId)
            guard var prefsInfo = prefsInfo else { return }
            prefsInfo[ConversationPreferenceAttributes.color.rawValue] = selectedColor
            self.conversationService.updateConversationPrefs(accountId: accountId, conversationId: conversationId, prefs: prefsInfo)
        }
    }
    func hideShowBackButton(colorPicker: Bool) {
        colorPickerStatus.accept(colorPicker)
    }
    func updateContactList () {
        self.swarmInfo.contacts
            .subscribe { [weak self] newValue in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.participantsRows = [ParticipantRow]()
                    for info in newValue {
                        let participant = ParticipantRow(participantData: info)
                        self.participantsRows.append(participant)
                    }
                }
            } onError: { _ in
            }
            .disposed(by: self.contactsSubscriptionsDisposeBag)
        injectionBag
            .contactsService
            .contacts
            .asObservable()
            .subscribe { [weak self] contacts in
                guard let self = self else { return }
                self.swarmInfo.addContacts(contacts: contacts)
            } onError: { _ in
            }
            .disposed(by: self.contactsSubscriptionsDisposeBag)
    }

    func removeExistingSubscription() {
        self.contactsSubscriptionsDisposeBag = DisposeBag()
    }

    func addMember() {
        for participant in selections {
            if let conversationId = conversation?.id,
               let accountId = conversation?.accountId {
                self.conversationService.addConversationMember(accountId: accountId, conversationId: conversationId, memberId: participant)
            }
        }
        selections.removeAll()
    }
    func removeMember(indexOffset: IndexSet) {
        let idDelete = indexOffset.map { swarmInfo.participants.value[$0].jamiId }
        if let conversationId = conversation?.id,
           let accountId = conversation?.accountId {
            _ = idDelete.compactMap { memberID in
                print(memberID)
                conversationService.removeConversationMember(accountId: accountId, conversationId: conversationId, memberId: memberID)
            }
        }
    }

    func leaveSwarm(stateEmmiter: SwarmInfoStateEmmiter) {
        guard let conversation = self.conversation else { return }
        let conversationId = conversation.id
        let accountId = conversation.accountId
        if conversation.isCoredialog(),
           let participantId = conversation.getParticipants().first?.jamiId {
            self.contactsService
                .removeContact(withId: participantId,
                               ban: true,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self] in
                    self?.conversationService
                        .removeConversationFromDB(conversation: conversation,
                                                  keepConversation: false)
                })
                .disposed(by: self.disposeBag)
        } else {
            self.conversationService.removeConversation(conversationId: conversationId, accountId: accountId)
        }
        stateEmmiter.emitState(newState: ConversationState.conversationRemoved)
    }

    func ignoreSwarm(isOn: Bool) {

    }
}
