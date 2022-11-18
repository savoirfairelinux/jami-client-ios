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

class ParticipantData {
    var jamiId: String
    var role: ParticipantRole
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var name = BehaviorRelay(value: "")

    init(jamiId: String, role: ParticipantRole) {
        self.jamiId = jamiId
        self.role = role
    }
}

class SwarmInfo {
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var name = BehaviorRelay(value: "")
    var description = BehaviorRelay(value: "")
    var participants = BehaviorRelay(value: [ParticipantData]())

    private let nameService: NameService
    private let contactsService: ContactsService
    private let accountId: String
    private let disposeBag = DisposeBag()
    var names = [String]()

    init(injectionBag: InjectionBag, conversation: ConversationModel) {
        self.nameService = injectionBag.nameService
        self.contactsService = injectionBag.contactsService
        self.accountId = conversation.accountId
        let info = injectionBag.conversationsService.getConversationInfo(conversationId: conversation.id, accountId: conversation.accountId)
        if let avatar = info[ConversationAttributes.avatar.rawValue] {
            self.avatar.accept(self.imageFrom(string: avatar))
        }
        if let title = info[ConversationAttributes.title.rawValue], !title.isEmpty  {
            self.name.accept(title)
        }
        if let description = info[ConversationAttributes.description.rawValue] {
            self.description.accept(description)
        }
        conversation.getParticipants().forEach { participant in
            self.addParticipant(jamiId: participant.jamiId, role: participant.role)
        }
    }

    func addContacts(contacts: [ContactModel]) {
        contacts.forEach { contact in
            self.addParticipant(jamiId: contact.hash, role: ParticipantRole.unknown)
        }
    }

    private func imageFrom(string: String) -> UIImage? {
        guard !string.isEmpty, let data = NSData(base64Encoded: string, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? else { return nil }
        return UIImage(data: data)
    }

    private func addParticipant(jamiId: String, role: ParticipantRole) {
        let participantInfo = ParticipantData(jamiId: jamiId, role: role)
        let uri = JamiURI.init(schema: .ring, infoHach: jamiId)
        guard let uriString = uri.uriString else { return }
        if let profile = self.contactsService.getProfile(uri: uriString, accountId: accountId) {
            if let imageString = profile.photo, let image = self.imageFrom(string: imageString) {
                participantInfo.avatar.accept(image)
            }
            if let profileName = profile.alias, !profileName.isEmpty {
                participantInfo.name.accept(profileName)
                if participantInfo.avatar.value == nil {
                    participantInfo.avatar.accept(UIImage.createContactAvatar(username: profileName))
                }
            }
        }
        if participantInfo.avatar.value == nil || participantInfo.name.value.isEmpty {
            lookupNameFor(participant: participantInfo)
        }
        var currentValue = self.participants.value
        currentValue.append(participantInfo)
        self.participants.accept(currentValue)
    }

    private func lookupNameFor(participant: ParticipantData) {
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
                    if participant.avatar.value == nil {
                        participant.avatar.accept(UIImage.createContactAvatar(username: name))
                    }
                } else {
                    participant.name.accept(participant.jamiId)
                    if participant.avatar.value == nil {
                        participant.avatar.accept(UIImage.createContactAvatar(username: participant.jamiId))
                    }
                }
            })
            .disposed(by: self.disposeBag)
        self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: participant.jamiId)
    }
}
