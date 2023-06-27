/*
 *  Copyright (C) 2019 - 2023 Savoir-faire Linux Inc.
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

import RxSwift
import RxCocoa

class ParticipantProfileInfo {
    private let participantId: String
    private let participantUserName: String
    private let callsSercive: CallsService
    private let profileService: ProfilesService
    private let accountService: AccountsService
    private let nameService: NameService
    private let disposeBag = DisposeBag()

    let avatar = BehaviorRelay<UIImage?>(value: nil)
    let displayName = BehaviorRelay<String>(value: "")
    let avatarSize = CGSize(width: 40, height: 40)

    init(injectionBag: InjectionBag, info: ConferenceParticipant) {
        self.callsSercive = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.participantId = info.uri?.filterOutHost() ?? ""
        self.participantUserName = info.displayName
        self.nameService = injectionBag.nameService
        if self.isLocalCall() {
            self.handleLocalParticipant()
        } else {
            self.handleRemoteParticipant()
        }
    }

    private func handleLocalParticipant() {
        guard let account = self.accountService.currentAccount else { return }
        profileService.getAccountProfile(accountId: account.id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                guard let self = self else { return }
                self.handleProfile(profile)
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }

    private func handleRemoteParticipant() {
        guard let account = self.accountService.currentAccount else { return }
        let type = account.type == AccountType.sip ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                                           infoHash: participantId,
                                           account: account).uriString else { return }
        profileService.getProfile(uri: uriString,
                                  createIfNotexists: false,
                                  accountId: account.id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                guard let self = self else { return }
                self.handleProfile(profile)
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }

    private func handleProfile(_ profile: Profile) {
        guard let account = self.accountService.currentAccount else { return }
        if let imageString = profile.photo, let image = imageString.createImage() {
            avatar.accept(image)
        }

        if self.isLocalCall() {
            var displayName = account.registeredName
            if let name = profile.alias, !name.isEmpty {
                displayName = name
            }
            if avatar.value == nil {
                avatar.accept(UIImage.createContactAvatar(username: displayName, size: avatarSize))
            }
            self.displayName.accept(L10n.Account.me)
        } else {
            var displayName = self.participantUserName
            if let name = profile.alias, !name.isEmpty {
                displayName = name
            }
            if displayName.isEmpty {
                lookupName(nameService: nameService, accountId: account.id)
                return
            }
            if avatar.value == nil {
                avatar.accept(UIImage.createContactAvatar(username: displayName, size: avatarSize))
            }
            self.displayName.accept(displayName)
        }
    }

    func lookupName(nameService: NameService, accountId: String) {
        nameService.usernameLookupStatus.share()
            .filter({ [weak self] lookupNameResponse in
                guard let self = self else { return false }
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == self.participantId
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self] lookupNameResponse in
                guard let self = self else { return }
                if let name = lookupNameResponse.name, !name.isEmpty, self.displayName.value != name {
                    self.displayName.accept(name)
                    if self.avatar.value == nil {
                        self.avatar.accept(UIImage.createContactAvatar(username: name, size: CGSize(width: 40, height: 40)))
                    }
                }
            })
            .disposed(by: self.disposeBag)
        nameService.lookupAddress(withAccount: accountId, nameserver: "", address: self.participantId)
    }

    func isLocalCall() -> Bool {
        guard let account = self.accountService.currentAccount else { return false }
        return account.jamiId == participantId
    }
}
