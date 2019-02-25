/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

enum ActionsState {
    case deviceRevokedWithSuccess(deviceId: String)
    case deviceRevokationError(deviceId: String, errorMessage: String)
    case showLoading
    case hideLoading
    case noAction
}

class MeViewModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let disposeBag = DisposeBag()
    var needToRebind = PublishSubject<Bool>()

    let accountService: AccountsService
    let nameService: NameService

     // MARK: - configure table sections

    var showActionState = Variable<ActionsState>(.noAction)

    public func getRingId() -> String? {
        if let uri = self.accountService.currentAccount?.details?.get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername)) {
            let ringId = uri.replacingOccurrences(of: "ring:", with: "")
            return ringId
        }
        return nil
    }

    lazy var accountCredentials: Observable<SettingsSection> = {
        return Observable
            .combineLatest(userName.startWith(""), ringId.startWith("")) { (name, ringID) in
                var items: [SettingsSection.SectionRow] =  [.sectionHeader(title: L10n.AccountPage.credentialsHeader),
                                                        .ordinary(label: "ID: " + ringID)]
            if !name.isEmpty {
                items.append(.ordinary(label: L10n.AccountPage.username + " " + name))
            } else {
                items.append(.ordinary(label: L10n.AccountPage.usernameNotRegistered))
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
            .just(.accountSettings( items: [.sectionHeader(title: L10n.AccountPage.settingsHeader),
                                            .notifications]))
    }()

    lazy var contactSettings: Observable<SettingsSection> = {
        return Observable
            .just(.accountSettings( items: [.sectionHeader(title: L10n.AccountPage.contactManagementTitle),
                                            .blockedList]))
    }()

    lazy var havePassord: Bool = {
        guard let currentAccount = self.accountService.currentAccount else {return true}
        return AccountModelHelper(withAccount: currentAccount).havePassword
    }()

    lazy var settings: Observable<[SettingsSection]> = {
        Observable.combineLatest(accountCredentials,
                                 linkNewDevice,
                                 linkedDevices,
                                 accountSettings,
                                 contactSettings) { (credentials, linkNew, devices, settings, contacts) in
            return [credentials, devices, linkNew, settings, contacts]
        }
    }()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.accountService.currentAccountChanged
            .subscribe(onNext: { [unowned self] account in
                if let currentAccount = account {
                    self.updateDataFor(account: currentAccount)
                }
            }).disposed(by: self.disposeBag)
    }

    func updateDataFor(account: AccountModel) {
        if let accountName = account.volatileDetails?.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRegisteredName)) {
            currentAccountUserName.onNext(accountName)
        } else if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
            let accountName = userNameData[account.id] as? String,
            !accountName.isEmpty {
            currentAccountUserName.onNext(accountName)
        } else {
            currentAccountUserName.onNext("")
        }
        if let jamiId =  AccountModelHelper.init(withAccount: account).ringId {
            currentAccountJamiId.onNext(jamiId)
        } else {
            currentAccountJamiId.onNext("")
        }
        self.accountService.devicesObservable(account: account)
            .subscribe(onNext: { [unowned self] devices in
                self.currentAccountDevices.onNext(devices)
            }).disposed(by: self.disposeBag)
        self.accountService.proxyEnabled(accountID: account.id)
            .asObservable()
            .subscribe(onNext: { [unowned self] enable in
                self.currentAccountProxy.onNext(enable)
            }).disposed(by: self.disposeBag)
    }

    func linkDevice() {
        self.stateSubject.onNext(MeState.linkNewDevice)
    }

    func showBlockedContacts() {
        self.stateSubject.onNext(MeState.blockedContacts)
    }

    func revokeDevice(deviceId: String, accountPassword password: String) {
        guard let accountId = self.accountService.currentAccount?.id else {
            self.showActionState.value = .hideLoading
            return
        }
        self.accountService.sharedResponseStream
            .filter({ (deviceEvent) -> Bool in
                return deviceEvent.eventType == ServiceEventType.deviceRevocationEnded
                    && deviceEvent.getEventInput(.id) == accountId
            })
            .subscribe(onNext: { [unowned self] deviceEvent in
                if let state: Int = deviceEvent.getEventInput(.state),
                    let deviceID: String = deviceEvent.getEventInput(.deviceId) {
                    switch state {
                    case DeviceRevocationState.success.rawValue:
                        self.showActionState.value = .deviceRevokedWithSuccess(deviceId: deviceID)
                    case DeviceRevocationState.wrongPassword.rawValue:
                        self.showActionState.value = .deviceRevokationError(deviceId:deviceID, errorMessage: L10n.AccountPage.deviceRevocationWrongPassword)
                    case DeviceRevocationState.unknownDevice.rawValue:
                        self.showActionState.value = .deviceRevokationError(deviceId:deviceID, errorMessage: L10n.AccountPage.deviceRevocationUnknownDevice)
                    default:
                        self.showActionState.value = .deviceRevokationError(deviceId:deviceID, errorMessage: L10n.AccountPage.deviceRevocationError)
                    }
                }
            }).disposed(by: self.disposeBag)
        self.accountService.revokeDevice(for: accountId, withPassword: password, deviceId: deviceId)
    }

    // MARK: update for celected account
    let currentAccountUserName = PublishSubject<String>()
    let currentAccountJamiId = PublishSubject<String>()
    let currentAccountDevices = PublishSubject<[DeviceModel]>()
    let currentAccountProxy = PublishSubject<Bool>()

    lazy var userName: Observable<String> = { [unowned self] in
        var initialValue: String = ""
        if let account = self.accountService.currentAccount {
            if !account.registeredName.isEmpty {
                initialValue = account.registeredName
            } else if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
                let accountName = userNameData[account.id] as? String,
                !accountName.isEmpty {
                initialValue = accountName
            }
        }
        return currentAccountUserName.share().startWith(initialValue)
    }()

    lazy var ringId: Observable<String> = { [unowned self] in
        var initialValue: String = ""
        if let account = self.accountService.currentAccount {
            let jamiId = account.jamiId
            initialValue = jamiId
        }
        return currentAccountJamiId.share().startWith(initialValue)
    }()

    lazy var linkedDevices: Observable<SettingsSection> = { [unowned self] in
        let empptySection: SettingsSection =
            .linkedDevices(items: [.ordinary(label: "")])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
            if let account = self.accountService.currentAccount {
                self.accountService.devicesObservable(account: account)
                    .take(1)
                    .subscribe(onNext: { [unowned self] profile in
                        self.currentAccountDevices.onNext(profile)
                    }).disposed(by: self.disposeBag)
            }
        })
        return self.currentAccountDevices.share()
            .map { devices -> SettingsSection in
                var rows: [SettingsSection.SectionRow]?

                if !devices.isEmpty {
                    rows = [.device(device: devices[0])]
                    for deviceIndex in 1 ..< devices.count {
                        let device = devices[deviceIndex]
                        rows!.append (.device(device: device))
                    }
                }
                if rows != nil {
                    rows?.insert(.sectionHeader(title: L10n.AccountPage.devicesListHeader), at: 0)
                    let devicesSection: SettingsSection = .linkedDevices(items: rows!)
                    return devicesSection
                }
                return empptySection
        }
        }()

    lazy var proxyEnabled: Observable<Bool> = { [unowned self] in
        if let account = self.accountService.currentAccount {
            self.accountService.proxyEnabled(accountID: account.id)
                .asObservable()
                .take(1)
                .subscribe(onNext: { [unowned self] enable in
                    self.currentAccountProxy.onNext(enable)
                }).disposed(by: self.disposeBag)
        }
        return currentAccountProxy.share()
    }()

    // MARK: Notifications

    lazy var notificationsEnabled: Observable<Bool> = {
        return Observable.combineLatest(self.notificationsPermitted.asObservable(),
                                        self.proxyEnabled.asObservable()) { (notifications, proxy) in
                                            return notifications && proxy

        }
    }()

    lazy var notificationsPermitted: Variable<Bool> = {
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

    func enableNotifications(enable: Bool) {
        guard let account = self.accountService.currentAccount else {return}
        if !self.accountService.proxyEnabled() && enable == true {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
        }
        self.accountService.changeProxyStatus(accountID: account.id, enable: enable)
    }
}
