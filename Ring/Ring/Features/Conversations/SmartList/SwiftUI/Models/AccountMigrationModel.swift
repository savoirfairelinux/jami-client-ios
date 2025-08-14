/*
 *  Copyright (C) 2025 - 2025 Savoir-faire Linux Inc.
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
import UIKit
import RxSwift

enum MigrationError: LocalizedError {
    case migrationFailed

    var errorDescription: String? {
        switch self {
        case .migrationFailed:
            return L10n.MigrateAccount.error
        }
    }
}

final class AccountMigrationModel: AvatarProvider {
    @Published var migrationCompleted: Bool = false
    @Published var error: String?
    @Published var jamiId: String = ""
    @Published var needsPassword: Bool = false
    @Published var isLoading: Bool = false

    private(set) var selectedAccount: String?

    private let accountService: AccountsService
    private let profileService: ProfilesService
    private let accountId: String
    private let disposeBag = DisposeBag()
    private let profileDisposeBag = DisposeBag()

    init(accountId: String, accountService: AccountsService, profileService: ProfilesService) {
        self.accountId = accountId
        self.selectedAccount = accountId
        self.accountService = accountService
        self.profileService = profileService
        super.init(profileService: profileService, size: Constants.AvatarSize.account100)
        self.updateAccountInfo()
    }

    func handleMigration(password: String = "") {
        isLoading = true
        error = nil

        accountService.migrateAccount(account: accountId, password: password)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] success in
                guard let self = self else { return }
                self.handleMigrationResult(success)
            }, onError: { [weak self] _ in
                self?.handleMigrationError()
            })
            .disposed(by: disposeBag)
    }

    func removeAccount() {
        accountService.removeAccount(id: accountId)
    }

    func getNextAccountToMigrate() -> String? {
        accountService.accounts.first { account in
            account.id != accountId && account.status == .errorNeedMigration
        }?.id
    }

    func getNextValidAccount() -> String? {
        accountService.accounts.first { account in
            account.id != accountId && account.status != .errorNeedMigration
        }?.id
    }

    private func updateAccountInfo() {
        guard let account = accountService.getAccount(fromAccountId: accountId) else {
            error = MigrationError.migrationFailed.errorDescription
            return
        }

        jamiId = account.jamiId
        needsPassword = AccountModelHelper(withAccount: account).hasPassword
        registeredName = extractUsername() ?? ""
        subscribeProfile()
    }

    private func subscribeProfile() {
        profileService.getAccountProfile(accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                self?.updateProfileInfo(profile)
            }
            .disposed(by: profileDisposeBag)
    }

    private func updateProfileInfo(_ profile: Profile) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let data = profile.photo?.toImageData(),
               let image = self.profileService.getAvatarFor(data, size: self.size.points) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.avatar = image
                }
            }

            if let name = profile.alias {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.profileName = name
                }
            }
        }
    }

    private func extractUsername() -> String? {
        guard let account = accountService.getAccount(fromAccountId: accountId) else {
            return nil
        }

        if !account.registeredName.isEmpty {
            return account.registeredName
        }

        if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
           let accountName = userNameData[account.id] as? String,
           !accountName.isEmpty {
            return accountName
        }

        return nil
    }

    private func handleMigrationResult(_ success: Bool) {

        if success {
            self.updateCurrentAccount()
        } else {
            self.error = MigrationError.migrationFailed.errorDescription
        }

        self.isLoading = false
        self.migrationCompleted = success
    }

    private func handleMigrationError() {
        self.isLoading = false
        self.error = MigrationError.migrationFailed.errorDescription
    }

    private func updateCurrentAccount() {
        guard let account = accountService.getAccount(fromAccountId: accountId) else { return }
        let selectedAccountKey = Constants.selectedAccountID
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.set(accountId, forKey: selectedAccountKey)
        }
        accountService.currentAccount = account
    }
}
