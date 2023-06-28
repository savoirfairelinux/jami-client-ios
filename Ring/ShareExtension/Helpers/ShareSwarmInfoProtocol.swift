/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
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

import RxSwift
import RxRelay
import UIKit

protocol ShareSwarmInfoProtocol {
    var avatar: BehaviorRelay<UIImage?> { get set }
    var title: BehaviorRelay<String> { get set }
    var color: BehaviorRelay<String> { get set }
    var type: BehaviorRelay<ConversationType> { get set }
    var description: BehaviorRelay<String> { get set }
    var participantsNames: BehaviorRelay<[String]> { get set }
    var participantsAvatars: BehaviorRelay<[UIImage]> { get set }

    var avatarHeight: CGFloat { get set }
    var avatarSpacing: CGFloat { get set }
    var maximumLimit: Int { get set }

    var finalTitle: Observable<String> { get set }

    var finalAvatar: Observable<UIImage> { get set }

    var participants: BehaviorRelay<[ShareParticipantInfo]> { get set }
    var conversation: ShareConversationModel? { get set }
    var id: String { get set }

    func hasParticipantWithRegisteredName(name: String) -> Bool
    func contains(searchQuery: String) -> Bool
}

class ShareParticipantInfo: Equatable, Hashable {

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
                    self.avatar.accept(UIImage.createContactAvatar(username: name, size: CGSize(width: 40, height: 40)))
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        Observable.combineLatest(self.registeredName.asObservable(),
                                 self.profileName.asObservable())
            .subscribe {[weak self] (registeredName, profileName) in
                guard let self = self else { return }
                let finalName = getFinalNameFrom(registeredName: registeredName, profileName: profileName, hash: self.jamiId)
                self.finalName.accept(finalName)

            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    static func == (lhs: ShareParticipantInfo, rhs: ShareParticipantInfo) -> Bool {
        return rhs.jamiId == lhs.jamiId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(jamiId)
    }

    func getFinalNameFrom(registeredName: String, profileName: String, hash: String) -> String {
        // priority: 1. profileName, 2. registeredName, 3. hash
        if registeredName.isEmpty && profileName.isEmpty {
            return hash
        }
        if !profileName.isEmpty {
            return profileName
        }
        return registeredName
    }

    func lookupName(nameService: ShareNameService, accountId: String) {
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

class ShareSwarmInfo: ShareSwarmInfoProtocol {
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var title = BehaviorRelay(value: "")
    var color = BehaviorRelay<String>(value: "")
    var type = BehaviorRelay(value: ConversationType.oneToOne)
    var description = BehaviorRelay(value: "")
    var participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    var participantsAvatars: BehaviorRelay<[UIImage]> = BehaviorRelay(value: [UIImage()])

    var avatarHeight: CGFloat = 40
    var avatarSpacing: CGFloat = 2
    var maximumLimit: Int = 8
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

    lazy var finalAvatar: Observable<UIImage> = {
        return Observable
            .combineLatest(self.avatar.asObservable().startWith(self.avatar.value),
                           self.participantsAvatars.asObservable().startWith(self.participantsAvatars.value)) { [weak self] (avatar: UIImage?, _: [UIImage]) -> UIImage in
                guard let self = self else { return UIImage.createGroupAvatar(username: "", size: CGSize(width: 60, height: 60)) }
                if let avatar = avatar { return avatar }
                return self.buildAvatar()
            }
    }()

    var participants = BehaviorRelay(value: [ShareParticipantInfo]()) // particiapnts already added to swarm
    var conversation: ShareConversationModel?

    private let shareServcice: ShareAdapterService
    private let nameServcice: ShareNameService
    private let accountId: String
    private let localJamiId: String?
    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()

    // to get info during swarm creation
    init(injectionBag: ShareInjectionBag, accountId: String, avatarHeight: CGFloat = 40) {
        self.avatarHeight = avatarHeight
        self.shareServcice = injectionBag.daemonService
        self.nameServcice = injectionBag.nameService
        self.accountId = accountId
        self.localJamiId = shareServcice.getAccount(fromAccountId: accountId)?.jamiId
        self.participants
            .subscribe {[weak self] _ in
                guard let self = self else { return }
                self.subscribeParticipantsInfo()
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    // to get info for existing swarm
    convenience init(injectionBag: ShareInjectionBag, conversation: ShareConversationModel, avatarHeight: CGFloat = 40) {
        self.init(injectionBag: injectionBag, accountId: conversation.accountId, avatarHeight: avatarHeight)
        self.conversation = conversation
        self.updateInfo()
        self.setParticipants()
    }

    func hasParticipantWithRegisteredName(name: String) -> Bool {
        return !self.participants.value.filter { participant in
            participant.registeredName.value == name
        }.isEmpty
    }

    func contains(searchQuery: String) -> Bool {
        if self.title.value.containsCaseInsentative(string: searchQuery) { return true }
        return !self.participants.value.filter { participant in
            participant.registeredName.value.containsCaseInsentative(string: searchQuery) ||
                participant.profileName.value.containsCaseInsentative(string: searchQuery) || participant.jamiId.containsCaseInsentative(string: searchQuery)
        }.isEmpty
    }

    private func subscribeParticipantsInfo() {
        tempBag = DisposeBag()
        let namesObservable = participants.value
            .map({ participantInfo in
                return participantInfo.finalName.share().asObservable()
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

    private func updateInfo() {
        guard let conversation = self.conversation else { return }
        let info = self.shareServcice.getConversationInfo(conversationId: conversation.id, accountId: self.accountId)
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

    private func setParticipants() {
        guard let conversation = self.conversation else { return }
        var participantsInfo = [ShareParticipantInfo]()
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
        var participantsInfo = [ShareParticipantInfo]()
        self.participants.accept(participantsInfo)
        self.insertAndSortParticipants(participants: participantsInfo)
        if let localJamiId = self.localJamiId {
            let memberList = shareServcice.getSwarmMembers(conversationId: conversation.id, accountId: accountId, accountURI: localJamiId)
            memberList.forEach { participant in
                if let participantInfo = createParticipant(jamiId: participant.jamiId, role: participant.role) {
                    participantsInfo.append(participantInfo)
                }
            }
        }
        if participantsInfo.isEmpty { return }
        self.insertAndSortParticipants(participants: participantsInfo)
    }

    private func createParticipant(jamiId: String, role: ParticipantRole) -> ShareParticipantInfo? {
        let participantInfo = ShareParticipantInfo(jamiId: jamiId, role: role)
        let uri = ShareJamiURI.init(schema: .ring, infoHash: jamiId)
        guard let uriString = uri.uriString else { return nil }
        //         subscribe for profile updates for participant
        self.shareServcice
            .getProfile(uri: uriString, createIfNotexists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak participantInfo] profile in
                guard let participantInfo = participantInfo else { return }
                if let imageString = profile.photo, let image = imageString.createImage() {
                    participantInfo.avatar.accept(image)
                    participantInfo.hasProfileAvatar = true
                }
                if let profileName = profile.alias, !profileName.isEmpty {
                    participantInfo.profileName.accept(profileName)
                }
            } onError: { _ in
            }
            .disposed(by: participantInfo.disposeBag)
        participantInfo.lookupName(nameService: self.nameServcice, accountId: self.accountId)
        return participantInfo
    }

    private func insertAndSortParticipants(participants: [ShareParticipantInfo]) {
        var currentValue = [ShareParticipantInfo]()
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
        if participantsCount == 2, let localJamiId = shareServcice.getAccount(fromAccountId: accountId)?.jamiId,
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

    func sendAndSaveFile(displayName: String, imageData: Data, conversation: ShareConversationModel, accountId: String? = nil) {
        self.shareServcice.sendAndSaveFile(displayName: displayName, conversation: conversation, imageData: imageData)
    }
}
