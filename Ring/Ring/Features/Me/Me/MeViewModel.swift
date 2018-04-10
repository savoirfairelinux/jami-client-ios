/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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
import RxSwift
import RxDataSources

enum SettingsSection: SectionModelType {

    typealias Item = SectionRow

    case linkedDevices(items: [SectionRow])
    case linkNewDevice(items: [SectionRow])
    case accountSettings(items: [SectionRow])
    case credentials(items: [SectionRow])

    enum SectionRow {
        case device(device: DeviceModel)
        case linkNew
        case proxy
        case blockedList
        case sectionHeader(title: String)
        case ordinary(label: String)
        case notifications
    }

    var items: [SectionRow] {
        switch self {
        case .linkedDevices(let items):
            return items
        case .linkNewDevice(let items):
            return items
        case .accountSettings(let items):
            return items
        case .credentials(let items):
            return items
        }
    }

    public init(original: SettingsSection, items: [SectionRow]) {
        switch original {
        case .linkedDevices:
            self = .linkedDevices(items: items)
        case .linkNewDevice:
            self = .linkNewDevice(items: items)
        case .accountSettings:
            self = .accountSettings(items: items)
        case .credentials:
            self = .credentials(items: items)
        }
    }
}

class MeViewModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let disposeBag = DisposeBag()

    let accountService: AccountsService
    let nameService: NameService

     // MARK: - configure table sections

    lazy var userName: Observable<String> = {
        // return username if exists, is no start name lookup
        guard let account = self.accountService.currentAccount else {
            return Observable.just("")
        }
        let accountName = account.volatileDetails?.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRegisteredName))
        if let accountName = accountName, !accountName.isEmpty {
            return Observable.just(accountName)
        }
        let accountHelper = AccountModelHelper(withAccount: account)
        guard let uri = accountHelper.ringId else {
            return Observable.just("")
        }
        let time = DispatchTime.now() + 2
        DispatchQueue.main.asyncAfter(deadline: time) {
            self.nameService.lookupAddress(withAccount: "", nameserver: "", address: uri)
        }
        return self.nameService.usernameLookupStatus
            .filter({ lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == uri && lookupNameResponse.state == .found
            })
            .map({ lookupNameResponse in
                return lookupNameResponse.name
            })
    }()

    lazy var ringId: Observable<String> = {
        if let uri = self.accountService.currentAccount?.details?.get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername)) {
            let ringId = uri.replacingOccurrences(of: "ring:", with: "")
            return Observable.just(ringId)
        }
        return Observable.just("")
    }()

    lazy var accountCredentials: Observable<SettingsSection> = {
        return Observable
            .combineLatest(userName.startWith(""), ringId.startWith("")) { (name, ringID) in
            var items: [SettingsSection.SectionRow] =  [.sectionHeader(title: L10n.Accountpage.credentialsHeader),
                                                        .ordinary(label: "ringID: " + ringID)]
            if !name.isEmpty {
                items.append(.ordinary(label: L10n.Accountpage.username + " " + name))
            } else {
                items.append(.ordinary(label: L10n.Accountpage.usernameNotRegistered))
            }
            return SettingsSection
                .credentials(items: items)
        }
    }()

    lazy var linkNewDevice: Observable<SettingsSection> = {
        return Observable.just(.linkNewDevice(items: [.linkNew]))
    }()

    lazy var accountSettings: Observable<SettingsSection> = {
        return Observable
            .just(.accountSettings( items: [.sectionHeader(title: L10n.Accountpage.settingsHeader),
                                            .blockedList, .proxy, .notifications]))
    }()

    lazy var linkedDevices: Observable<SettingsSection> = {
        // if account does not exist or devices list empty return empty section
        let empptySection: SettingsSection = .linkedDevices(items: [.ordinary(label: "")])
        guard let account = self.accountService.currentAccount else {
            return Observable.just(empptySection)
        }
        return self.accountService.devicesObservable(account: account)
            .map { devices -> SettingsSection in
                var rows: [SettingsSection.SectionRow]?

                if !devices.isEmpty {
                    rows = [.device(device: devices[0])]
                    for i in 1 ..< devices.count {
                        let device = devices[i]
                        rows!.append (.device(device: device))
                    }
                }
                if rows != nil {
                    rows?.insert(.sectionHeader(title: L10n.Accountpage.devicesListHeader), at: 0)
                    let devicesSection: SettingsSection = .linkedDevices(items: rows!)
                    return devicesSection
                }
                return empptySection
        }
    }()

    lazy var settings: Observable<[SettingsSection]> = {
        Observable.combineLatest(accountCredentials,
                                 linkNewDevice,
                                 linkedDevices,
                                 accountSettings) { (credentials, linkNew, devices, settings) in
            return [credentials, devices, linkNew, settings]
        }
    }()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
    }

    func linkDevice() {
        self.stateSubject.onNext(MeState.linkNewDevice)
    }

    func showBlockedContacts() {
        self.stateSubject.onNext(MeState.blockedContacts)
    }

    // MARK: - DHT Proxy

    lazy var proxyEnabled: Variable<Bool> = {
        if let account = self.accountService.currentAccount {
            return self.accountService.proxyEnabled(accountID: account.id)
        }
        return Variable<Bool>(false)
    }()

    lazy var proxyAddress: Variable<String> = {
        if let account = self.accountService.currentAccount {
            return self.accountService.proxyAddress(accountID: account.id)
        }
        return Variable<String>("")
    }()

    lazy var proxyDisplaybele: Observable<String> = {
        return Observable.combineLatest(self.proxyAddress.asObservable(),
                                        self.proxyEnabled.asObservable()) { (address, proxy) in
                                            if !proxy {
                                                return ""
                                            }
                                            return address

        }
    }()

    func changeProxyAvailability(enable: Bool, proxyAddress: String) {
        guard let account = self.accountService.currentAccount else {
            return
        }
        self.accountService.changeProxyAvailability(accountID: account.id, enable: enable, proxyAddress: proxyAddress)
    }

    func changeProxyAddress(address: String) {
        guard let account = self.accountService.currentAccount else {
            return
        }
        self.accountService.updateProxyAddress(address: address, accountID: account.id)
    }

    // MARK: - Push Notifications

    lazy var notificationsEnabled: Variable<Bool> = {
        if let account = self.accountService.currentAccount {
            return self.accountService.pushNotificationsEnabled(accountID: account.id)
        }
        return Variable<Bool>(false)
    }()

    func enablePushNotifications(enable: Bool) {
        if enable {
             NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.disablePushNotifications.rawValue), object: nil)
    }

    // MARK: - Local Notifications

    lazy var localNotificationsEnabled: Variable<Bool> = {
        let variable = Variable<Bool>(LocalNotificationsHelper.isEnabled())
        UserDefaults.standard.rx
            .observe(Bool.self, enbleNotificationsKey)
            .subscribe(onNext: { enable in
                if let enable = enable {
                    variable.value = enable
                }
            }).disposed(by: self.disposeBag)
        return variable
    }()

    func localNotifications(enable: Bool) {
        let currentNotificationsState = LocalNotificationsHelper.isEnabled()
        if enable == currentNotificationsState {return}
        if !enable {
            DispatchQueue.main.async { [weak self] in
                self?.notificationsEnabled.value = currentNotificationsState
                guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsUrl, completionHandler: nil)
                    } else {
                        UIApplication.shared.openURL(settingsUrl as URL)
                    }
                }
            }
        } else {
            self.enableLocalNotifications()
        }
    }

    func enableLocalNotifications() {
        if #available(iOS 10.0, *) {
            let current = UNUserNotificationCenter.current()
            current.getNotificationSettings(completionHandler: { [weak self] settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    break
                case .denied:
                    DispatchQueue.main.async {
                        let enabled = LocalNotificationsHelper.isEnabled()
                        self?.notificationsEnabled.value = enabled
                        guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                            return
                        }
                        if UIApplication.shared.canOpenURL(settingsUrl) {
                            UIApplication.shared.open(settingsUrl, completionHandler: nil)
                        }
                    }
                case .authorized:
                    break
                }
            })
        } else {
            if !UIApplication.shared.isRegisteredForRemoteNotifications {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
            }
        }
    }
}
