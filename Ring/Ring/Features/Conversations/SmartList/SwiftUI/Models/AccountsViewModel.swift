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
    var avatar: UIImage { get set }
    var profileName: String { get set }
    var registeredName: String { get set }
    var bestName: String { get set }
    var profileDisposeBag: DisposeBag { get set }
    var profileService: ProfilesService { get }
    var selectedAccount: String? { get }
    var avatarSize: CGFloat { get }
}

extension AccountProfileObserver {
    func updateProfileDetails(account: AccountModel) {
        profileDisposeBag = DisposeBag()
        profileService.getAccountProfile(accountId: account.id)
            .subscribe(onNext: { [weak self] profile in
                guard let self = self else { return }
                // The view size is avatarSize. Create a larger image for better resolution.
                let avatar = profile.photo?.createImage(size: self.avatarSize * 2) ?? UIImage.defaultJamiAvatarFor(profileName: profile.alias, account: account, size: 17)
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
    let imageSize: CGFloat = 28
    let spacing: CGFloat = 15
}

class AccountRow: ObservableObject, Hashable, Identifiable, AccountProfileObserver {
    let id: String

    @Published var avatar = UIImage()
    @Published var profileName: String = ""
    @Published var registeredName: String = ""
    @Published var bestName: String = ""
    @Published var needMigrate: String?
    var avatarSize: CGFloat
    var selectedAccount: String? // Not used. Added to conform to the AccountProfileObserver protocol.

    var dimensions = AccountRowSizes()

    var disposeBag = DisposeBag()
    var profileDisposeBag = DisposeBag()
    var profileService: ProfilesService
    var account: AccountModel

    init(account: AccountModel, profileService: ProfilesService) {
        self.id = account.id
        self.selectedAccount = account.id
        self.profileService = profileService
        self.account = account
        self.avatarSize = self.dimensions.imageSize
        if account.status == .errorNeedMigration {
            needMigrate = L10n.Account.needMigration
        }

        self.registeredName = resolveAccountName(from: account)
        updateProfileDetails(account: account)
    }

    func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }

    static func == (lhs: AccountRow, rhs: AccountRow) -> Bool {
        return lhs.id == rhs.id
    }
}

class AccountsViewModel: ObservableObject, AccountProfileObserver {
    @Published var avatar = UIImage()
    @Published var profileName: String = ""
    @Published var registeredName: String = ""
    @Published var bestName: String = ""
    var avatarSize: CGFloat
    @Published var selectedAccount: String?
    @Published var accountsRows: [AccountRow] = []

    @Published var migrationCompleted: Bool = false

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
        self.avatarSize = self.dimensions.imageSize
        self.subscribeToCurrentAccountUpdates()
        self.subscribeToRegisteredName()
    }

    func subscribeToCurrentAccountUpdates() {
        accountService.currentAccountChanged
            .startWith(accountService.currentAccount)
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] account in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.selectedAccount = account.id
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
            return AccountRow(account: accountModel, profileService: self.profileService)
        }
    }

    func changeCurrentAccount(accountId: String) -> Bool {
        guard let account = self.accountService.getAccount(fromAccountId: accountId) else { return false }
        if true {
            self.stateEmitter.emitState(.migrateAccount(accountId: account.id, completion: { [weak self] in
                guard let self = self else { return }
                self.migrationCompleted = true
            }))
            return false
        }
        self.accountService.updateCurrentAccount(account: account)
        UserDefaults.standard.set(accountId, forKey: self.accountService.selectedAccountID)
        return true
    }
}

