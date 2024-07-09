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

class AccountSettings: ObservableObject {

    @Published var proxyEnabled: Bool = false
    @Published var proxyListEnabled: Bool = false
    @Published var callsFromUnknownContacts: Bool = false
    @Published var peerDiscovery: Bool = false
    @Published var showNotificationPermitionIssue: Bool = false
    @Published var upnpEnabled: Bool = false
    @Published var turnEnabled: Bool = false

    @Published var autoRegistrationEnabled: Bool = false
    @Published var autoRegistrationExpirationTime = ""
    @Published var enableSRTP: Bool = false

    // turn
    @Published var turnServer = ""
    @Published var turnUsername = ""
    @Published var turnPassword = ""
    @Published var turnRealm = ""

    @Published var proxyAddress = ""
    @Published var proxyListUrl = ""

    var notificationsPermitted: Bool = LocalNotificationsHelper.isEnabled()
    let accountService: AccountsService
    let account: AccountModel

    let disposeBag = DisposeBag()

    init(account: AccountModel, injectionBag: InjectionBag) {
        self.account = account
        self.accountService = injectionBag.accountService
        self.setUpInitialParameters()
    }

    private func setUpInitialParameters() {
        self.upnpEnabled = self.getBoolState(for: ConfigKey.accountUpnpEnabled)
        self.turnEnabled = self.getBoolState(for: ConfigKey.turnEnable)
        self.turnServer = self.getStringState(for: ConfigKey.turnServer)
        self.turnUsername = self.getStringState(for: ConfigKey.turnUsername)
        self.turnPassword = self.getStringState(for: ConfigKey.turnPassword)
        self.turnRealm = self.getStringState(for: ConfigKey.turnRealm)
        if self.account.type == .sip {
            setUPSIPParameters()
        } else {
            setUPJamiParameters()
        }
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

// MARK: - Jami account
extension AccountSettings {
    private func setUPJamiParameters() {
        self.proxyEnabled = self.accountService.proxyEnabled(for: self.account.id)
        self.proxyListUrl = self.getStringState(for: ConfigKey.dhtProxyListUrl)
        self.proxyListEnabled = self.getBoolState(for: ConfigKey.proxyListEnabled)
        self.proxyAddress = self.account.proxy//self.getStringState(for: ConfigKey.proxyServer)
        self.callsFromUnknownContacts = self.getBoolState(for: ConfigKey.dhtPublicIn)
        self.peerDiscovery = self.getBoolState(for: ConfigKey.dhtPeerDiscovery)
        self.verifyNotificationPermissionStatus()
        observeNotificationPermissionChanges()
    }

    func enableCallsFromUnknownContacts(enable: Bool) {
        if self.callsFromUnknownContacts == enable {
            return
        }
        self.accountService.enableCallsFromUnknownContacts(enable: enable, accountId: account.id)
        self.callsFromUnknownContacts = enable
    }

    func enableProxyList(enable: Bool) {
        if self.proxyListEnabled == enable {
            return
        }
        let property = ConfigKeyModel(withKey: .proxyListEnabled)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        self.proxyListEnabled = enable
    }

    func enablePeerDiscovery(enable: Bool) {
        if self.peerDiscovery == enable {
            return
        }
        self.accountService.enablePeerDiscovery(enable: enable, accountId: account.id)
        self.peerDiscovery = enable
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

    private func verifyNotificationPermissionStatus() {
        showNotificationPermitionIssue = self.proxyEnabled && !self.notificationsPermitted
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

    func saveProxyAddress() {
        self.accountService.setProxyAddress(accountID: account.id, proxy: self.proxyAddress)
    }

    func saveProxyListUrl() {
        let property = ConfigKeyModel(withKey: .dhtProxyListUrl)
        self.accountService.setAccountProperty(property: property, value: self.proxyListUrl, accountId: account.id)
    }
}

// MARK: - SIP account
extension AccountSettings {
    private func setUPSIPParameters() {
        self.autoRegistrationEnabled = self.getBoolState(for: ConfigKey.keepAliveEnabled)
        self.autoRegistrationExpirationTime = self.getStringState(for: ConfigKey.registrationExpire)
        self.enableSRTP = self.getSRTPEnabled()
    }

    func getSRTPEnabled() -> Bool {
        let property = ConfigKeyModel(withKey: .srtpKeyExchange)
        let stringValue = accountService.getCurrentStringValue(property: property, accountId: account.id)
        return stringValue == "sdes"
    }

    func enableSRTP(enable: Bool) {
        if self.enableSRTP == enable { return }
        self.accountService.enableSRTP(enable: enable, accountId: account.id)
        self.enableSRTP = enable
    }

    func setExpirationTime() {
        let autoRegistrationExpirationTime = self.getStringState(for: ConfigKey.registrationExpire)
        if self.autoRegistrationExpirationTime == autoRegistrationExpirationTime { return }
        let property = ConfigKeyModel(withKey: ConfigKey.registrationExpire)
        self.accountService.setAccountProperty(property: property, value: self.autoRegistrationExpirationTime, accountId: account.id)
    }

    func enableaAtoregister(enable: Bool) {
        if self.autoRegistrationEnabled == enable { return }
        self.accountService.enableKeepAlive(enable: enable, accountId: account.id)
        self.autoRegistrationEnabled = enable
    }
}
