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

import Foundation
import SwiftUI
import RxSwift

protocol AccountProfileObserver: AnyObject {
    var avatar: UIImage? { get set }
    var profileName: String { get set }
    var registeredName: String { get set }
    var bestName: String { get set }
    var profileDisposeBag: DisposeBag { get set }
    var profileService: ProfilesService { get }
    var selectedAccount: String? { get }
    var size: Constants.AvatarSize { get }
}

extension AccountProfileObserver {
    func updateProfileDetails(account: AccountModel) {
        profileDisposeBag = DisposeBag()
        profileService.getAccountProfile(accountId: account.id)
            .subscribe(onNext: { [weak self] profile in
                guard let self = self else { return }
                let avatar = profile.photo?.createImage(size: self.size.points * 2)
                DispatchQueue.main.async { [weak self] in
                    /*
                     Profile updates might be received in a different order than
                     they were called. Verify that the id for the profile
                     matches the selected account.
                     */
                    guard let self = self, account.id == self.selectedAccount else { return
                    }
                    self.avatar = avatar
                    self.profileName = profile.alias ?? ""
                    self.updateBestName()
                }
            })
            .disposed(by: profileDisposeBag)
    }

    func resolveAccountName(from account: AccountModel) -> String {
        if !account.registeredName.isEmpty {
            return account.registeredName
        }
        if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
           let accountName = userNameData[account.id] as? String,
           !accountName.isEmpty {
            return accountName
        }
        return account.jamiId
    }

    func updateBestName() {
        self.bestName = profileName.isEmpty ? registeredName : profileName
    }
}

struct AccountRowSizes {
    let spacing: CGFloat = 7
}

class AccountRow: AvatarProvider, Hashable, Identifiable, AccountProfileObserver {
    let id: String

    @Published var bestName: String = ""
    @Published var needMigrate: String?
    @Published var accountStatus: AccountState
    var selectedAccount: String? // Not used. Added to conform to the AccountProfileObserver protocol.

    var dimensions = AccountRowSizes()

    var disposeBag = DisposeBag()
    var profileDisposeBag = DisposeBag()
    var profileService: ProfilesService
    var account: AccountModel
    private let accountService: AccountsService

    init(account: AccountModel, profileService: ProfilesService, accountService: AccountsService) {
        self.id = account.id
        self.selectedAccount = account.id
        self.profileService = profileService
        self.account = account
        self.accountService = accountService
        self.accountStatus = account.status
        if account.status == .errorNeedMigration {
            needMigrate = L10n.Account.needMigration
        }
        super.init(profileService: profileService, size: Constants.AvatarSize.medium40)
        self.jamiId = account.jamiId

        self.registeredName = resolveAccountName(from: account)
        updateProfileDetails(account: account)
        subscribeToStatusChanges()
    }

    private func subscribeToStatusChanges() {
        accountService.sharedResponseStream
            .filter { [weak self] event in
                guard let self = self else { return false }
                return event.eventType == .registrationStateChanged &&
                    event.getEventInput(ServiceEventInput.accountId) == self.id
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let stateString: String = event.getEventInput(ServiceEventInput.registrationState),
                      let newState = AccountState(rawValue: stateString) else { return }
                self.accountStatus = newState
            })
            .disposed(by: disposeBag)
    }

    func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }

    static func == (lhs: AccountRow, rhs: AccountRow) -> Bool {
        return lhs.id == rhs.id
    }
}

class AccountsViewModel: AvatarProvider, AccountProfileObserver {
    @Published var bestName: String = ""
    @Published var selectedAccount: String?
    @Published var accountsRows: [AccountRow] = []
    @Published var accountStatus: AccountState = .unregistered

    @Published var migrationHandledWithSuccess: Bool?

    let stateEmitter: ConversationStatePublisher

    let headerTitle = L10n.Smartlist.accounts

    var dimensions = AccountRowSizes()

    let accountService: AccountsService
    let profileService: ProfilesService
    let nameService: NameService
    var disposeBag = DisposeBag()
    var profileDisposeBag = DisposeBag()

    init(accountService: AccountsService, profileService: ProfilesService, nameService: NameService, stateEmitter: ConversationStatePublisher) {
        self.accountService = accountService
        self.profileService = profileService
        self.nameService = nameService
        self.stateEmitter = stateEmitter
        super.init(profileService: profileService, size: Constants.AvatarSize.account28)
        if let currentAccount = accountService.currentAccount {
            self.accountStatus = currentAccount.status
        }
        self.subscribeToCurrentAccountUpdates()
        self.subscribeToRegisteredName()
        self.subscribeToStatusChanges()
    }

    private func subscribeToStatusChanges() {
        accountService.sharedResponseStream
            .filter { [weak self] event in
                guard let self = self else { return false }
                return event.eventType == .registrationStateChanged &&
                    event.getEventInput(ServiceEventInput.accountId) == self.selectedAccount
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let stateString: String = event.getEventInput(ServiceEventInput.registrationState),
                      let newState = AccountState(rawValue: stateString) else { return }
                self.accountStatus = newState
            })
            .disposed(by: disposeBag)
    }

    func subscribeToCurrentAccountUpdates() {
        accountService.currentAccountChanged
            .startWith(accountService.currentAccount)
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] account in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.selectedAccount = account.id
                    self.jamiId = account.jamiId
                    self.accountStatus = account.status
                    self.registeredName = self.resolveAccountName(from: account)
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        guard let self = self else { return }
                        self.updateProfileDetails(account: account)
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    func subscribeToRegisteredName() {
        self.nameService.sharedRegistrationStatus
            .filter({ (serviceEvent) -> Bool in
                guard let account = self.accountService.currentAccount else { return false }
                guard serviceEvent.getEventInput(ServiceEventInput.accountId) == account.id,
                      serviceEvent.eventType == .nameRegistrationEnded,
                      let status: NameRegistrationState = serviceEvent.getEventInput(ServiceEventInput.state),
                      status == .success else {
                    return false
                }
                return true
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self,
                      let account = self.accountService.currentAccount else { return }
                self.registeredName = self.resolveAccountName(from: account)
                self.updateProfileDetails(account: account)
            })
            .disposed(by: disposeBag)
    }

    func getAccountsRows() {
        accountsRows = self.accountService.accounts.map { accountModel in
            return AccountRow(account: accountModel, profileService: self.profileService, accountService: self.accountService)
        }
    }

    func changeCurrentAccount(accountId: String) -> Bool {
        guard let account = self.accountService.getAccount(fromAccountId: accountId) else { return false }
        if accountService.needAccountMigration(accountId: accountId) {
            self.stateEmitter.emitState(.migrateAccount(accountId: account.id, completion: { [weak self] state in
                guard let self = self else { return }
                self.migrationHandledWithSuccess = state
            }))
            return false
        }
        self.accountService.updateCurrentAccount(account: account)
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            sharedDefaults.set(accountId, forKey: Constants.selectedAccountID)
            return true
        }
        return false
    }
}
