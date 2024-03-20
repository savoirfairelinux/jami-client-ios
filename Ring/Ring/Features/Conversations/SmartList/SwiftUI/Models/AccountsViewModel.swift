//
//  AccountListViewModel.swift
//  Ring
//
//  Created by kateryna on 2024-04-01.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI
import RxSwift

protocol AccountProfileObserver: AnyObject {
    var avatar: UIImage { get set }
    var profileName: String { get set }
    var registeredName: String { get set }
    var disposeBag: DisposeBag { get }
    var profileService: ProfilesService { get }
}

extension AccountProfileObserver {
    func updateProfileDetails(account: AccountModel) {
        profileService.getAccountProfile(accountId: account.id)
            .subscribe(onNext: { profile in
                let avatar = profile.photo?.createImage() ?? UIImage.defaultJamiAvatarFor(profileName: profile.alias, account: account, size: 17)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.avatar = avatar
                    self.profileName = profile.alias ?? ""
                }
            })
            .disposed(by: disposeBag)
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
}

class AccountRow: ObservableObject, Hashable, Identifiable, AccountProfileObserver {
    let id: String

    @Published var avatar = UIImage()
    @Published var profileName: String = ""
    @Published var registeredName: String = ""
    @Published var needMigrate: String?

    var disposeBag = DisposeBag()
    var profileService: ProfilesService
    var account: AccountModel

    init(account: AccountModel, profileService: ProfilesService) {
        self.id = account.id
        self.profileService = profileService
        self.account = account
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
    @Published var profileName = ""
    @Published var registeredName: String = ""
    @Published var selectedAccount: String?
    @Published var accountsRows: [AccountRow] = []

    let accountService: AccountsService
    let profileService: ProfilesService
    var disposeBag = DisposeBag()

    init(accountService: AccountsService, profileService: ProfilesService) {
        self.accountService = accountService
        self.profileService = profileService
        self.subscribeToCurrentAccountUpdates()
    }

    func subscribeToCurrentAccountUpdates() {
        accountService.currentAccountChanged
            .startWith(accountService.currentAccount)
            .compactMap { $0 } // Ensures we only proceed with non-nil accounts
            .subscribe(onNext: { [weak self] account in
                guard let self = self else { return }
                self.selectedAccount = account.id
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

    func changeCurrentAccount(accountId: String) {
        if let account = self.accountService.getAccount(fromAccountId: accountId) {
            if accountService.needAccountMigration(accountId: accountId) {
//                self.stateSubject.onNext(ConversationState.needAccountMigration(accountId: accountId))
                return
            }
            self.accountService.updateCurrentAccount(account: account)
            UserDefaults.standard.set(accountId, forKey: self.accountService.selectedAccountID)
        }
    }
}
