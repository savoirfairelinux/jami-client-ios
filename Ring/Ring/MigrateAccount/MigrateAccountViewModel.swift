/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
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

import UIKit
import RxSwift
import RxCocoa

enum AccountMigrationState {
    case unknown
    case started
    case success
    case error
}

class MigrateAccountViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let accountService: AccountsService
    let profileService: ProfilesService
    let disposeBag = DisposeBag()

    var accountToMigrate = ""

    // MARK: - view binding
    let password = BehaviorRelay<String>(value: "")
    let migrationState = BehaviorRelay<AccountMigrationState>(value: .unknown)

    lazy var profileImage: Observable<UIImage?> = { [unowned self] in
        return self.profileService.getAccountProfile(accountId: accountToMigrate)
            .take(1)
            .map({ profile in
                if let photo = profile.photo,
                    let data = NSData(base64Encoded: photo,
                                      options: NSData.Base64DecodingOptions
                                        .ignoreUnknownCharacters) as Data? {
                    guard let image = UIImage(data: data) else {
                        return UIImage(named: "account_icon")
                    }
                    return image
                }
                return UIImage(named: "account_icon")
            })
        }()

    lazy var profileName: Observable<String> = {
        var displayName = ""
        let details = self.accountService.getAccountDetails(fromAccountId: accountToMigrate)
        let name = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .displayName))
        if !name.isEmpty {
            displayName = name
        }
        return Observable.just(displayName)
    }()

    lazy var jamiId: Observable<String> = {
        let account = self.accountService.getAccount(fromAccountId: accountToMigrate)
        let jamiId = account?.jamiId
        return Observable.just(jamiId ?? "")
    }()

    lazy var username: Observable<String> = {
        guard let account = self.accountService.getAccount(fromAccountId: accountToMigrate) else {
            return Observable.just("")
        }
        var username = ""
        if !(account.registeredName.isEmpty) {
            username = account.registeredName
        } else if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
            let accountName = userNameData[account.id] as? String,
            !accountName.isEmpty {
            username = accountName
        }
        return Observable.just(username)
    }()

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
    }

    func accountHasPassword() -> Bool {
        guard let account = self.accountService.getAccount(fromAccountId: registeredNamesKey) else {return true}
        return AccountModelHelper(withAccount: account).havePassword
    }

    // MARK: - Actions

    func migrateAccount() {
        self.accountService
            .migrateAccount(accountId: accountToMigrate,
                            password: password.value)
            .subscribe(onNext: { (_) in
                self.migrationState.accept(AccountMigrationState.success)
                self.stateSubject.onNext(AppState.checkAccountsAreReady)
            }, onError: { (_) in
                self.migrationState.accept(AccountMigrationState.error)
            }).disposed(by: self.disposeBag)
    }

    func removeAccount() {
        self.accountService.removeAccount(id: accountToMigrate)
        self.stateSubject.onNext(AppState.checkAccountsAreReady)
    }
}
