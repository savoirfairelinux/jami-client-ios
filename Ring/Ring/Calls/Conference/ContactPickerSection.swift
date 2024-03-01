/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import RxDataSources
import RxSwift
import RxCocoa

class Contact {
    var uri: String
    var accountID: String
    var registeredName: String
    var hash: String
    let disposeBag = DisposeBag()

    lazy var presenceStatus: BehaviorRelay<PresenceStatus>? = {
        self.presenceService
            .getSubscriptionsForContact(contactId: self.hash)
    }()

    var firstLine: BehaviorRelay<String> = BehaviorRelay(value: "")
    var secondLine: String = ""

    var imageData: BehaviorRelay<Data?> = BehaviorRelay(value: nil)
    let presenceService: PresenceService
    let nameService: NameService
    let profileService: ProfilesService

    init (contactUri: String, accountId: String,
          registeredName: String, presService: PresenceService,
          nameService: NameService, hash: String, profileService: ProfilesService) {
        self.presenceService = presService
        self.nameService = nameService
        self.profileService = profileService
        self.uri = contactUri
        self.accountID = accountId
        self.registeredName = registeredName
        self.hash = hash
        self.updateName()
        self.fetchProfile()
    }

    private func fetchProfile() {
        profileService.getProfile(uri: self.uri, createIfNotexists: false, accountId: self.accountID)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(
                onNext: { [weak self] profile in
                    self?.processProfile(profile)
                },
                onError: { [weak self] _ in
                    self?.handleError()
                }
            )
            .disposed(by: disposeBag)
    }

    private func processProfile(_ profile: Profile) {
        updateName(profile: profile)
        if let photo = profile.photo,
           let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
            DispatchQueue.main.async { [weak self ] in
                self?.imageData.accept(data)
            }
        }
        if registeredName.isEmpty && profile.alias?.isEmpty ?? true {
            lookupNameAsync()
        }
    }

    private func handleError() {
        if registeredName.isEmpty {
            lookupNameAsync()
        } else {
            updateName()
        }
    }

    private func lookupNameAsync() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.lookupName(nameService: self.nameService, accountId: self.accountID)
        }
    }

    private func lookupName(nameService: NameService?, accountId: String) {
        nameService?.usernameLookupStatus.share()
            .filter { [weak self] response in
                response.address == self?.hash
            }
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self] response in
                self?.registeredName = response.name
                self?.updateName()
            })
            .disposed(by: disposeBag)

        nameService?.lookupAddress(withAccount: accountId, nameserver: "", address: hash)
    }

    private func updateName(profile: Profile? = nil) {
        DispatchQueue.main.async { [weak self ] in
            guard let self = self else { return }
            let nameToUse: String
            if let alias = profile?.alias, !alias.isEmpty {
                nameToUse = alias
            } else {
                nameToUse = self.registeredName.isEmpty ? self.hash : self.registeredName
            }
            self.firstLine.accept(nameToUse)
            self.updateSecondLine()
        }
    }

    private func updateSecondLine() {
        self.secondLine = {
            if firstLine.value == hash {
                return ""
            }
            if firstLine.value == registeredName {
                return hash
            }
            return registeredName.isEmpty ? hash : registeredName
        }()
    }

    static func == (lhs: Contact, rhs: Contact) -> Bool {
        return (lhs.uri == rhs.uri &&
                    lhs.accountID == rhs.accountID &&
                    lhs.registeredName == rhs.registeredName)
    }
}

struct ConferencableItem {
    var conferenceID: String
    var contacts: [Contact]
}

struct ContactPickerSection {
    var header: String
    var items: [ConferencableItem]
}

extension ContactPickerSection: SectionModelType {
    typealias Item = ConferencableItem
    init(original: ContactPickerSection, items: [Item]) {
        self = original
        self.items = items
    }
}

struct ConversationPickerSection {
    var items: [Item]
}

extension ConversationPickerSection: SectionModelType {
    typealias Item = SwarmInfo
    init(original: ConversationPickerSection, items: [SwarmInfo]) {
        self = original
        self.items = items
    }
}
