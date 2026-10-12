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
    var avatarData: BehaviorRelay<Data?> { get }
    var title: BehaviorRelay<String> { get }
    var color: BehaviorRelay<String> { get }
    var type: BehaviorRelay<ConversationType> { get }
    var description: BehaviorRelay<String> { get }
    var participantsNames: BehaviorRelay<[String]> { get }
    var participantsAvatars: BehaviorRelay<[Data]> { get }

    var finalTitle: BehaviorRelay<String> { get }
    var participantsString: BehaviorRelay<String> { get }

    var finalAvatarData: Observable<Data?> { get }

    var participants: BehaviorRelay<[ParticipantInfo]> { get }
    var conversation: ConversationModel { get }
    var conversationEnded: BehaviorRelay<Bool> { get }
    var id: String { get }

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

    static func loaded(jamiId: String, role: ParticipantRole, accountId: String, isLocal: Bool,
                       injectionBag: InjectionBag) -> ParticipantInfo? {
        let profileService = injectionBag.profileService
        let participantInfo = ParticipantInfo(jamiId: jamiId, role: role, profileService: profileService)
        let uri = JamiURI.init(schema: .ring, infoHash: jamiId)
        guard let uriString = uri.uriString else { return nil }
        let profileObservable: Observable<Profile>
        if isLocal {
            profileObservable = profileService.getAccountProfile(accountId: accountId)
        } else {
            profileObservable = profileService.getProfile(uri: uriString, accountId: accountId)
        }
        profileObservable
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak participantInfo] profile in
                participantInfo?.apply(profile)
            } onError: { _ in
            }
            .disposed(by: participantInfo.disposeBag)
        participantInfo.lookupName(nameService: injectionBag.nameService, accountId: accountId)
        return participantInfo
    }

    func lookupName(nameService: NameService, accountId: String) {
        nameService.registeredName(forAddress: self.jamiId, accountId: accountId)
            .take(1)
            .subscribe(onNext: { [weak self] name in
                guard let self = self, self.registeredName.value != name else { return }
                self.registeredName.accept(name)
            })
            .disposed(by: self.disposeBag)
    }
}

class SwarmInfo: SwarmInfoProtocol, Identifiable {
    let avatarData: BehaviorRelay<Data?> = BehaviorRelay(value: nil)
    let title = BehaviorRelay(value: "")
    let color = BehaviorRelay<String>(value: "")
    let type = BehaviorRelay(value: ConversationType.oneToOne)
    let description = BehaviorRelay(value: "")
    let participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    let participantsAvatars: BehaviorRelay<[Data]> = BehaviorRelay(value: [Data()])
    let conversationEnded: BehaviorRelay<Bool> = BehaviorRelay(value: false)

    lazy var id: String = {
        return conversation.id
    }()

    let finalTitle = BehaviorRelay<String>(value: "")
    let participantsString = BehaviorRelay(value: "")

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

    let participants = BehaviorRelay(value: [ParticipantInfo]()) // participants already added to swarm
    var nonLocalParticipants: [ParticipantInfo] {
        return participants.value.filter { $0.jamiId != localJamiId }
    }
    var localParticipant: ParticipantInfo? {
        return participants.value.first { $0.jamiId == localJamiId }
    }
    let conversation: ConversationModel

    private let injectionBag: InjectionBag
    private let accountId: String
    private let localJamiId: String?
    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()
    private var members = Set<ParticipantData>()
    private var avatarSource: String?
    private let stateScheduler = SerialDispatchQueueScheduler(qos: .userInitiated)

    init(injectionBag: InjectionBag, conversation: ConversationModel) {
        self.injectionBag = injectionBag
        self.conversation = conversation
        self.accountId = conversation.accountId
        self.localJamiId = injectionBag.accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId

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

        self.apply(conversation.info)
        conversation.infoChanges
            .observe(on: self.stateScheduler)
            .subscribe(onNext: { [weak self] info in
                self?.apply(info)
            })
            .disposed(by: self.disposeBag)
    }

    private func isConversationEnded(_ info: ConversationInfo) -> Bool {
        if info.participants.isEmpty {
            return false
        }

        let hasActiveOtherParticipants = info.participants.filter { !$0.isLocal }.contains { participant in
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

        let localParticipant = info.participants.first { $0.isLocal }
        if info.isCoredialog {
            // check if conversation with self
            if let participant = localParticipant {
                return participant.role == .left
            }

            return true
        }

        return localParticipant?.role != .admin
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

        let isDialog = conversation.isCoredialog()

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

    private func apply(_ info: ConversationInfo) {
        if !info.isCoredialog {
            if info.avatar != self.avatarSource {
                self.avatarSource = info.avatar
                self.avatarData.accept(info.avatar.toImageData().flatMap { $0.isEmpty ? nil : $0 })
            }
            Self.accept(info.title, to: self.title)
            Self.accept(info.description, to: self.description)
        }
        Self.accept(info.preferences.color, to: self.color)
        let members = Set(info.participants.map { ParticipantData(jamiId: $0.jamiId, role: $0.role) })
        if members != self.members {
            self.members = members
            self.setParticipants(Array(members))
        }
        Self.accept(self.isConversationEnded(info), to: self.conversationEnded)
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
        return ParticipantInfo.loaded(jamiId: jamiId, role: role, accountId: accountId,
                                      isLocal: jamiId == localJamiId,
                                      injectionBag: injectionBag)
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
        guard conversation.isCoredialog() else { return nil }
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
        if conversation.isCoredialog(),
           let name = nonLocalParticipants.first?.finalName.value, !name.isEmpty {
            return name
        }
        let localName = localParticipant?.finalName.value
        let processedNames = names.map { $0 == localName ? $0.withYourselfSuffix() : $0 }
        let activeCount = participants.value.filter { $0.role.isActive }.count
        return buildGroupTitle(resolvedNames: processedNames, totalActiveCount: activeCount)
    }
}
