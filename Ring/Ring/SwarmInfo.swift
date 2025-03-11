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

protocol SwarmInfoProtocol {
    var avatar: BehaviorRelay<UIImage?> { get set }
    var title: BehaviorRelay<String> { get set }
    var color: BehaviorRelay<String> { get set }
    var type: BehaviorRelay<ConversationType> { get set }
    var description: BehaviorRelay<String> { get set }
    var participantsNames: BehaviorRelay<[String]> { get set }
    var participantsAvatars: BehaviorRelay<[UIImage]> { get set }

    var avatarHeight: CGFloat { get set }
    var avatarSpacing: CGFloat { get set }

    var finalTitle: Observable<String> { get set }
    var participantsString: BehaviorRelay<String> { get set }

    var finalAvatar: Observable<UIImage> { get set }

    var participants: BehaviorRelay<[ParticipantInfo]> { get set }
    var contacts: BehaviorRelay<[ParticipantInfo]> { get set }
    var conversation: ConversationModel? { get set }
    var id: String { get set }

    func addContacts(contacts: [ContactModel])
    func hasParticipantWithRegisteredName(name: String) -> Bool
    func contains(searchQuery: String) -> Bool
}

class ParticipantInfo: Equatable, Hashable {

    var jamiId: String
    var role: ParticipantRole
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var registeredName = BehaviorRelay(value: "")
    var profileName = BehaviorRelay(value: "")
    var finalName = BehaviorRelay(value: "")
    let disposeBag = DisposeBag()
    var hasProfileAvatar = false

    init(jamiId: String, role: ParticipantRole) {
        self.jamiId = jamiId
        self.role = role
        self.finalName.accept(jamiId)
        self.finalName
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] name in
                guard let self = self else { return }
                // when profile does not have an avatar, contact image
                // should be updated each time when name changed.
                if !self.hasProfileAvatar, !name.isEmpty {

                    self.avatar.accept(UIImage.createContactAvatar(username: name, size: CGSize(width: 55, height: 55)))
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        Observable.combineLatest(self.registeredName.asObservable(),
                                 self.profileName.asObservable())
            .subscribe {[weak self] (registeredName, profileName) in
                guard let self = self else { return }
                let finalName = ContactsUtils.getFinalNameFrom(registeredName: registeredName, profileName: profileName, hash: self.jamiId)
                self.finalName.accept(finalName)

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
                guard let self = self else { return false }
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == self.jamiId
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self] lookupNameResponse in
                guard let self = self else { return }
                if let name = lookupNameResponse.name, !name.isEmpty, self.registeredName.value != name {
                    self.registeredName.accept(name)
                }
            })
            .disposed(by: self.disposeBag)
        nameService.lookupAddress(withAccount: accountId, nameserver: "", address: self.jamiId)
    }
}

class SwarmInfo: SwarmInfoProtocol {
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var title = BehaviorRelay(value: "")
    var color = BehaviorRelay<String>(value: "")
    var type = BehaviorRelay(value: ConversationType.oneToOne)
    var description = BehaviorRelay(value: "")
    var participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    var participantsAvatars: BehaviorRelay<[UIImage]> = BehaviorRelay(value: [UIImage()])

    var avatarHeight: CGFloat = 55
    var avatarSpacing: CGFloat = 2
    lazy var id: String = {
        return conversation?.id ?? ""
    }()

    lazy var finalTitle: Observable<String> = {
        return Observable
            .combineLatest(self.title.asObservable().startWith(self.title.value),
                           self.participantsNames.asObservable().startWith(self.participantsNames.value)) { [weak self] (title: String, names: [String]) -> String in
                guard let self = self else { return "" }
                if !title.isEmpty { return title }
                return self.buildTitleFrom(names: names)
            }
    }()

    var participantsString = BehaviorRelay(value: "")

    lazy var finalAvatar: Observable<UIImage> = {
        return Observable
            .combineLatest(self.avatar.asObservable().startWith(self.avatar.value),
                           self.participantsAvatars.asObservable().startWith(self.participantsAvatars.value)) { [weak self] (avatar: UIImage?, _: [UIImage]) -> UIImage in
                guard let self = self else {
                    return UIImage.createSwarmAvatar(convId: "", size: CGSize(width: 55, height: 55))
                }
                if let avatar = avatar { return avatar }
                return self.buildAvatar()
            }
    }()

    var participants = BehaviorRelay(value: [ParticipantInfo]()) // particiapnts already added to swarm
    var contacts = BehaviorRelay(value: [ParticipantInfo]()) // contacts that could be added to swarm
    var conversation: ConversationModel?

    private let nameService: NameService
    private let profileService: ProfilesService
    private let conversationsService: ConversationsService
    private let contactsService: ContactsService
    private let accountsService: AccountsService
    private let requestsService: RequestsService
    private let accountId: String
    private let localJamiId: String?
    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()

    // to get info during swarm creation
    init(injectionBag: InjectionBag, accountId: String, avatarHeight: CGFloat = 55) {
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
    convenience init(injectionBag: InjectionBag, conversation: ConversationModel, avatarHeight: CGFloat = 55) {
        self.init(injectionBag: injectionBag, accountId: conversation.accountId, avatarHeight: avatarHeight)
        self.conversation = conversation
        self.subscribeConversationEvents()
        self.updateInfo()
        self.setParticipants()
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

    func hasParticipantWithRegisteredName(name: String) -> Bool {
        return !self.participants.value.filter { participant in
            participant.registeredName.value == name.lowercased()
        }.isEmpty
    }

    func contains(searchQuery: String) -> Bool {
        if self.title.value.containsCaseInsensitive(string: searchQuery) { return true }
        return !self.participants.value.filter { participant in
            participant.registeredName.value.containsCaseInsensitive(string: searchQuery) ||
                participant.profileName.value.containsCaseInsensitive(string: searchQuery) || participant.jamiId.containsCaseInsensitive(string: searchQuery)
        }.isEmpty
    }

    private func subscribeParticipantsInfo() {
        tempBag = DisposeBag()

        guard !participants.value.isEmpty else { return }

        let isDialog = conversation?.isDialog() ?? false

        // Create a single shared observable for all participant data
        // swiftlint:disable large_tuple
        let participantData = Observable.combineLatest(
            participants.value.map { participant -> Observable<(String, String, String, UIImage?)> in
                return Observable.combineLatest(
                    participant.finalName.asObservable(),
                    participant.registeredName.asObservable(),
                    participant.profileName.asObservable(),
                    participant.avatar.asObservable()
                )
            }
        )
        .share(replay: 1)
        // swiftlint:enable large_tuple

        participantData
            .subscribe(onNext: { [weak self] data in
                guard let self = self else { return }

                let finalNames = data.map { $0.0 }.filter { !$0.isEmpty }
                let registeredNames = data.map { $0.1 }.filter { !$0.isEmpty }
                let profileNames = data.map { $0.2 }.filter { !$0.isEmpty }
                let avatars = data.map { $0.3 }.compactMap { $0 }

                self.participantsAvatars.accept(avatars)

                if isDialog {
                    self.participantsNames.accept(Array(Set(finalNames)))
                    self.participantsString.accept(self.buildTitleFrom(names: Array(Set(registeredNames))))

                    if self.title.value.isEmpty, let name = profileNames.first {
                        self.title.accept(name)
                    }
                } else {
                    let uniqueNames = Array(Set(finalNames))
                    self.participantsNames.accept(uniqueNames)
                    self.participantsString.accept(self.buildTitleFrom(names: uniqueNames))
                }
            })
            .disposed(by: tempBag)
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
                self?.updateColorPreference()
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
            // The view has a size of avatarHeight. Create a larger image for better resolution.
            self.avatar.accept(avatar.createImage(size: self.avatarHeight * 2))
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
        self.color.accept(conversation.preferences.color)
    }

    private func setParticipants() {
        guard let conversation = self.conversation else { return }
        var participantsInfo = [ParticipantInfo]()
        let memberList = conversation.getAllParticipants()
        memberList.forEach { participant in
            if let participantInfo = createParticipant(jamiId: participant.jamiId, role: participant.role) {
                participantsInfo.append(participantInfo)
            }
        }
        if participantsInfo.isEmpty { return }
        self.insertAndSortParticipants(participants: participantsInfo)
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
        let uri = JamiURI.init(schema: .ring, infoHash: jamiId)
        guard let uriString = uri.uriString else { return nil }
        // subscribe for profile updates for participant
        self.profileService
            .getProfile(uri: uriString, createIfNotexists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak participantInfo] profile in
                guard let participantInfo = participantInfo else { return }
                // The view has a size of avatarHeight. Create a larger image for better resolution.
                if let imageString = profile.photo, let image = imageString.createImage(size: self.avatarHeight * 2) {
                    participantInfo.avatar.accept(image)
                    participantInfo.hasProfileAvatar = true
                }
                if let profileName = profile.alias, !profileName.isEmpty {
                    participantInfo.profileName.accept(profileName)
                }
            } onError: { _ in
            }
            .disposed(by: participantInfo.disposeBag)
        participantInfo.lookupName(nameService: self.nameService, accountId: self.accountId)
        return participantInfo
    }

    private func insertAndSortContacts(contacts: [ParticipantInfo]) {
        var currentValue = [ParticipantInfo]()
        currentValue.append(contentsOf: contacts)
        self.contacts.accept(currentValue)
    }

    private func insertAndSortParticipants(participants: [ParticipantInfo]) {
        var currentValue = [ParticipantInfo]()
        currentValue.append(contentsOf: participants)
        currentValue = currentValue.filter({ [.invited, .member, .admin].contains($0.role) })
        currentValue.sort { participant1, participant2 in
            if participant1.role == participant2.role {
                return participant1.finalName.value > participant2.finalName.value
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
        // for conversation with one participant return contact avatar
        if participantsCount == 1, let avatar = self.participants.value.first?.avatar.value {
            return avatar
        }
        var convId = ""
        if let conv = self.conversation {
            convId = conv.id
        }
        if participantsCount == 2, let localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId,
           let avatar = self.participants.value.filter({ info in
            return info.jamiId != localJamiId
           }).first?.avatar.value {
            return avatar
        }
        return UIImage.createSwarmAvatar(convId: convId, size: CGSize(width: self.avatarHeight, height: self.avatarHeight))
    }

    private func buildTitleFrom(names: [String]) -> String {
        // title format: "name1, name2, name3 + number of other participants"
        let participantsCount = self.participants.value.count
        // for one to one conversation return contact name
        if participantsCount == 2, let localJamiId = self.localJamiId,
           let name = self.participants.value.filter({ info in
            return info.jamiId != localJamiId
           }).first?.finalName.value {
            return name
        }
        // replaece local name with "me"
        var localName = ""
        if let localJamiId = self.localJamiId,
           let name = self.participants.value.filter({ info in
            return info.jamiId == localJamiId
           }).first?.finalName.value {
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
