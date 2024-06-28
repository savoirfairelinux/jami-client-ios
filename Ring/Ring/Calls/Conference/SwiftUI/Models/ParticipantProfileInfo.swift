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
        self.displayName.accept(L10n.Account.me)
        guard let account = self.accountService.currentAccount else { return }
        profileService.getAccountProfile(accountId: account.id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                guard let self = self else { return }
                self.handleProfile(profile)
            } onError: { [weak self] _ in
                guard let self = self else { return }
                self.avatar.accept(UIImage.defaultJamiAvatarFor(profileName: "", account: account, size: self.avatarSize.width))
            }
            .disposed(by: disposeBag)
    }

    private func handleRemoteParticipant() {
        self.displayName.accept(self.participantUserName.isEmpty ? self.participantId : self.participantUserName)
        guard let uriString = getParticipantURI(), let accountId = self.accountService.currentAccount?.id else { return }
        self.fetchRemoteProfile(for: uriString, accountId: accountId)
    }

    private func getParticipantURI() -> String? {
        guard let account = self.accountService.currentAccount else { return nil }
        let type = account.type == AccountType.sip ? URIType.sip : URIType.ring
        return JamiURI(schema: type, infoHash: participantId, account: account).uriString
    }

    private func fetchRemoteProfile(for uri: String, accountId: String) {
        profileService.getProfile(uri: uri, createIfNotexists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(
                onNext: { [weak self] profile in
                    self?.handleProfile(profile)
                },
                onError: { [weak self] _ in
                    self?.handleProfileError()
                }
            )
            .disposed(by: disposeBag)
    }

    func lookupNameAsync(accountId: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.lookupName(nameService: self?.nameService, accountId: accountId)
        }
    }

    func lookupName(nameService: NameService?, accountId: String) {
        nameService?.usernameLookupStatus.share()
            .filter { [weak self] response in
                response.address == self?.participantId
            }
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self] response in
                if let name = response.name, !name.isEmpty, self?.displayName.value != name {
                    self?.displayName.accept(name)
                    if self?.avatar.value == nil {
                        self?.avatar.accept(self?.createAvatar(for: name))
                    }
                }
            })
            .disposed(by: disposeBag)

        nameService?.lookupAddress(withAccount: accountId, nameserver: "", address: participantId)
    }

    private func handleProfileError() {
        if avatar.value == nil {
            avatar.accept(self.createAvatar(for: self.participantUserName))
        }
        if self.participantUserName.isEmpty {
            lookupNameAsync(accountId: self.accountService.currentAccount?.id ?? "")
        }
    }

    private func handleProfile(_ profile: Profile) {
        guard let account = self.accountService.currentAccount else { return }
        // The view has a size of avatarSize.width. Create a larger image for better resolution.
        if let imageString = profile.photo, let image = imageString.createImage(size: avatarSize.width * 2) {
            avatar.accept(image)
        }
        if self.isLocalCall() {
            if avatar.value == nil {
                avatar.accept(UIImage.defaultJamiAvatarFor(profileName: profile.alias, account: account, size: avatarSize.width))
            }
            self.displayName.accept(L10n.Account.me)
        } else {
            var displayName = self.participantUserName
            if let name = profile.alias, !name.isEmpty {
                displayName = name
            }
            if avatar.value == nil {
                avatar.accept(self.createAvatar(for: displayName))
            }
            if displayName.isEmpty {
                lookupNameAsync(accountId: account.id)
            } else {
                self.displayName.accept(displayName)
            }
        }
    }

    private func createAvatar(for username: String) -> UIImage? {
        return UIImage.createContactAvatar(username: username, size: avatarSize)
    }

    func isLocalCall() -> Bool {
        if participantId.isEmpty { return true }
        guard let account = self.accountService.currentAccount else { return false }
        return account.jamiId == participantId
    }
}
