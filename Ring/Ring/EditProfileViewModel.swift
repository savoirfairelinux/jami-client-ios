/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani <alireza.toghiani@savoirfairelinux.com>
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
import Contacts

class EditProfileViewModel {

    let disposeBag = DisposeBag()
    let defaultImage = UIImage(named: "add_avatar")
    var image: UIImage?
    var name: String = ""
    let profileService: ProfilesService
    let accountService: AccountsService

    lazy var profileImage: Observable<UIImage?> = { [weak self] in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
            if let self = self, let account = self.accountService.currentAccount {
                self.profileService.getAccountProfile(accountId: account.id)
                    .take(1)
                    .subscribe(onNext: { profile in
                        self.profileForCurrentAccount.onNext(profile)
                    })
                    .disposed(by: self.disposeBag)
            }
        })
        return profileForCurrentAccount.share()
            .map({ profile in
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo,
                                     options: NSData.Base64DecodingOptions
                                        .ignoreUnknownCharacters) as Data?,
                   let image = UIImage(data: data) {
                    self?.image = image
                    return image
                }
                return UIImage.defaultJamiAvatarFor(profileName: profile.alias, account: self?.accountService.currentAccount, size: 70, withFontSize: 26, inset: 16)
            })
    }()

    var profileForCurrentAccount = PublishSubject<Profile>()

    lazy var profileName: Observable<String?> = { [weak self] in
        return profileForCurrentAccount.share()
            .map({ profile in
                guard let self = self else { return "" }
                if let name = profile.alias, !name.isEmpty {
                    self.name = name
                    return name
                }
                if let account = self.accountService.currentAccount {
                    guard var details = account.details else { return "" }
                    let name = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .displayName))
                    if !name.isEmpty {
                        self.name = name
                        return name
                    }
                }
                return ""
            })
    }()

    init(profileService: ProfilesService, accountService: AccountsService) {
        self.profileService = profileService
        self.accountService = accountService
        self.accountService.currentAccountChanged
            .subscribe(onNext: { [weak self] account in
                if let self = self, let selectedAccount = account {
                    self.updateProfileInfoFor(accountId: selectedAccount.id)
                }
            })
            .disposed(by: self.disposeBag)
    }

    func updateProfileInfoFor(accountId: String) {
        self.profileService.getAccountProfile(accountId: accountId)
            .subscribe(onNext: { [weak self] profile in
                self?.profileForCurrentAccount.onNext(profile)
            })
            .disposed(by: self.disposeBag)
    }

    func saveProfile() {
        guard let account = self.accountService.currentAccount else { return }
        var photo: String?
        if let image = self.image, !image.isEqual(defaultImage),
           let imageData = image.convertToData(ofMaxSize: 40000) {
            photo = imageData.base64EncodedString()
        }
        guard var details = account.details else { return }
        details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.displayName), withValue: self.name)
        account.details = details
        self.accountService.setAccountDetails(forAccountId: account.id, withDetails: details)
        let accountUri = AccountModelHelper.init(withAccount: account).uri ?? ""
        self.profileService.updateAccountProfile(accountId: account.id,
                                                 alias: self.name,
                                                 photo: photo, accountURI: accountUri)

    }

    func updateImage(_ image: UIImage) {
        self.image = image
        self.saveProfile()
    }

    func updateName(_ name: String) {
        self.name = name
        self.saveProfile()
    }
}
