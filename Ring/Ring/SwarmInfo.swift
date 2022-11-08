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
    var hasProfileAvatar = false

    init(jamiId: String, role: ParticipantRole) {
        self.jamiId = jamiId
        self.role = role
        self.name.subscribe { [weak self] name in
            guard let self = self else { return }
            // when profile does not have an avatar, contact image
            // should be updated each time when name changed.
            if !self.hasProfileAvatar {
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

    var avatarHeight: CGFloat = 40
    var avatarSpacing: CGFloat = 2

    lazy var finalTitle: Observable<String> = {
        return Observable
            .combineLatest(self.title.asObservable(), self.participantsNames.asObservable()) { [weak self] (title: String, names: [String]) -> String in
                guard let self = self else { return "" }
                if !title.isEmpty { return title }
                return self.buildTitleFrom(names: names)
            }
    }()

    lazy var finalAvatar: Observable<UIImage> = {
        return Observable
            .combineLatest(self.avatar.asObservable(), self.participantsAvatars.asObservable()) { [weak self] (avatar: UIImage?, avatars: [UIImage]) -> UIImage in
                guard let self = self else { return UIImage() }
                if let avatar = avatar { return avatar }
                return self.buildAvatarFrom(avatars: avatars)
            }
    }()

    var participants = BehaviorRelay(value: [ParticipantInfo]()) // particiapnts already added to swarm
    var contacts = BehaviorRelay(value: [ParticipantInfo]()) // contacts that could be added to swarm

    private let nameService: NameService
    private let profileService: ProfilesService
    private let conversationsService: ConversationsService
    private let requestsService: RequestsService
    private let accountId: String
    private var conversation: ConversationModel?
    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()

    // to get info during swarm creation
    init(injectionBag: InjectionBag, accountId: String) {
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
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
        self.conversation = conversation
        self.subscribeConversationEvents()
        self.updateInfo()
        self.updateParticipants()
    }

    func addContacts(contacts: [ContactModel]) {
        var contactsInfo = [ParticipantInfo]()
        let requests = self.requestsService.requests.value
        contacts.forEach { contact in
            let requestIndex = requests.firstIndex(where: { request in
                request.participants.contains { participant in
                    participant.jamiId == contact.hash
                }
            })
            // filter out banned and pending contacts
            if contact.banned || requestIndex != nil { return }
            // filter out contact that is already added to swarm participants
            if self.participants.value.filter({ participantInfo in
                participantInfo.jamiId == contact.hash
            }).first != nil {
                return
            }
            if let contactInfo = createParticipant(jamiId: contact.hash, role: ParticipantRole.unknown) {
                contactsInfo.append(contactInfo)
            }
        }
        if contactsInfo.isEmpty { return }
        self.insertAndSortContacts(contacts: contactsInfo)
    }

    func addContactToParticipantsList(jamiId: String, role: ParticipantRole) {
        // remove from contacts list
        var contactsValue = contacts.value
        if let index = contactsValue.firstIndex(where: { contactInfo in
            contactInfo.jamiId == jamiId
        }) {
            contactsValue.remove(at: index)
            contacts.accept(contactsValue)
        }
        // add to participants list
        guard let participantInfo = createParticipant(jamiId: jamiId, role: role) else { return }
        insertAndSortParticipants(participants: [participantInfo])
    }

    func addContactToParticipantsList(participantInfo: ParticipantInfo, role: ParticipantRole) {
        // remove from contacts list
        var contactsValue = contacts.value
        if let index = contactsValue.firstIndex(where: { contactInfo in
            contactInfo.jamiId == participantInfo.jamiId
        }) {
            contactsValue.remove(at: index)
            contacts.accept(contactsValue.sorted(by: { $0.name.value > $1.name.value }))
        }
        // add to participants list
        participantInfo.role = role
        insertAndSortParticipants(participants: [participantInfo])
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
        // filter out default avatars
        let avatarsObservable = participants.value
            .filter({ participantInfo in
                participantInfo.jamiId != participantInfo.name.value
            })
            .map({ participantInfo in
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

    private func subscribeConversationEvents() {
        self.conversationsService
            .sharedResponseStream
            .filter({ [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.conversationProfileUpdated &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.accountId &&
                    event.getEventInput(ServiceEventInput.conversationId) == self?.conversation?.id
            })
            .subscribe {[weak self] _ in
                self?.updateInfo()
            } onError: { _ in
            }.disposed(by: self.disposeBag)

        self.conversationsService
            .sharedResponseStream
            .filter({ [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.conversationMemberEvent &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.accountId &&
                    event.getEventInput(ServiceEventInput.conversationId) == self?.conversation?.id
            })
            .subscribe {[weak self] _ in
                self?.updateParticipants()
            } onError: { _ in
            }.disposed(by: self.disposeBag)
    }

    private func updateInfo() {
        guard let conversation = self.conversation else { return }
        let info = self.conversationsService.getConversationInfo(conversationId: conversation.id, accountId: self.accountId)
        if let avatar = info[ConversationAttributes.avatar.rawValue] {
            self.avatar.accept(avatar.createImage())
        }
        if let title = info[ConversationAttributes.title.rawValue], !title.isEmpty {
            self.title.accept(title)
        }
        if let description = info[ConversationAttributes.description.rawValue] {
            self.description.accept(description)
        }
    }

    private func updateParticipants() {
        guard let conversation = self.conversation else { return }
        var participantsInfo = [ParticipantInfo]()
        self.insertAndSortParticipants(participants: participantsInfo)
        conversation.getParticipants().forEach { participant in
            if let participantInfo = createParticipant(jamiId: participant.jamiId, role: participant.role) {
                participantsInfo.append(participantInfo)
            }
        }
        if participantsInfo.isEmpty { return }
        self.insertAndSortParticipants(participants: participantsInfo)
    }

    private func createParticipant(jamiId: String, role: ParticipantRole) -> ParticipantInfo? {
        let participantInfo = ParticipantInfo(jamiId: jamiId, role: role)
        let uri = JamiURI.init(schema: .ring, infoHach: jamiId)
        guard let uriString = uri.uriString else { return nil}
        // subscribe for profile updates for participant
        self.profileService
            .getProfile(uri: uriString, createIfNotexists: false, accountId: accountId)
            .subscribe { [weak self, weak participantInfo] profile in
                guard let self = self, let participantInfo = participantInfo else { return }
                if let imageString = profile.photo, let image = imageString.createImage() {
                    participantInfo.avatar.accept(image)
                    participantInfo.hasProfileAvatar = true
                }
                if let profileName = profile.alias, !profileName.isEmpty {
                    participantInfo.name.accept(profileName)
                }
                if participantInfo.avatar.value == nil || participantInfo.name.value.isEmpty {
                    participantInfo.name.accept(jamiId)
                    self.lookupNameFor(participant: participantInfo)
                }
            } onError: { _ in
            }
            .disposed(by: participantInfo.disposeBag)
        return participantInfo
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

    private func insertAndSortContacts(contacts: [ParticipantInfo]) {
        var currentValue = self.contacts.value
        currentValue.append(contentsOf: contacts)
        self.contacts.accept(currentValue.sorted(by: { $0.name.value > $1.name.value }))
    }

    private func insertAndSortParticipants(participants: [ParticipantInfo]) {
        var currentValue = self.participants.value
        currentValue.append(contentsOf: participants)
        self.participants.accept(currentValue.sorted(by: { $0.name.value > $1.name.value }))
    }

    private func buildAvatarFrom(avatars: [UIImage]) -> UIImage {
        if avatars.count < 2 {
            UIImage(asset: Asset.icContactPicture)!
                .withAlignmentRectInsets(UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        }
        return UIImage.mergeImages(image1: avatars[0], image2: avatars[1], spacing: avatarSpacing, height: avatarHeight)
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
