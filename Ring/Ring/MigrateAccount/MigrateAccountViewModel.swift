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
    case finished
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

    lazy var profileImage: Observable<UIImage?> = {
        return self.profileService
            .getAccountProfile(accountId: accountToMigrate)
            .take(1)
            .map({ profile in
                if let photo = profile.photo,
                    let data = NSData(base64Encoded: photo,
                                      options: NSData.Base64DecodingOptions
                                        .ignoreUnknownCharacters) as Data? {
                    guard let image = UIImage(data: data) else {
                        return UIImage(named: "fallback_avatar")
                    }
                    return image
                }
                return UIImage(named: "fallback_avatar")
            })
        }()

    lazy var profileName: Observable<String> = {
        var displayName = ""
        let details = self.accountService
            .getAccountDetails(fromAccountId: accountToMigrate)
        let name = details
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .displayName))
        if !name.isEmpty {
            displayName = name
        }
        return Observable.just(displayName)
    }()

    lazy var jamiId: Observable<String> = {
        let account = self.accountService
            .getAccount(fromAccountId: accountToMigrate)
        let jamiId = account?.jamiId
        return Observable.just(jamiId ?? "")
    }()

    lazy var notCancelable: Observable<Bool> = {
        let canc = self.accountService.hasValidAccount()
        return Observable.just(!self.accountService.hasValidAccount())
    }()

    lazy var hideMigrateAnotherAccountButton: Observable<Bool> = {
        let show = !self.accountService.hasValidAccount() &&
            self.accountService.accounts.count > 1
        return Observable.just(!show)
    }()

    lazy var username: Observable<String> = {
        guard let account = self.accountService
            .getAccount(fromAccountId: accountToMigrate) else {
                return Observable.just("")
        }
        var username = ""
        if !(account.registeredName.isEmpty) {
            username = account.registeredName
        } else if let userNameData = UserDefaults
                                    .standard
                                    .dictionary(forKey: registeredNamesKey),
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
        guard let account = self.accountService
            .getAccount(fromAccountId: registeredNamesKey) else { return true }
        return AccountModelHelper(withAccount: account).hasPassword
    }

    // MARK: - Actions

    func migrateAccount() {
        self.accountService
            .migrateAccount(account: accountToMigrate,
                            password: password.value)
            .subscribe(onNext: { [weak self] (_) in
                if let migratedAccount = self?.accountToMigrate,
                    let account = self?.accountService.getAccount(fromAccountId: migratedAccount),
                    let selectedAccounKey = self?.accountService.selectedAccountID {
                    UserDefaults.standard.set(migratedAccount, forKey: selectedAccounKey)
                    self?.accountService.currentAccount = account
                }
                DispatchQueue.main.async {
                    self?.migrationState.accept(AccountMigrationState.success)
                    self?.migrationState.accept(AccountMigrationState.finished)
                    self?.stateSubject.onNext(AppState.allSet)
                }
                }, onError: { [weak self] (_) in
                    DispatchQueue.main.async {
                        self?.migrationState.accept(AccountMigrationState.error)
                    }
            })
            .disposed(by: self.disposeBag)
    }

    func removeAccount() {
        self.accountService.removeAccount(id: accountToMigrate)
        if self.accountService.accounts.isEmpty {
            self.migrationState.accept(AccountMigrationState.finished)
            self.stateSubject.onNext(AppState.needToOnboard(animated: false,
                                                            isFirstAccount: true))
            return
        }
        finishWithoutMigration()
    }

    func finishWithoutMigration() {
        if !self.accountService.hasValidAccount() {
            migrateAnotherAccount()
            return
        }
        // choose next available account
        for account in self.accountService.accounts where
            (account.id != accountToMigrate &&
            account.status != .errorNeedMigration) {
                UserDefaults.standard.set(account.id, forKey: self.accountService.selectedAccountID)
                self.accountService.currentAccount = account
                self.migrationState.accept(AccountMigrationState.finished)
                self.stateSubject.onNext(AppState.allSet)
        }
    }

    func migrateAnotherAccount() {
        for account in self.accountService.accounts where
            (account.id != accountToMigrate && account.status == .errorNeedMigration) {
                self.migrationState.accept(AccountMigrationState.finished)
                self.stateSubject
                    .onNext(AppState.needAccountMigration(accountId: account.id))
                return
        }
    }
}
