/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import SwiftUI
import UIKit
import RxSwift

class AccountVM: ObservableObject  {

    let account: AccountModel

    // edit profile
    @Published var newImage: UIImage?
    @Published var newName: String = ""

    @Published var profileImage: UIImage?
    @Published var username: String?
    @Published var profileName: String = ""
    @Published var accountStatus: String = ""

    let disposeBag = DisposeBag()

    let accountService: AccountsService
    let profileService: ProfilesService

    init(injectionBag: InjectionBag, account: AccountModel) {
        self.account = account
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.subscribeProfile()
        self.subscribeStatus()
        self.username = extractUsername()
    }

    func presentEditProfile() {
        self.newName = profileName
        self.newImage = profileImage
    }

    func getProfileColor() -> UIColor {
        let unwrappedUserName: String = self.username ?? ""
        let name = self.profileName.isEmpty ? unwrappedUserName : self.profileName
        let scanner = Scanner(string: name.toMD5HexString().prefixString())
        var index: UInt64 = 0

        scanner.scanHexInt64(&index)
        return avatarColors[Int(index)]
    }

    func subscribeProfile() {
        self.profileService.getAccountProfile(accountId: account.id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                guard let self = self else { return }
                if let imageString = profile.photo,
                   let image = imageString.createImage() {
                    DispatchQueue.main.async {
                        self.profileImage = image
                    }
                }

                if let name = profile.alias {
                    DispatchQueue.main.async {
                        self.profileName = name
                    }
                }

            }
            .disposed(by: disposeBag)
    }

    func subscribeStatus() {
        if let details = account.details {
            let enable = details.get(withConfigKeyModel:
                                        ConfigKeyModel.init(withKey: .accountEnable)).boolValue
        }
        self.accountService.sharedResponseStream
            .filter({ serviceEvent in
                guard let _: String = serviceEvent
                    .getEventInput(ServiceEventInput.registrationState) else { return false }
                guard let accountId: String = serviceEvent
                    .getEventInput(ServiceEventInput.accountId),
                      accountId == self.account.id else { return false }
                return true
            })
            .subscribe(onNext: { serviceEvent in
                guard let state: String = serviceEvent
                    .getEventInput(ServiceEventInput.registrationState),
                      let accountState = AccountState(rawValue: state) else { return }
               // self.currentAccountState.onNext(accountState)
            })
            .disposed(by: self.disposeBag)
    }

    func extractUsername() -> String? {
        let accountName = account.registeredName
        if !accountName.isEmpty {
            return accountName
        }
        return nil
    }

    func updateProfile() {
        var photo: String?
        if let image = self.newImage,
           let imageData = image.convertToData(ofMaxSize: 40000) {
            photo = imageData.base64EncodedString()
        }
        let details = self.accountService.getAccountDetails(fromAccountId: account.id)
        details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.displayName), withValue: self.newName)
        account.details = details
        self.accountService.setAccountDetails(forAccountId: account.id, withDetails: details)
        let accountUri = AccountModelHelper.init(withAccount: account).uri ?? ""
        self.profileService.updateAccountProfile(accountId: account.id,
                                                 alias: self.newName,
                                                 photo: photo, accountURI: accountUri)
    }
}
