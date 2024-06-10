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

class GeneralSettings: ObservableObject {
    @Published var automaticlyDownloadIncomingFiles = UserDefaults.standard.bool(forKey: automaticDownloadFilesKey)

    @Published var downloadLimit = String(UserDefaults.standard.integer(forKey: acceptTransferLimitKey))

    func enableAutomaticlyDownload(enable: Bool) {
        if automaticlyDownloadIncomingFiles == enable {
            return
        }
        UserDefaults.standard.set(enable, forKey: automaticDownloadFilesKey)
        automaticlyDownloadIncomingFiles = enable
    }

    func saveDownloadLimit() {
        UserDefaults.standard.set(Int(downloadLimit) ?? 0, forKey: acceptTransferLimitKey)
    }
}

class AccountSettings: ObservableObject {

    @Published var proxyEnabled: Bool
    @Published var callsFromUnknownContacts: Bool = false
    @Published var autoConnectOnLocalNetwork: Bool = false
    @Published var showNotificationPermitionIssue: Bool = false
    @Published var upnpEnabled: Bool = false
    @Published var turnEnabled: Bool = false

    @Published var turnServer = ""
    @Published var turnUsername = ""
    @Published var turnPassword = ""
    @Published var turnRealm = ""

    var notificationsPermitted: Bool
    let accountService: AccountsService
    let account: AccountModel

    let disposeBag = DisposeBag()

    init(account: AccountModel, injectionBag: InjectionBag) {
        self.account = account
        self.accountService = injectionBag.accountService
        self.proxyEnabled = self.accountService.proxyEnabled(for: self.account.id)
        self.notificationsPermitted = LocalNotificationsHelper.isEnabled()
        self.callsFromUnknownContacts = self.getBoolState(for: ConfigKey.dhtPublicIn)
        self.autoConnectOnLocalNetwork = self.getBoolState(for: ConfigKey.keepAliveEnabled)
        self.upnpEnabled = self.getBoolState(for: ConfigKey.accountUpnpEnabled)
        self.turnEnabled = self.getBoolState(for: ConfigKey.turnEnable)
        turnServer = self.getStringState(for: ConfigKey.turnServer)
        turnUsername = self.getStringState(for: ConfigKey.turnUsername)
        turnPassword = self.getStringState(for: ConfigKey.turnPassword)
        turnRealm = self.getStringState(for: ConfigKey.turnRealm)
        self.verifyNotificationPermissionStatus()
        observeNotificationPermissionChanges()
    }

    private func observeNotificationPermissionChanges() {
        UserDefaults.standard.rx
            .observe(Bool.self, enbleNotificationsKey)
            .subscribe(onNext: { enable in
                if let enable = enable {
                    self.notificationsPermitted = enable
                    self.verifyNotificationPermissionStatus()
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func verifyNotificationPermissionStatus() {
        showNotificationPermitionIssue = self.proxyEnabled && !self.notificationsPermitted
    }

    private func getBoolState(for key: ConfigKey) -> Bool {
        let property = ConfigKeyModel(withKey: key)
        let stringValue = accountService.getCurrentStringValue(property: property, accountId: account.id)
        return stringValue.boolValue
    }

    private func getStringState(for key: ConfigKey) -> String {
        let property = ConfigKeyModel(withKey: key)
        return accountService.getCurrentStringValue(property: property, accountId: account.id)
    }

    func enableNotifications(enable: Bool) {
        if self.proxyEnabled == enable {
            return
        }
        // Register for VOIP Push notifications if needed
        if !self.accountService.hasAccountWithProxyEnabled() && enable == true {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
        }
        self.accountService.changeProxyStatus(accountID: account.id, enable: enable)
        self.proxyEnabled = self.accountService.proxyEnabled(for: self.account.id)

        // Unregister VOIP Push notifications if needed
        if !self.accountService.hasAccountWithProxyEnabled() {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.disablePushNotifications.rawValue), object: nil)
        }
        self.verifyNotificationPermissionStatus()
    }

    func enableCallsFromUnknownContacts(enable: Bool) {
        if self.callsFromUnknownContacts == enable {
            return
        }
        self.accountService.enableCallsFromUnknownContacts(enable: enable, accountId: account.id)
        self.callsFromUnknownContacts = enable
    }

    func enableAutoConnectOnLocalNetwork(enable: Bool) {
        if self.autoConnectOnLocalNetwork == enable {
            return
        }
        self.accountService.enableKeepAlive(enable: enable, accountId: account.id)
        self.autoConnectOnLocalNetwork = enable
    }

    func enableUpnp(enable: Bool) {
        if self.upnpEnabled == enable {
            return
        }
        self.accountService.enableUpnp(enable: enable, accountId: account.id)
        self.upnpEnabled = enable
    }

    func enableTurn(enable: Bool) {
        if self.turnEnabled == enable {
            return
        }
        self.accountService.enableTurn(enable: enable, accountId: account.id)
        self.turnEnabled = enable
    }

    func saveTurnSettings() {
        self.accountService.setTurnSettings(accountId: account.id, server: turnServer, username: turnUsername, password: turnPassword, realm: turnRealm)
    }
}

class AccountSummaryVM: ObservableObject, AvatarViewDataModel {
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

    let disposeBag = DisposeBag()

    let accountService: AccountsService
    let profileService: ProfilesService
    let injectionBag: InjectionBag
    let stateSubject: PublishSubject<State>

    init(injectionBag: InjectionBag, account: AccountModel, stateSubject: PublishSubject<State>) {
        self.account = account
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.injectionBag = injectionBag
        self.jamiId = account.jamiId
        self.stateSubject = stateSubject

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

    func startAccountRemoving() {
        let allAccounts = self.accountService.accounts
        if allAccounts.count < 1 { return }
        if allAccounts.count == 1 {
            UserDefaults.standard.set("", forKey: self.accountService.selectedAccountID)
            self.stateSubject.onNext(MeState.needToOnboard)
            accountRemoved = true
            self.accountService.removeAccount(id: account.id)
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
        self.stateSubject.onNext(MeState.needAccountMigration(accountId: allAccounts[1].id))
    }
}

// MARK: - Account Profile
extension AccountSummaryVM {

    func subscribeProfile() {
        self.profileService.getAccountProfile(accountId: account.id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { [weak self] profile in
                if let imageString = profile.photo,
                   let image = imageString.createImage() {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.profileImage = image
                    }
                }

                if let name = profile.alias {
                    DispatchQueue.main.async {
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
        self.accountService.enableAccount(enable: enable, accountId: account.id)
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
