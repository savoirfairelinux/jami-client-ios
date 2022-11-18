/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import RxRelay

class ParticipantInfo {
    var jamiId: String
    var role: ParticipantRole
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var name = BehaviorRelay(value: "")
    let disposeBag = DisposeBag()

    init(jamiId: String, role: ParticipantRole) {
        self.jamiId = jamiId
        self.role = role
        self.name.subscribe { [weak self] name in
            guard let self = self else { return }
            if self.avatar.value == nil {
                self.avatar.accept(UIImage.createContactAvatar(username: name))
            }
        } onError: { _ in
        }
        .disposed(by: self.disposeBag)
    }
}

class SwarmInfo {
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var title = BehaviorRelay(value: "")
    var description = BehaviorRelay(value: "")
    var participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    var participantsAvatars: BehaviorRelay<[UIImage]> = BehaviorRelay(value: [UIImage()])

    lazy var finalTitle: Observable<String> = {
        return Observable
            .combineLatest(self.title.asObservable(), self.participantsNames.asObservable()) { (title: String, names: [String]) -> String in
                if !title.isEmpty { return title }
                return self.buildTitleFrom(names: names)
            }
    }()

    var participants = BehaviorRelay(value: [ParticipantInfo]()) // particiapnts already added to swarm
    var contacts = BehaviorRelay(value: [ParticipantInfo]()) // contacts that could be added to swarm

    private let nameService: NameService
    private let profileService: ProfilesService
    private let accountId: String
    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()

    // to get info during swarm creation
    init(injectionBag: InjectionBag, accountId: String) {
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.accountId = accountId
        self.participants
            .subscribe {[weak self] _ in
                guard let self = self else { return }
                self.subscribeParticipantsInfo()
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    // to get info for existing swarm
    convenience init(injectionBag: InjectionBag, conversation: ConversationModel) {
        self.init(injectionBag: injectionBag, accountId: conversation.accountId)
        let info = injectionBag.conversationsService.getConversationInfo(conversationId: conversation.id, accountId: conversation.accountId)
        if let avatar = info[ConversationAttributes.avatar.rawValue] {
            self.avatar.accept(avatar.toImage())
        }
        if let title = info[ConversationAttributes.title.rawValue], !title.isEmpty {
            self.title.accept(title)
        }
        if let description = info[ConversationAttributes.description.rawValue] {
            self.description.accept(description)
        }
        conversation.getParticipants().forEach { participant in
            self.insertParticipant(list: self.participants, jamiId: participant.jamiId, role: participant.role)
        }
    }

    func addContacts(contacts: [ContactModel]) {
        contacts.forEach { contact in
            self.insertParticipant(list: self.contacts, jamiId: contact.hash, role: ParticipantRole.unknown)
        }
    }

    func addContactToParticipantsList(jamiId: String) {
        var contactsValue = contacts.value
        if let index = contactsValue.firstIndex(where: { contactInfo in
            contactInfo.jamiId == jamiId
        }) {
            contactsValue.remove(at: index)
            contacts.accept(contactsValue)
        }
        self.insertParticipant(list: self.participants, jamiId: jamiId, role: ParticipantRole.unknown)
    }

    func addContactToParticipantsList(participantInfo: ParticipantInfo) {
        var contactsValue = contacts.value
        if let index = contactsValue.firstIndex(where: { contactInfo in
            contactInfo.jamiId == participantInfo.jamiId
        }) {
            contactsValue.remove(at: index)
            contacts.accept(contactsValue.sorted(by: { $0.name.value > $1.name.value }))
        }
        insertAndSort(list: participants, participant: participantInfo)
    }

    private func subscribeParticipantsInfo() {
        tempBag = DisposeBag()
        let namesObservable = participants.value.map({ participantInfo in
            return participantInfo.name.asObservable()
        })
        Observable
            .combineLatest(namesObservable) { (items: [String]) -> [String] in
                return items.filter { name in
                    !name.isEmpty
                }
            }
            .subscribe { [weak self] names in
                guard let self = self else { return }
                self.participantsNames.accept(names)
            } onError: { _ in
            }
            .disposed(by: self.tempBag)

        let avatarsObservable = participants.value.map({ participantInfo in
            return participantInfo.avatar.asObservable()
        })
        Observable
            .combineLatest(avatarsObservable) { (items: [UIImage?]) -> [UIImage] in
                return items.compactMap { $0 }
            }
            .subscribe { [weak self] avatars in
                guard let self = self else { return }
                self.participantsAvatars.accept(avatars)
            } onError: { _ in
            }
            .disposed(by: self.tempBag)
    }

    private func insertParticipant(list: BehaviorRelay<[ParticipantInfo]>, jamiId: String, role: ParticipantRole) {
        let participantInfo = ParticipantInfo(jamiId: jamiId, role: role)
        let uri = JamiURI.init(schema: .ring, infoHach: jamiId)
        guard let uriString = uri.uriString else { return }
        // subscribe for profile updates for participant
        self.profileService
            .getProfile(uri: uriString, createIfNotexists: false, accountId: accountId)
            .subscribe { [weak self, weak participantInfo] profile in
                guard let self = self, let participantInfo = participantInfo else { return }
                if let imageString = profile.photo, let image = imageString.toImage() {
                    participantInfo.avatar.accept(image)
                }
                if let profileName = profile.alias, !profileName.isEmpty {
                    participantInfo.name.accept(profileName)
                }
                if participantInfo.avatar.value == nil || participantInfo.name.value.isEmpty {
                    self.lookupNameFor(participant: participantInfo)
                }
            } onError: { _ in
            }
            .disposed(by: participantInfo.disposeBag)
        insertAndSort(list: participants, participant: participantInfo)
    }

    private func lookupNameFor(participant: ParticipantInfo) {
        self.nameService.usernameLookupStatus
            .filter({ lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == participant.jamiId
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak participant] lookupNameResponse in
                guard let participant = participant else { return }
                if let name = lookupNameResponse.name, !name.isEmpty {
                    participant.name.accept(name)
                } else {
                    participant.name.accept(participant.jamiId)
                }
            })
            .disposed(by: participant.disposeBag)
        self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: participant.jamiId)
    }

    private func insertAndSort(list: BehaviorRelay<[ParticipantInfo]>, participant: ParticipantInfo) {
        var currentValue = list.value
        currentValue.append(participant)
        list.accept(currentValue.sorted(by: { $0.name.value > $1.name.value }))
    }

    private func buildTitleFrom(names: [String]) -> String {
        // title format: "name1, name2, name3 + number of other participants"
        let participantsCount = self.participants.value.count
        var finalTitle = ""
        if names.isEmpty { return finalTitle }
        // maximum 3 names could be displayed
        let numberOfDisplayedNames: Int = names.count < 3 ? names.count : 3
        // number of participants not included in title
        let otherParticipantsCount = participantsCount - numberOfDisplayedNames
        let titleEnd = otherParticipantsCount > 0 ? ", + \(otherParticipantsCount)" : ""
        finalTitle = names[0]
        for index in 1...(numberOfDisplayedNames - 1) {
            finalTitle += " , " + names[index]
        }
        finalTitle += titleEnd
        return finalTitle
    }
}
