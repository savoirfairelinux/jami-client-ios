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
    @Published var typingIndicator: Bool = true

    @Published var autoRegistrationEnabled: Bool = false
    @Published var autoRegistrationExpirationTime = ""
    @Published var enableSRTP: Bool = false
    @Published var enableTLS: Bool = false
    @Published var tlsVerifyServer: Bool = true
    @Published var tlsVerifyClient: Bool = true
    @Published var tlsRequireClientCertificate: Bool = true
    @Published var tlsDisableSecureDlgCheck: Bool = true

    // turn
    @Published var turnServer = ""
    @Published var turnUsername = ""
    @Published var turnPassword = ""
    @Published var turnRealm = ""

    // stun
    @Published var stunEnabled: Bool = false
    @Published var stunServer = ""

    // public address
    @Published var allowIPAutoRewrite: Bool = true
    @Published var publishedSameAsLocal: Bool = true
    @Published var publishedAddress = ""
    @Published var publishedPort = ""

    @Published var proxyAddress = ""
    @Published var proxyListUrl = ""
    @Published var currentProxy = ""

    @Published var bootstrap = ""

    @Published var serverName = ""

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
        let stringValue = AccountModelHelper(withAccount: self.account).getCurrentStringValue(property: property)
        return stringValue.boolValue
    }

    private func getStringState(for key: ConfigKey) -> String {
        let property = ConfigKeyModel(withKey: key)
        return AccountModelHelper(withAccount: self.account).getCurrentStringValue(property: property)
    }

    func enableUpnp(enable: Bool) {
        if self.upnpEnabled == enable {
            return
        }
        let property = ConfigKeyModel(withKey: ConfigKey.accountUpnpEnabled)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        self.upnpEnabled = enable
    }

    func enableTurn(enable: Bool) {
        if self.turnEnabled == enable {
            return
        }
        let property = ConfigKeyModel(withKey: ConfigKey.turnEnable)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        self.turnEnabled = enable
    }

    func saveTurnSettings() {
        self.accountService.setTurnSettings(accountId: account.id, server: turnServer, username: turnUsername, password: turnPassword, realm: turnRealm)
    }
}

// MARK: - Jami account
extension AccountSettings {
    private func setUPJamiParameters() {
        self.serverName = self.getStringState(for: .ringNsURI)
        self.proxyEnabled = self.getBoolState(for: .proxyEnabled)
        self.proxyListUrl = self.getStringState(for: ConfigKey.dhtProxyListUrl)
        self.bootstrap = self.getStringState(for: ConfigKey.accountHostname)
        self.proxyListEnabled = self.getBoolState(for: ConfigKey.proxyListEnabled)
        self.proxyAddress = self.getStringState(for: ConfigKey.proxyServer)
        self.currentProxy = self.account.proxy
        self.callsFromUnknownContacts = self.getBoolState(for: ConfigKey.dhtPublicIn)
        self.peerDiscovery = self.getBoolState(for: ConfigKey.dhtPeerDiscovery)
        self.typingIndicator = self.getBoolState(for: ConfigKey.typingIndicator)
        self.verifyNotificationPermissionStatus()
        observeNotificationPermissionChanges()
        observeCurrentProxy()
    }

    func enableCallsFromUnknownContacts(enable: Bool) {
        if self.callsFromUnknownContacts == enable {
            return
        }
        let property = ConfigKeyModel(withKey: ConfigKey.dhtPublicIn)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        self.callsFromUnknownContacts = enable
    }

    func enableTypingIndicator(enable: Bool) {
        if self.typingIndicator == enable {
            return
        }
        let property = ConfigKeyModel(withKey: ConfigKey.typingIndicator)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        self.typingIndicator = enable
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
        let property = ConfigKeyModel(withKey: ConfigKey.dhtPeerDiscovery)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
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
        let property = ConfigKeyModel(withKey: ConfigKey.proxyEnabled)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        self.proxyEnabled = self.getBoolState(for: .proxyEnabled)

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

    private func observeCurrentProxy() {
        self.accountService.sharedResponseStream
            .filter { [weak self] serviceEvent in
                guard let self = self else { return false }
                if serviceEvent.eventType != .registrationStateChanged { return false }
                guard let eventAccountId: String = serviceEvent.getEventInput(.accountId) else { return false }
                return eventAccountId == self.account.id
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.currentProxy = self.account.proxy
            })
            .disposed(by: self.disposeBag)
    }

    func saveProxyAddress() {
        let property = ConfigKeyModel(withKey: ConfigKey.proxyServer)
        self.accountService.setAccountProperty(property: property, value: self.proxyAddress, accountId: account.id)
    }

    func saveBootstrap() {
        let property = ConfigKeyModel(withKey: ConfigKey.accountHostname)
        self.accountService.setAccountProperty(property: property, value: self.bootstrap, accountId: account.id)
    }

    func saveProxyListUrl() {
        let property = ConfigKeyModel(withKey: .dhtProxyListUrl)
        self.accountService.setAccountProperty(property: property, value: self.proxyListUrl, accountId: account.id)
    }

    func saveNameServer() {
        let property = ConfigKeyModel(withKey: ConfigKey.ringNsURI)
        self.accountService.setAccountProperty(property: property, value: self.serverName, accountId: account.id)
    }
}

// MARK: - SIP account
extension AccountSettings {
    private func setUPSIPParameters() {
        self.autoRegistrationEnabled = self.getBoolState(for: ConfigKey.keepAliveEnabled)
        self.autoRegistrationExpirationTime = self.getStringState(for: ConfigKey.registrationExpire)
        self.stunEnabled = self.getBoolState(for: ConfigKey.stunEnable)
        self.stunServer = self.getStringState(for: ConfigKey.stunServer)
        self.allowIPAutoRewrite = self.getBoolState(for: ConfigKey.allowIPAutoRewrite)
        self.publishedSameAsLocal = self.getBoolState(for: ConfigKey.publishedSameAsLocal)
        self.publishedAddress = self.getStringState(for: ConfigKey.publishedAddress)
        self.publishedPort = self.getStringState(for: ConfigKey.publishedPort)
        self.enableSRTP = self.getSRTPEnabled()
        self.enableTLS = self.getBoolState(for: ConfigKey.tlsEnable)
        self.tlsVerifyServer = self.getBoolState(for: ConfigKey.tlsVerifyServer)
        self.tlsVerifyClient = self.getBoolState(for: ConfigKey.tlsVerifyClient)
        self.tlsRequireClientCertificate = self.getBoolState(for: ConfigKey.tlsRequireClientCertificate)
        self.tlsDisableSecureDlgCheck = self.getBoolState(for: ConfigKey.disableSecureDlgCheck)
    }

    func getSRTPEnabled() -> Bool {
        let property = ConfigKeyModel(withKey: .srtpKeyExchange)
        let stringValue = AccountModelHelper(withAccount: self.account).getCurrentStringValue(property: property)
        return stringValue == "sdes"
    }

    func enableSRTP(enable: Bool) {
        if self.enableSRTP == enable { return }
        self.accountService.enableSRTP(enable: enable, accountId: account.id)
        self.enableSRTP = enable
    }

    func enableTLS(enable: Bool) {
        switchSipBoolProperty(ConfigKey.tlsEnable, current: enableTLS, enable: enable) { self.enableTLS = $0 }
    }

    func setTlsVerifyServer(enable: Bool) {
        switchSipBoolProperty(ConfigKey.tlsVerifyServer, current: tlsVerifyServer, enable: enable) { self.tlsVerifyServer = $0 }
    }

    func setTlsVerifyClient(enable: Bool) {
        switchSipBoolProperty(ConfigKey.tlsVerifyClient, current: tlsVerifyClient, enable: enable) { self.tlsVerifyClient = $0 }
    }

    func setTlsRequireClientCertificate(enable: Bool) {
        switchSipBoolProperty(ConfigKey.tlsRequireClientCertificate, current: tlsRequireClientCertificate, enable: enable) {
            self.tlsRequireClientCertificate = $0
        }
    }

    func setTlsDisableSecureDlgCheck(enable: Bool) {
        switchSipBoolProperty(ConfigKey.disableSecureDlgCheck, current: tlsDisableSecureDlgCheck, enable: enable) {
            self.tlsDisableSecureDlgCheck = $0
        }
    }

    private func switchSipBoolProperty(_ key: ConfigKey, current: Bool, enable: Bool, update: (Bool) -> Void) {
        if current == enable { return }
        let property = ConfigKeyModel(withKey: key)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        update(enable)
    }

    func setExpirationTime() {
        let saved = self.getStringState(for: ConfigKey.registrationExpire)
        guard AccountSettings.isValid(autoRegistrationExpirationTime, in: AccountSettings.registrationExpireRange) else {
            autoRegistrationExpirationTime = saved
            return
        }
        if self.autoRegistrationExpirationTime == saved { return }
        let property = ConfigKeyModel(withKey: ConfigKey.registrationExpire)
        self.accountService.setAccountProperty(property: property, value: self.autoRegistrationExpirationTime, accountId: account.id)
    }

    func enableaAtoregister(enable: Bool) {
        if self.autoRegistrationEnabled == enable { return }
        let property = ConfigKeyModel(withKey: ConfigKey.keepAliveEnabled)
        self.accountService.switchAccountPropertyTo(state: enable, accountId: account.id, property: property)
        self.autoRegistrationEnabled = enable
    }

    func enableAllowIPAutoRewrite(enable: Bool) {
        switchSipBoolProperty(ConfigKey.allowIPAutoRewrite, current: allowIPAutoRewrite, enable: enable) {
            self.allowIPAutoRewrite = $0
        }
        if enable {
            enablePublishedSameAsLocal(enable: true)
        }
    }

    func enablePublishedSameAsLocal(enable: Bool) {
        switchSipBoolProperty(ConfigKey.publishedSameAsLocal, current: publishedSameAsLocal, enable: enable) {
            self.publishedSameAsLocal = $0
        }
    }

    func savePublishedAddress() {
        guard !publishedAddress.isEmpty else {
            publishedAddress = getStringState(for: ConfigKey.publishedAddress)
            return
        }
        let property = ConfigKeyModel(withKey: ConfigKey.publishedAddress)
        self.accountService.setAccountProperty(property: property, value: publishedAddress, accountId: account.id)
    }

    func savePublishedPort() {
        guard AccountSettings.isValid(publishedPort, in: AccountSettings.publishedPortRange) else {
            publishedPort = getStringState(for: ConfigKey.publishedPort)
            return
        }
        let property = ConfigKeyModel(withKey: ConfigKey.publishedPort)
        self.accountService.setAccountProperty(property: property, value: publishedPort, accountId: account.id)
    }

    static let publishedPortRange = 0...Int(UInt16.max)
    static let registrationExpireRange = 60...(7 * 24 * 3600)

    static func isValid(_ value: String, in range: ClosedRange<Int>) -> Bool {
        guard let number = Int(value) else { return false }
        return range.contains(number)
    }

    static func isValidStunServer(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        guard let colon = value.firstIndex(of: ":") else { return true }
        let port = value[value.index(after: colon)...]
        return !value[..<colon].isEmpty && isValid(String(port), in: publishedPortRange)
    }

    func enableStun(enable: Bool) {
        switchSipBoolProperty(ConfigKey.stunEnable, current: stunEnabled, enable: enable) {
            self.stunEnabled = $0
        }
    }

    func saveStunSettings() {
        guard AccountSettings.isValidStunServer(stunServer) else {
            stunServer = getStringState(for: ConfigKey.stunServer)
            return
        }
        self.accountService.setStunSettings(accountId: account.id, server: stunServer)
    }
}
