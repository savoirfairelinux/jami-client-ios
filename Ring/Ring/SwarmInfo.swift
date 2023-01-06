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

class ParticipantInfo: Equatable, Hashable {

    var jamiId: String
    var role: ParticipantRole
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var name = BehaviorRelay(value: "")
    let disposeBag = DisposeBag()
    var hasProfileAvatar = false

    init(jamiId: String, role: ParticipantRole) {
        self.jamiId = jamiId
        self.role = role
        self.name
            .subscribe { [weak self] name in
                guard let self = self else { return }
                // when profile does not have an avatar, contact image
                // should be updated each time when name changed.
                if !self.hasProfileAvatar, !name.isEmpty {
                    if jamiId == name && self.avatar.value != nil {
                        return
                    }
                    self.avatar.accept(UIImage.createContactAvatar(username: name, size: CGSize(width: 40, height: 40)))
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    static func == (lhs: ParticipantInfo, rhs: ParticipantInfo) -> Bool {
        return rhs.jamiId == lhs.jamiId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(jamiId)
    }

    func lookupName(nameService: NameService, accountId: String) {
        nameService.usernameLookupStatus.share()
            .filter({ [weak self] lookupNameResponse in
                guard let self = self else { return false}
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == self.jamiId
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self] lookupNameResponse in
                guard let self = self else { return }
                if let name = lookupNameResponse.name, !name.isEmpty, self.name.value != name {
                    self.name.accept(name)
                }
            })
            .disposed(by: self.disposeBag)
        nameService.lookupAddress(withAccount: accountId, nameserver: "", address: self.jamiId)
    }
}

class SwarmInfo {
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var title = BehaviorRelay(value: "")
    var color = BehaviorRelay<String>(value: "")
    var type = BehaviorRelay(value: ConversationType.oneToOne)
    var description = BehaviorRelay(value: "")
    var participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    var participantsAvatars: BehaviorRelay<[UIImage]> = BehaviorRelay(value: [UIImage()])

    var avatarHeight: CGFloat = 40
    var avatarSpacing: CGFloat = 2
    var defaultColor = "#00BCD4"
    var id: String {
        return conversation?.id ?? ""
    }

    lazy var finalTitle: Observable<String> = {
        return Observable
            .combineLatest(self.title.asObservable().startWith(self.title.value),
                           self.participantsNames.asObservable().startWith(self.participantsNames.value)) { [weak self] (title: String, names: [String]) -> String in
                guard let self = self else { return "" }
                if !title.isEmpty { return title }
                return self.buildTitleFrom(names: names)
            }
    }()

    lazy var finalAvatar: Observable<UIImage> = {
        return Observable
            .combineLatest(self.avatar.asObservable().startWith(self.avatar.value),
                           self.participantsAvatars.asObservable().startWith(self.participantsAvatars.value)) { [weak self] (avatar: UIImage?, _: [UIImage]) -> UIImage in
                guard let self = self else { return UIImage.createGroupAvatar(username: "", size: CGSize(width: 60, height: 60)) }
                if let avatar = avatar { return avatar }
                return self.buildAvatar()
            }
    }()

    var participants = BehaviorRelay(value: [ParticipantInfo]()) // particiapnts already added to swarm
    var contacts = BehaviorRelay(value: [ParticipantInfo]()) // contacts that could be added to swarm

    private let nameService: NameService
    private let profileService: ProfilesService
    private let conversationsService: ConversationsService
    private let contactsService: ContactsService
    private let accountsService: AccountsService
    private let requestsService: RequestsService
    private let accountId: String
    private let localJamiId: String?
    private var conversation: ConversationModel?
    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()

    // to get info during swarm creation
    init(injectionBag: InjectionBag, accountId: String, avatarHeight: CGFloat = 40) {
        self.avatarHeight = avatarHeight
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.conversationsService = injectionBag.conversationsService
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.accountService
        self.requestsService = injectionBag.requestsService
        self.accountId = accountId
        self.localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId
        self.participants
            .subscribe {[weak self] _ in
                guard let self = self else { return }
                self.subscribeParticipantsInfo()
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    // to get info for existing swarm
    convenience init(injectionBag: InjectionBag, conversation: ConversationModel, avatarHeight: CGFloat = 40) {
        self.init(injectionBag: injectionBag, accountId: conversation.accountId, avatarHeight: avatarHeight)
        self.conversation = conversation
        self.subscribeConversationEvents()
        self.updateInfo()
        self.updateParticipants()
        self.updateColorPreference()
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
        let namesObservable = participants.value
            .map({ participantInfo in
                return participantInfo.name.share().asObservable()
            })
        Observable
            .combineLatest(namesObservable) { (items: [String]) -> [String] in
                return items.filter { name in
                    !name.isEmpty
                }
            }
            .subscribe { [weak self] names in
                guard let self = self else { return }
                self.participantsNames.accept(Array(Set(names)))
            } onError: { _ in
            }
            .disposed(by: self.tempBag)
        // filter out default avatars
        let avatarsObservable = participants.value
            .map({ participantInfo in
                return participantInfo.avatar.share().asObservable()
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
                return event.eventType == ServiceEventType.conversationPreferencesUpdated &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.accountId &&
                    event.getEventInput(ServiceEventInput.conversationId) == self?.conversation?.id
            })
            .subscribe {[weak self] _ in
                DispatchQueue.global(qos: .background).async {
                    self?.updateColorPreference()
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        self.conversationsService
            .sharedResponseStream
            .filter({ [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.conversationProfileUpdated &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.accountId &&
                    event.getEventInput(ServiceEventInput.conversationId) == self?.conversation?.id
            })
            .subscribe {[weak self] _ in
                DispatchQueue.global(qos: .background).async {
                    self?.updateInfo()
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)

        self.conversationsService
            .sharedResponseStream
            .filter({ [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.conversationMemberEvent &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.accountId &&
                    event.getEventInput(ServiceEventInput.conversationId) == self?.conversation?.id
            })
            .subscribe {[weak self] _ in
                DispatchQueue.global(qos: .background).async {
                    self?.updateParticipants()
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func updateInfo() {
        guard let conversation = self.conversation else { return }
        let info = self.conversationsService.getConversationInfo(conversationId: conversation.id, accountId: self.accountId)
        if let avatar = info[ConversationAttributes.avatar.rawValue] {
            self.avatar.accept(avatar.createImage())
        }
        if let title = info[ConversationAttributes.title.rawValue] {
            self.title.accept(title)
        }
        if let description = info[ConversationAttributes.description.rawValue] {
            self.description.accept(description)
        }
    }
    private func updateColorPreference() {
        guard let conversation = self.conversation else { return }
        let info = self.conversationsService.getConversationPreferences(accountId: self.accountId, conversationId: conversation.id)
        guard let info = info else { return }
        if let color = info[ConversationPreferenceAttributes.color.rawValue] {
            self.color.accept(color)
        }
    }
    private func updateParticipants() {
        guard let conversation = self.conversation else { return }
        var participantsInfo = [ParticipantInfo]()
        self.participants.accept(participantsInfo)
        self.insertAndSortParticipants(participants: participantsInfo)
        if let localJamiId = self.localJamiId {
            let memberList = conversationsService.getSwarmMembers(conversationId: conversation.id, accountId: accountId, accountURI: localJamiId)
            memberList.forEach { participant in
                if let participantInfo = createParticipant(jamiId: participant.jamiId, role: participant.role) {
                    participantsInfo.append(participantInfo)
                }
            }
        }
        if participantsInfo.isEmpty { return }
        self.insertAndSortParticipants(participants: participantsInfo)
    }

    private func createParticipant(jamiId: String, role: ParticipantRole) -> ParticipantInfo? {
        let participantInfo = ParticipantInfo(jamiId: jamiId, role: role)
        let uri = JamiURI.init(schema: .ring, infoHach: jamiId)
        guard let uriString = uri.uriString else { return nil}
        if self.contactsService.contact(withHash: jamiId) != nil {
            // subscribe for profile updates for participant
            self.profileService
                .getProfile(uri: uriString, createIfNotexists: false, accountId: accountId)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
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
                        if participantInfo.name.value.isEmpty {
                            participantInfo.name.accept(jamiId)
                        }
                        participantInfo.lookupName(nameService: self.nameService, accountId: self.accountId)
                    }
                } onError: { _ in
                }
                .disposed(by: participantInfo.disposeBag)
        } else {
            participantInfo.name.accept(jamiId)
            participantInfo.lookupName(nameService: self.nameService, accountId: self.accountId)
        }
        return participantInfo
    }

    private func insertAndSortContacts(contacts: [ParticipantInfo]) {
        var currentValue = self.contacts.value
        currentValue.append(contentsOf: contacts)
        self.contacts.accept(currentValue)
    }

    private func insertAndSortParticipants(participants: [ParticipantInfo]) {
        var currentValue = self.participants.value
        currentValue.append(contentsOf: participants)
        currentValue = currentValue.filter({ [.invited, .member, .admin].contains($0.role) })
        currentValue.sort { participant1, participant2 in
            if participant1.role == participant2.role {
                return participant1.name.value > participant2.name.value
            } else {
                switch participant1.role {
                case .admin:
                    return true
                case .member:
                    if participant2.role == .admin {
                        return false
                    } else {
                        return true
                    }
                default:
                    return false
                }
            }
        }
        self.participants.accept(currentValue)
    }

    private func buildAvatar() -> UIImage {
        let participantsCount = self.participants.value.count
        // for one to one conversation return contact avatar
        if participantsCount == 2, let localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId,
           let avatar = self.participants.value.filter({ info in
            return info.jamiId != localJamiId
           }).first?.avatar.value {
            return avatar
        }
        let avatars = self.participants.value.filter { participant in
            participant.hasProfileAvatar && (participant.jamiId != self.localJamiId ?? "")
        }
        .map { participant in
            return participant.avatar
        }
        if avatars.count >= 2, let firstImage = avatars[0].value, let secondImage = avatars[1].value {
            return UIImage.mergeImages(image1: firstImage, image2: secondImage, spacing: avatarSpacing, height: avatarHeight)
        }
        return UIImage.createGroupAvatar(username: self.title.value, size: CGSize(width: self.avatarHeight, height: self.avatarHeight))
    }

    private func buildTitleFrom(names: [String]) -> String {
        // title format: "name1, name2, name3 + number of other participants"
        let participantsCount = self.participants.value.count
        // for one to one conversation return contact name
        if participantsCount == 2, let localJamiId = self.localJamiId,
           let name = self.participants.value.filter({ info in
            return info.jamiId != localJamiId
           }).first?.name.value {
            return name
        }
        // replaece local name with "me"
        var localName = ""
        if let localJamiId = self.localJamiId,
           let name = self.participants.value.filter({ info in
            return info.jamiId == localJamiId
           }).first?.name.value {
            localName = name
        }
        var namesVariable = names
        if let index = namesVariable.firstIndex(where: { currentName in
            currentName == localName
        }), !localName.isEmpty {
            namesVariable.remove(at: index)
            namesVariable.append(L10n.Account.me)
        }
        let sorted = namesVariable.sorted { name1, name2 in
            name1.count < name2.count
        }
        let namesSet = Array(Set(sorted))
        var finalTitle = ""
        if namesSet.isEmpty { return finalTitle }
        // maximum 3 names could be displayed
        let numberOfDisplayedNames: Int = namesSet.count < 3 ? namesSet.count : 3
        // number of participants not included in title
        let otherParticipantsCount = participantsCount - numberOfDisplayedNames
        let titleEnd = otherParticipantsCount > 0 ? ", + \(otherParticipantsCount)" : ""
        finalTitle = namesSet[0]
        if numberOfDisplayedNames != 1 {
            for index in 1...(numberOfDisplayedNames - 1) {
                finalTitle += ", " + namesSet[index]
            }
        }
        finalTitle += titleEnd
        return finalTitle
    }
}
