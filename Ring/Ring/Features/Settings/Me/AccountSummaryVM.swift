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

public enum MeState: State {
    case linkNewDevice
    case blockedContacts
    case needToOnboard
    case accountRemoved
    case accountModeChanged
    case needAccountMigration(accountId: String)
}

class AccountSummaryVM: ObservableObject, AvatarViewDataModel, Stateable {
    let account: AccountModel

    // profile
    @Published var profileImage: UIImage?
    @Published var profileName: String = ""

    @Published var username: String?

    // account status
    @Published var accountStatus: String = ""
    @Published var accountEnabled: Bool

    @Published var jamiId: String = ""

    @Published var accountRemoved: Bool = false

    let avatarSize: CGFloat = 100

    let disposeBag = DisposeBag()

    let accountService: AccountsService
    let profileService: ProfilesService
    let injectionBag: InjectionBag
    //let stateSubject: PublishSubject<State>!

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    init(injectionBag: InjectionBag, account: AccountModel) {
        self.account = account
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.injectionBag = injectionBag
        self.jamiId = account.jamiId

        // account status
        if let details = account.details {
            accountEnabled = details.get(withConfigKeyModel:
                                            ConfigKeyModel.init(withKey: .accountEnable)).boolValue
        } else {
            accountEnabled = false
        }
        self.accountStatus = self.getAccountStatus(state: account.status)
        self.subscribeStatus()

        self.subscribeProfile()
        self.username = extractUsername()
    }

    func extractUsername() -> String? {
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

    var accountInfoToShare: String {
        return self.accountService.accountInfoToShare?.joined(separator: "\n") ?? ""
    }

    func nameRegistered() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.username = self.extractUsername()
        }
    }

    func dismiss() {
        self.stateSubject.onNext(SettingsState.dismiss)
    }

    func removeAccount() {
        let allAccounts = self.accountService.accounts
        if allAccounts.count < 1 { return }
        if allAccounts.count == 1 {
            UserDefaults.standard.set("", forKey: self.accountService.selectedAccountID)
            accountRemoved = true
            self.accountService.removeAccount(id: account.id)
            self.stateSubject.onNext(MeState.needToOnboard)
            return
        }

        for nextAccount in allAccounts where
            (nextAccount != account && !accountService.needAccountMigration(accountId: nextAccount.id)) {
            UserDefaults.standard.set(nextAccount.id, forKey: self.accountService.selectedAccountID)
            self.accountService.currentAccount = nextAccount
            self.accountService.removeAccount(id: account.id)
            accountRemoved = true
            return
        }
        self.accountService.removeAccount(id: account.id)
        accountRemoved = true
        self.stateSubject.onNext(ConversationState.conversationRemoved)
    }
}

// MARK: - Account Profile
extension AccountSummaryVM {

    func subscribeProfile() {
        self.profileService.getAccountProfile(accountId: account.id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                guard let self = self else { return }
                // The view size is avatarSize. Create a larger image for better resolution.
                if let imageString = profile.photo,
                   let image = imageString.createImage(size: self.avatarSize * 2) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.profileImage = image
                    }
                }

                if let name = profile.alias {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.profileName = name
                    }
                }

            }
            .disposed(by: disposeBag)
    }
}

// MARK: - Account Status
extension AccountSummaryVM {
    func enableAccount(enable: Bool) {
        if self.accountEnabled == enable { return }
        accountEnabled = enable
        self.accountService.enableAccount(accountId: account.id, enable: enable)
    }

    func subscribeStatus() {
        self.accountService.sharedResponseStream
            .filter({ [weak self] serviceEvent in
                guard let self = self else { return false }
                guard let _: String = serviceEvent
                        .getEventInput(ServiceEventInput.registrationState) else { return false }
                guard let accountId: String = serviceEvent
                        .getEventInput(ServiceEventInput.accountId),
                      accountId == self.account.id else { return false }
                return true
            })
            .subscribe(onNext: { [weak self] serviceEvent in
                guard let state: String = serviceEvent
                        .getEventInput(ServiceEventInput.registrationState),
                      let accountState = AccountState(rawValue: state) else { return }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.accountStatus = self.getAccountStatus(state: accountState)
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func getAccountStatus(state: AccountState) -> String {
        if !accountEnabled {
            return L10n.Account.statusOffline
        }
        switch state {
        case .registered:
            return L10n.Account.statusOnline
        case .trying:
            return L10n.Account.statusConnecting
        case .errorRequestTimeout, .errorNotAcceptable,
             .errorServiceUnavailable, .errorExistStun,
             .errorConfStun, .errorHost,
             .errorNetwork, .errorAuth, .error:
            return L10n.Account.statusConnectionerror
        default:
            return L10n.Account.statusUnknown
        }
    }
}
