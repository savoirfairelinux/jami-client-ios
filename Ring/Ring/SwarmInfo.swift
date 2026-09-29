/*
 *  Copyright (C) 2022 - 2025 Savoir-faire Linux Inc.
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

    func apply(_ profile: Profile) {
        avatarData.accept(profile.photo?.toImageData())
        profileName.accept(profile.alias ?? "")
    }

    func lookupName(nameService: NameService, accountId: String) {
        nameService.registeredName(forAddress: self.jamiId, accountId: accountId)
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] name in
                guard let self = self, self.registeredName.value != name else { return }
                self.registeredName.accept(name)
            })
            .disposed(by: self.disposeBag)
    }
}

// swiftlint:disable type_body_length
class SwarmInfo: SwarmInfoProtocol, Identifiable {
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
                if let avatar = avatar, !avatar.isEmpty { return avatar }
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
    private let contactsService: ContactsService
    private let accountsService: AccountsService
    private let requestsService: RequestsService
    private let accountId: String
    private let localJamiId: String?
    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()
    private var members = Set<ParticipantData>()
    private var avatarSource: String?
    private let stateScheduler = SerialDispatchQueueScheduler(qos: .userInitiated)

    // to get info during swarm creation
    init(injectionBag: InjectionBag, accountId: String, avatarHeight: CGFloat = Constants.defaultAvatarSize) {
        self.avatarHeight = avatarHeight
        self.nameService = injectionBag.nameService
        self.profileService = injectionBag.profileService
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.accountService
        self.requestsService = injectionBag.requestsService
        self.accountId = accountId
        self.localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId

        Observable
            .combineLatest(self.title.asObservable(),
                           self.participantsNames.asObservable()) { [weak self] (title: String, names: [String]) -> String in
                guard let self = self else { return "" }
                let title = title.simplified()
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
        self.apply(conversation.state)
        conversation.stateChanges
            .observe(on: self.stateScheduler)
            .subscribe(onNext: { [weak self] state in
                self?.apply(state)
            })
            .disposed(by: self.disposeBag)
    }

    private func isConversationEnded(_ state: ConversationState) -> Bool {
        if state.participants.isEmpty {
            return false
        }

        let hasActiveOtherParticipants = state.participants.filter { !$0.isLocal }.contains { participant in
            switch participant.role {
            case .banned, .left:
                return false
            default:
                return true
            }
        }

        if hasActiveOtherParticipants {
            return false
        }

        let localParticipant = state.participants.first { $0.isLocal }
        if state.isCoredialog {
            // check if conversation with self
            if let participant = localParticipant {
                return participant.role == .left
            }

            return true
        }

        return localParticipant?.role != .admin
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
            // filter out banned and pending contacts
            if contact.banned || requestIndex != nil { return }
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

        let isDialog = conversation?.isCoredialog() ?? false

        // Create a single shared observable for all participant data
        // swiftlint:disable large_tuple
        let participantData = Observable.combineLatest(
            participants.value.map { participant -> Observable<(role: ParticipantRole, finalName: String, profileName: String,
                                                                avatarData: Data?)> in
                let role = participant.role
                return Observable.combineLatest(
                    participant.finalName.asObservable(),
                    participant.registeredName.asObservable(),
                    participant.profileName.asObservable(),
                    participant.avatarData.asObservable(),
                    resultSelector: { finalName, _, profileName, avatarData in
                        (role: role, finalName: finalName, profileName: profileName, avatarData: avatarData)
                    }
                )
            }
        )
        .share(replay: 1)
        // swiftlint:enable large_tuple

        participantData
            .subscribe(onNext: { [weak self] data in
                guard let self = self else { return }

                let finalNames = data.map(\.finalName).filter { !$0.isEmpty }
                let avatars = data.map(\.avatarData).compactMap { $0 }

                self.participantsAvatars.accept(avatars)

                if isDialog {
                    self.participantsNames.accept(Array(Set(finalNames)))
                    self.participantsString.accept(self.registeredNameForDialog())
                } else {
                    let activeFinalNames = data
                        .filter { $0.role.isActive }
                        .map(\.finalName)
                        .filter { !$0.isEmpty }
                    let uniqueNames = Array(Set(activeFinalNames))
                    self.participantsNames.accept(uniqueNames)
                    self.participantsString.accept(self.buildTitleFrom(names: uniqueNames))
                }
            })
            .disposed(by: tempBag)
    }

    private func apply(_ state: ConversationState) {
        if !state.isCoredialog {
            if state.avatar != self.avatarSource {
                self.avatarSource = state.avatar
                self.avatarData.accept(state.avatar.toImageData().flatMap { $0.isEmpty ? nil : $0 })
            }
            Self.accept(state.title, to: self.title)
            Self.accept(state.description, to: self.description)
        }
        Self.accept(state.preferences.color, to: self.color)
        let members = Set(state.participants.map { ParticipantData(jamiId: $0.jamiId, role: $0.role) })
        if members != self.members {
            self.members = members
            self.setParticipants(Array(members))
        }
        Self.accept(self.isConversationEnded(state), to: self.conversationEnded)
    }

    private static func accept<Value: Equatable>(_ value: Value, to relay: BehaviorRelay<Value>) {
        if relay.value != value {
            relay.accept(value)
        }
    }

    private func setParticipants(_ members: [ParticipantData]) {
        let participantsInfo = members.compactMap { member in
            createParticipant(jamiId: member.jamiId, role: member.role)
        }
        self.insertAndSortParticipants(participants: participantsInfo)
    }

    private func createParticipant(jamiId: String, role: ParticipantRole) -> ParticipantInfo? {
        let participantInfo = ParticipantInfo(jamiId: jamiId, role: role, profileService: self.profileService)
        let uri = JamiURI.init(schema: .ring, infoHash: jamiId)
        guard let uriString = uri.uriString else { return nil }
        let isSelf = jamiId == localJamiId
        let profileObservable: Observable<Profile>
        if isSelf {
            profileObservable = self.profileService.getAccountProfile(accountId: accountId)
        } else {
            profileObservable = self.profileService.getProfile(uri: uriString, accountId: accountId)
        }
        profileObservable
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak participantInfo] profile in
                participantInfo?.apply(profile)
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
        guard conversation?.isCoredialog() ?? false else { return nil }
        if let participant = nonLocalParticipants.first {
            return participant.avatarData.value
        }
        return localParticipant?.avatarData.value
    }

    private func registeredNameForDialog() -> String {
        if let name = nonLocalParticipants.first?.registeredName.value, !name.isEmpty {
            return name
        }
        return ""
    }

    private func buildTitleFrom(names: [String]) -> String {
        if conversation?.isCoredialog() ?? false,
           let name = nonLocalParticipants.first?.finalName.value, !name.isEmpty {
            return name
        }
        let localName = localParticipant?.finalName.value
        let processedNames = names.map { $0 == localName ? $0.withYourselfSuffix() : $0 }
        let activeCount = participants.value.filter { $0.role.isActive }.count
        return buildGroupTitle(resolvedNames: processedNames, totalActiveCount: activeCount)
    }
}
