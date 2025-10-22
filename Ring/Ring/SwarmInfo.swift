/*
 * Copyright (C) 2022-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import RxRelay

protocol SwarmInfoProtocol {
    var avatarData: BehaviorRelay<Data?> { get set }
    var title: BehaviorRelay<String> { get set }
    var color: BehaviorRelay<String> { get set }
    var type: BehaviorRelay<ConversationType> { get set }
    var description: BehaviorRelay<String> { get set }
    var participantsNames: BehaviorRelay<[String]> { get set }
    var participantsAvatars: BehaviorRelay<[Data]> { get set }

    var avatarHeight: CGFloat { get set }
    var avatarSpacing: CGFloat { get set }

    var finalTitle: BehaviorRelay<String> { get set }
    var participantsString: BehaviorRelay<String> { get set }

    var finalAvatarData: Observable<Data?> { get set }

    var participants: BehaviorRelay<[ParticipantInfo]> { get set }
    var contacts: BehaviorRelay<[ParticipantInfo]> { get set }
    var conversation: ConversationModel? { get set }
    var conversationEnded: BehaviorRelay<Bool> { get set }
    var id: String { get set }

    func addContacts(contacts: [ContactModel])
    func hasParticipantWithRegisteredName(name: String) -> Bool
    func contains(searchQuery: String) -> Bool
}

struct ParticipantData: Equatable, Hashable {
    var jamiId: String
    var role: ParticipantRole
}

class ParticipantInfo: Equatable, Hashable {

    var jamiId: String
    var role: ParticipantRole
    var avatarData: BehaviorRelay<Data?> = BehaviorRelay(value: nil)
    var registeredName = BehaviorRelay(value: "")
    var profileName = BehaviorRelay(value: "")
    var finalName = BehaviorRelay(value: "")
    let disposeBag = DisposeBag()
    let profileService: ProfilesService

    var hasProfileAvatar = false

    let profileLock = NSLock()

    let provider: AvatarProvider

    init(jamiId: String, role: ParticipantRole, profileService: ProfilesService) {
        self.profileService = profileService
        self.jamiId = jamiId
        self.role = role
        self.finalName.accept(jamiId)
        self.registeredName.accept(jamiId)
        provider = AvatarProvider(
            profileService: profileService,
            size: Constants.AvatarSize.default55,
            avatar: avatarData.asObservable(),
            displayName: finalName.asObservable(),
            isGroup: false
        )
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
                return lookupNameResponse.requestedName != nil &&
                    lookupNameResponse.requestedName == self.jamiId
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

// swiftlint:disable type_body_length
class SwarmInfo: SwarmInfoProtocol {
    var avatarData: BehaviorRelay<Data?> = BehaviorRelay(value: nil)
    var title = BehaviorRelay(value: "")
    var color = BehaviorRelay<String>(value: "")
    var type = BehaviorRelay(value: ConversationType.oneToOne)
    var description = BehaviorRelay(value: "")
    var participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    var participantsAvatars: BehaviorRelay<[Data]> = BehaviorRelay(value: [Data()])
    var conversationEnded: BehaviorRelay<Bool> = BehaviorRelay(value: false)

    var avatarHeight: CGFloat = Constants.defaultAvatarSize
    var avatarSpacing: CGFloat = 2
    lazy var id: String = {
        return conversation?.id ?? ""
    }()

    var finalTitle = BehaviorRelay<String>(value: "")
    var participantsString = BehaviorRelay(value: "")

    lazy var finalAvatarData: Observable<Data?> = {
        return Observable
            .combineLatest(self.avatarData.asObservable().startWith(self.avatarData.value),
                           self.participantsAvatars.asObservable().startWith(self.participantsAvatars.value)) { [weak self] (avatar: Data?, _: [Data]) -> Data? in
                guard let self = self else {
                    return nil
                }
                if let avatar = avatar { return avatar }
                return self.buildAvatar()
            }
    }()

    var participants = BehaviorRelay(value: [ParticipantInfo]()) // particiapnts already added to swarm
    var nonLocalParticipants: [ParticipantInfo] {
        return participants.value.filter { $0.jamiId != localJamiId }
    }
    var localParticipant: ParticipantInfo? {
        return participants.value.first { $0.jamiId == localJamiId }
    }
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
    init(injectionBag: InjectionBag, accountId: String, avatarHeight: CGFloat = Constants.defaultAvatarSize) {
        self.avatarHeight = avatarHeight
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.conversationsService = injectionBag.conversationsService
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.accountService
        self.requestsService = injectionBag.requestsService
        self.accountId = accountId
        self.localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId

        Observable
            .combineLatest(self.title.asObservable(),
                           self.participantsNames.asObservable()) { [weak self] (title: String, names: [String]) -> String in
                guard let self = self else { return "" }
                if !title.isEmpty { return title }
                return self.buildTitleFrom(names: names)
            }
            .subscribe(onNext: { [weak self] title in
                self?.finalTitle.accept(title)
            })
            .disposed(by: self.disposeBag)

        self.participants
            .subscribe {[weak self] _ in
                guard let self = self else { return }
                self.subscribeParticipantsInfo()
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    // to get info for existing swarm
    convenience init(injectionBag: InjectionBag, conversation: ConversationModel, avatarHeight: CGFloat = Constants.defaultAvatarSize) {
        self.init(injectionBag: injectionBag, accountId: conversation.accountId, avatarHeight: avatarHeight)
        self.conversation = conversation
        self.conversationEnded.accept(self.isConversationEnded())
        self.subscribeConversationEvents()
        self.updateInfo()
        self.setParticipants()
        self.updateColorPreference()
    }

    func isConversationEnded() -> Bool {
        guard let conversation = self.conversation else { return false }

        if conversation.getAllParticipants().isEmpty {
            return false
        }

        let hasActiveOtherParticipants = conversation.getParticipants().contains { participant in
            switch participant.role {
            case .blocked, .left:
                return false
            default:
                return true
            }
        }

        if hasActiveOtherParticipants {
            return false
        }

        if conversation.isCoredialog() {
            // check if conversation with self
            let localParticipants = conversation.getAllLocalParticipants()
            if let participant = localParticipants.first {
                return participant.role == .left
            }

            return true
        }

        return conversation.getLocalParticipants()?.role != .admin
    }

    func addContacts(contacts: [ContactModel]) {
        var contactsInfo = [ParticipantInfo]()
        self.contacts.accept(contactsInfo)
        let requests = self.requestsService.requests.value
        contacts.forEach { contact in
            let requestIndex = requests.firstIndex(where: { request in
                request.participants.contains { participant in
                    participant.jamiId == contact.hash
                }
            })
            // filter out blocked and pending contacts
            if contact.blocked || requestIndex != nil { return }
            // filter out contact that is already added to swarm participants
            if self.participants.value.filter({ participantInfo in
                participantInfo.jamiId == contact.hash
            }).first != nil {
                return
            }

            // filter out already added contacts
            if self.contacts.value.filter({ contactInfo in
                contactInfo.jamiId == contact.hash
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
        return nonLocalParticipants.contains { participant in
            participant.registeredName.value.lowercased() == name.lowercased()
        }
    }

    func contains(searchQuery: String) -> Bool {
        let normalizedQuery = searchQuery.normalized()

        if self.title.value.normalized().containsCaseInsensitive(string: normalizedQuery) {
            return true
        }

        return nonLocalParticipants.contains { participant in
            participant.registeredName.value.normalized().containsCaseInsensitive(string: normalizedQuery) ||
                participant.profileName.value.normalized().containsCaseInsensitive(string: normalizedQuery) ||
                participant.jamiId.normalized().containsCaseInsensitive(string: normalizedQuery)
        }
    }

    private func subscribeParticipantsInfo() {
        tempBag = DisposeBag()

        guard !participants.value.isEmpty else { return }

        let isDialog = conversation?.isDialog() ?? false

        // Create a single shared observable for all participant data
        // swiftlint:disable large_tuple
        let participantData = Observable.combineLatest(
            participants.value.map { participant -> Observable<(String, String, String, Data?)> in
                return Observable.combineLatest(
                    participant.finalName.asObservable(),
                    participant.registeredName.asObservable(),
                    participant.profileName.asObservable(),
                    participant.avatarData.asObservable()
                )
            }
        )
        .share(replay: 1)
        // swiftlint:enable large_tuple

        participantData
            .subscribe(onNext: { [weak self] data in
                guard let self = self else { return }

                let finalNames = data.map { $0.0 }.filter { !$0.isEmpty }
                let profileNames = data.map { $0.2 }.filter { !$0.isEmpty }
                let avatars = data.map { $0.3 }.compactMap { $0 }

                self.participantsAvatars.accept(avatars)

                if isDialog {
                    self.participantsNames.accept(Array(Set(finalNames)))
                    self.participantsString.accept(self.registeredNameForDialog())

                    if self.title.value.isEmpty, let name = profileNames.first {
                        self.title.accept(titleForDialog())
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
        if let avatar = info[ConversationAttributes.avatar.rawValue],
           let imageData = avatar.toImageData() {
            self.avatarData.accept(imageData)
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
        self.conversationEnded.accept(self.isConversationEnded())
        self.insertAndSortParticipants(participants: participantsInfo)
    }

    private func createParticipant(jamiId: String, role: ParticipantRole) -> ParticipantInfo? {
        let participantInfo = ParticipantInfo(jamiId: jamiId, role: role, profileService: self.profileService)
        let uri = JamiURI.init(schema: .ring, infoHash: jamiId)
        guard let uriString = uri.uriString else { return nil }
        // subscribe for profile updates for participant
        self.profileService
            .getProfile(uri: uriString, createIfNotexists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak participantInfo] profile in
                guard let participantInfo = participantInfo else { return }
                // The view has a size of avatarHeight. Create a larger image for better resolution.
                if let data = profile.photo?.toImageData() {
                    participantInfo.profileLock.lock()
                    participantInfo.hasProfileAvatar = true
                    participantInfo.avatarData.accept(data)
                    participantInfo.profileLock.unlock()
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
        currentValue = currentValue.filter({ [.invited, .member, .admin, .left].contains($0.role) })
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

    private func buildAvatar() -> Data? {
        let participantsCount = self.participants.value.count
        // for conversation with one participant return that participant's avatar
        if participantsCount == 1, let avatar = self.participants.value.first?.avatarData.value {
            return avatar
        }
        if participantsCount == 2,
           let avatar = nonLocalParticipants.first?.avatarData.value {
            return avatar
        }
        return nil
    }

    private func titleForDialog() -> String {
        if let name = nonLocalParticipants.first?.profileName.value,
           !name.isEmpty {
            return name
        }
        if let name = localParticipant?.profileName.value, !name.isEmpty {
            return name.withYourselfSuffix()
        }
        return ""
    }

    private func registeredNameForDialog() -> String {
        if let name = nonLocalParticipants.first?.registeredName.value, !name.isEmpty {
            return name
        }
        if let name = localParticipant?.registeredName.value, !name.isEmpty {
            return name.withYourselfSuffix()
        }
        return ""
    }

    private func buildTitleFrom(names: [String]) -> String {
        // title format: "name1, name2, name3 + number of other participants"
        let participantsCount = self.participants.value.count

        // One-to-one conversation: return other participant's name
        if participantsCount == 2, let name = nonLocalParticipants.first?.finalName.value, !name.isEmpty {
            return name
        }

        let localName = localParticipant?.finalName.value

        let processedNames = names.map { name in
            name == localName ? name.withYourselfSuffix() : name
        }

        var uniqueSetNames = Set<String>()
        let uniqueNames = processedNames.filter { uniqueSetNames.insert($0).inserted }
            .sorted { $0.count < $1.count }

        guard !uniqueNames.isEmpty else { return "" }

        // Show max 3 names + count of others
        let displayCount = min(uniqueNames.count, 3)
        let displayedNames = uniqueNames.prefix(displayCount).joined(separator: ", ")
        let othersCount = participantsCount - displayCount

        return othersCount > 0 ? "\(displayedNames), + \(othersCount)" : displayedNames
    }
}
