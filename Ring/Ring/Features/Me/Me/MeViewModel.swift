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
import RxCocoa
import RxDataSources

// swiftlint:disable file_length
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
        case removeAccount
        case shareAccountDetails
        case sectionHeader(title: String)
        case ordinary(label: String)
        case jamiID(label: String)
        case jamiUserName(label: String)
        case notifications
        case sipUserName(value: String)
        case sipPassword(value: String)
        case sipServer(value: String)
        case port(value: String)
        case proxyServer(value: String)
        case accountState(state: Variable<String>)
        case enableAccount
        case changePassword
        case boothMode
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
    case usernameRegistered
    case usernameRegistrationFailed(errorMessage: String)
    case noAction
}

// swiftlint:disable type_body_length
class MeViewModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let disposeBag = DisposeBag()
    var tempBag = DisposeBag()

    let accountService: AccountsService
    let nameService: NameService
    let contactService: ContactsService
    let presenceService: PresenceService

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
                                                        .jamiID(label: ringID)]
                items.append(.jamiUserName(label: name))
                items.append(.shareAccountDetails)
            return SettingsSection
                .credentials(items: items)
        }
    }()

    var accountInfoToShare: [Any]? {
        var info = [String]()
        guard let account = self.accountService.currentAccount else {return nil}
        var nameToContact = ""
        if self.isAccountSip.value {
            guard let accountDetails = account.details,
                let credentials = account.credentialDetails.first else {return nil}
            if AccountModelHelper.init(withAccount: account).isAccountRing() {
                return nil
            }
            let username = credentials.username
            let server = accountDetails.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountHostname))
            if username.isEmpty || server.isEmpty {
                return nil
            }
            nameToContact = username + "@" + server
        }
        if !account.registeredName.isEmpty {
            nameToContact = account.registeredName
        } else if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
            let accountName = userNameData[account.id] as? String,
            !accountName.isEmpty {
            nameToContact = accountName
        }
        if nameToContact.isEmpty {
            nameToContact = account.jamiId
        }
        let title = L10n.AccountPage.contactMeOnJamiContant(nameToContact)
        info.append(title)
        return info
    }

    lazy var linkNewDevice: Observable<SettingsSection> = {
        return Observable.just(.linkNewDevice(items: [.linkNew]))
    }()

    lazy var removeAccount: Observable<SettingsSection> = {
        return Observable
            .just(.accountSettings( items: [.sectionHeader(title: ""),
                                            .ordinary(label: L10n.AccountPage.removeAccountTitle)]))
    }()

    lazy var accountStatus: Variable<String> = {
        let accStatus = Variable<String>("")
        Observable
            .combineLatest(accountState,
                           accountEnabled.asObservable()) { (state, enabled) -> String in
                            if !enabled {
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
            }.subscribe(onNext: { status in
                accStatus.value = status
            }).disposed(by: self.disposeBag)
        return accStatus
    }()

    lazy var accountJamiSettings: Observable<SettingsSection> = {
        return Observable
            .just(.accountSettings( items: [.sectionHeader(title: L10n.AccountPage.settingsHeader),
                                            .notifications]))
    }()

    lazy var otherJamiSettings: Observable<SettingsSection> = {
        return Observable
            .just(SettingsSection.accountSettings( items: [.sectionHeader(title: L10n.AccountPage.other),
                                                           .blockedList,
                                                           .accountState(state: self.accountStatus),
                                                           .enableAccount,
                                                           .changePassword,
                                                           .boothMode,
                                                           .removeAccount]))
    }()

    func hasPassword() -> Bool {
        guard let currentAccount = self.accountService.currentAccount else {return true}
        return AccountModelHelper(withAccount: currentAccount).hasPassword
    }

    lazy var jamiSettings: Observable<[SettingsSection]> = {
        Observable.combineLatest(accountCredentials,
                                 linkNewDevice,
                                 linkedDevices,
                                 accountJamiSettings,
                                 otherJamiSettings) { (credentials, linkNew, devices, settings, other) in
            return [credentials, devices, linkNew, settings, other]
        }
    }()

    let isAccountSip = Variable<Bool>(false)
    var sipInfoUpdated = BehaviorSubject<Bool>(value: true)

    lazy var otherSipSettings: Observable<SettingsSection> = {
        return Observable
            .just(SettingsSection.accountSettings( items: [.sectionHeader(title: ""),
                                            .accountState(state: self.accountStatus),
                                            .enableAccount,
                                            .removeAccount]))
    }()

    lazy var sipCredentials: Observable<SettingsSection> = {
        return sipInfoUpdated.map {_ in
            var username = ""
            var password = ""
            var server = ""
            var port = ""
            var proxyServer = ""
            if let account = self.accountService.currentAccount,
                let details = account.details,
                let credentials = account.credentialDetails.first {
                username = credentials.username
                password = credentials.password
                server = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountHostname))
                port = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .localPort))
                proxyServer = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountRouteSet))
                self.sipUsername.value = username
                self.sipPassword.value = password
                self.sipServer.value = server
                self.port.value = port
                self.proxyServer.value = proxyServer
            }
            //isIP2IP
            if server.isEmpty {
                return .accountSettings( items: [.sectionHeader(title: ""),
                                                 .sipUserName(value: username),
                                                 .sipPassword(value: password),
                                                 .sipServer(value: server),
                                                 .shareAccountDetails])
            }
            return .accountSettings( items: [.sectionHeader(title: ""),
                                             .sipUserName(value: username),
                                             .sipPassword(value: password),
                                             .sipServer(value: server),
                                             .port(value: port),
                                             .proxyServer(value: proxyServer),
                                             .shareAccountDetails])
        }
    }()

    lazy var sipSettings: Observable<[SettingsSection]> = {
        Observable.combineLatest(sipCredentials,
                                 otherSipSettings) { (credentials, other) in
                                    return [credentials, other]
        }
    }()

    lazy var settings: Observable<[SettingsSection]> = {
        self.accountService.currentAccountChanged
            .subscribe(onNext: { [unowned self] account in
                if let currentAccount = account {
                    self.updateDataFor(account: currentAccount)
                }
            }).disposed(by: self.disposeBag)
        if let account = self.accountService.currentAccount {
            self.isAccountSip.value = account.type == AccountType.sip
        }
        return Observable.combineLatest(jamiSettings, sipSettings,
                                        isAccountSip.asObservable()) {(jami, sip, isSip) in
                                            if isSip == true {
                                                return sip
                                            }
                                            return jami
        }
    }()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.contactService = injectionBag.contactsService
        self.presenceService = injectionBag.presenceService
        self.secureTextEntry.onNext(true)
    }

    func updateDataFor(account: AccountModel) {
        tempBag = DisposeBag()
        self.currentAccountState.onNext(account.status)
        self.secureTextEntry.onNext(true)
        self.accountEnabled.value = account.enabled
        // subscribe for updating status for current account
        self.accountService.sharedResponseStream
            .filter({ serviceEvent in
                guard let _: String = serviceEvent
                    .getEventInput(ServiceEventInput.registrationState) else {return false}
                guard let accountId: String = serviceEvent
                    .getEventInput(ServiceEventInput.accountId),
                    accountId == account.id else {return false}
                return true
            }).subscribe(onNext: { serviceEvent in
                guard let state: String = serviceEvent
                    .getEventInput(ServiceEventInput.registrationState),
                    let accountState = AccountState(rawValue: state) else {return}
                self.currentAccountState.onNext(accountState)
            }).disposed(by: self.tempBag)
        self.isAccountSip.value = account.type == AccountType.sip
        if account.type == AccountType.sip {
            sipInfoUpdated.onNext(true)
            return
        }
        self.nameService.sharedRegistrationStatus
            .filter { (serviceEvent) -> Bool in
                if serviceEvent.getEventInput(ServiceEventInput.accountId) != account.id {return false}
                if serviceEvent.eventType != .nameRegistrationEnded {
                    return false
                }
                return true
            }.subscribe(onNext: { [unowned self] _ in
                if  !self.userNameForAccount(account: account).isEmpty {
                    self.currentAccountUserName
                        .onNext(self.userNameForAccount(account: account))
                }
                }, onError: { _ in
            }).disposed(by: self.tempBag)
        self.currentAccountUserName
            .onNext(self.userNameForAccount(account: account))
        if let jamiId =  AccountModelHelper.init(withAccount: account).ringId {
            currentAccountJamiId.onNext(jamiId)
        } else {
            currentAccountJamiId.onNext("")
        }
        self.accountService.devicesObservable(account: account)
            .subscribe(onNext: { [unowned self] devices in
                self.currentAccountDevices.onNext(devices)
            }).disposed(by: self.tempBag)
        self.accountService.proxyEnabled(accountID: account.id)
            .asObservable()
            .subscribe(onNext: { [unowned self] enable in
                self.notificationsEnabled = enable
                self.currentAccountProxy.onNext(enable)
            }).disposed(by: self.tempBag)
    }

    func userNameForAccount(account: AccountModel) -> String {
        if let accountName = account.volatileDetails?.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRegisteredName)),
            !accountName.isEmpty {
            return accountName
        } else if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
            let accountName = userNameData[account.id] as? String,
            !accountName.isEmpty {
            return accountName
        }
        return ""
    }

    func linkDevice() {
        self.stateSubject.onNext(MeState.linkNewDevice)
    }

    func showBlockedContacts() {
        self.stateSubject.onNext(MeState.blockedContacts)
    }
    //rigistering username
    let newUsername = BehaviorRelay<String>(value: "")
    let usernameValidationState = BehaviorRelay<UsernameValidationState>(value: .unknown)

    func subscribeForNameLokup(disposeBug: DisposeBag) {
        newUsername.asObservable().subscribe(onNext: { [unowned self] username in
            self.nameService.lookupName(withAccount: "", nameserver: "", name: username)
        }).disposed(by: disposeBug)

        nameService.usernameValidationStatus.asObservable().subscribe(onNext: {[weak self] (status) in
            switch status {
            case .lookingUp:
                self?.usernameValidationState.accept(.lookingForAvailibility(message: L10n.CreateAccount.lookingForUsernameAvailability))
            case .invalid:
                self?.usernameValidationState.accept(.invalid(message: L10n.CreateAccount.invalidUsername))
            case .alreadyTaken:
                self?.usernameValidationState.accept(.unavailable(message: L10n.CreateAccount.usernameAlreadyTaken))
            default:
                self?.usernameValidationState.accept(.available)
            }
        }).disposed(by: disposeBug)
    }

    func registerUsername(username: String, password: String) {
        guard let accountId = self.accountService.currentAccount?.id else {
            self.showActionState.value = .hideLoading
            return
        }

        self.nameService
            .registerNameObservable(withAccount: accountId,
                                    password: password,
                                    name: username)
            .subscribe(onNext: { registered in
                if registered {
                    if let account = self.accountService.getAccount(fromAccountId: accountId) {
                        self.currentAccountUserName
                            .onNext(self.userNameForAccount(account: account))
                    }
                    self.showActionState.value = .usernameRegistered
                } else {
                    self.showActionState.value = .usernameRegistrationFailed(errorMessage: L10n.AccountPage.usernameRegistrationFailed)
                }
            }, onError: { _ in
                self.showActionState.value = .usernameRegistrationFailed(errorMessage: L10n.AccountPage.usernameRegistrationFailed)
            }).disposed(by: self.disposeBag)
    }

    func changePassword(oldPassword: String, newPassword: String) -> Bool {
        guard let accountId = self.accountService.currentAccount?.id else {
            return false
        }
        return self.accountService
            .changePassword(forAccount: accountId, password: oldPassword, newPassword: newPassword)
    }

    var switchBoothModeState = PublishSubject<Bool>()

    func enableBoothMode(enable: Bool, password: String) -> Bool {
        guard let accountId = self.accountService.currentAccount?.id else {
            return false
        }
        let result = self.accountService.setBoothMode(forAccount: accountId, enable: enable, password: password)
        if !result {
            return false
        }
        self.stateSubject.onNext(MeState.accountModeChanged)
        self.presenceService.subscribeBuddies(withAccount: accountId, withContacts: self.contactService.contacts.value, subscribe: false)
        self.contactService.removeAllContacts(for: accountId)
        return true
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

    // MARK: update for selected account
    let currentAccountUserName = PublishSubject<String>()
    let currentAccountJamiId = PublishSubject<String>()
    let currentAccountDevices = PublishSubject<[DeviceModel]>()
    let currentAccountProxy = PublishSubject<Bool>()
    let currentAccountState = PublishSubject<AccountState>()

    lazy var accountState: Observable<AccountState> = {
        var state = AccountState.registered
        if let account = self.accountService.currentAccount {
            state = account.status
            self.accountService.sharedResponseStream
                .filter({ serviceEvent in
                    guard let _: String = serviceEvent
                        .getEventInput(ServiceEventInput.registrationState) else {return false}
                    guard let accountId: String = serviceEvent
                        .getEventInput(ServiceEventInput.accountId),
                        accountId == account.id else {return false}
                    return true
                }).subscribe(onNext: { serviceEvent in
                    guard let state: String = serviceEvent
                        .getEventInput(ServiceEventInput.registrationState),
                        let accountState = AccountState(rawValue: state) else {return}
                    self.currentAccountState.onNext(accountState)
                }).disposed(by: self.tempBag)
        }
        return currentAccountState.share().startWith(state)
    }()

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
                    .subscribe(onNext: { [unowned self] device in
                        self.currentAccountDevices.onNext(device)
                    }).disposed(by: self.tempBag)
            }
        })
        return self.currentAccountDevices.share()
            .map { devices -> SettingsSection in
                var rows: [SettingsSection.SectionRow]?
                if !devices.isEmpty {
                    rows = [.device(device: devices[0])]
                    for deviceIndex in 1 ..< devices.count {
                        let device = devices[deviceIndex]
                        rows!.append(.device(device: device))
                    }
                } else if let account = self.accountService.currentAccount,
                    let details = account.details {
                    let deviceId = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountDeviceId))
                    let deviceName = details.get(withConfigKeyModel:
                        ConfigKeyModel.init(withKey: .accountDeviceName))
                    if deviceId.isEmpty {
                        return empptySection
                    }
                    rows = [.device(device:
                        DeviceModel(withDeviceId: deviceId,
                                    deviceName: deviceName,
                                    isCurrent: true))]
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
        if let account = self.accountService.currentAccount {
            self.accountService.proxyEnabled(accountID: account.id)
                .asObservable()
                .take(1)
                .subscribe(onNext: { [unowned self] enable in
                    self.currentAccountProxy.onNext(enable)
                    self.notificationsEnabled = enable
                }).disposed(by: self.disposeBag)
        }
        })
        return currentAccountProxy.share()
    }()

    // MARK: Notifications

    lazy var notificationsEnabledObservable: Observable<Bool> = {
        return Observable.combineLatest(self.notificationsPermitted.asObservable(),
                                        self.proxyEnabled.asObservable()) { (notifications, proxy) in
                                            return  proxy && notifications
        }
    }()

    var notificationsEnabled: Bool {
        get {
            return _notificationsEnabled && self.notificationsPermitted.value
        }
        set {
            _notificationsEnabled = newValue
        }
    }

    private var _notificationsEnabled: Bool = true

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
        let proxyEnabled = self.accountService.proxyEnabled(for: account.id)
        if enable == notificationsPermitted.value &&
            enable == proxyEnabled {
            return
        }
        notificationsEnabled = enable
        if !self.accountService.hasAccountWithProxyEnabled() && enable == true {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
        }
        self.accountService.changeProxyStatus(accountID: account.id, enable: enable)
        // if notiications not allowed open application settings
        if enable == true && enable != notificationsPermitted.value {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, completionHandler: nil)
            }
        }
    }

    // MARK: Account State
    func startAccountRemoving() {
        guard let account = self.accountService.currentAccount else {
            return
        }
        let allAccounts = self.accountService.accounts
        if allAccounts.count < 1 {return}
        if allAccounts.count == 1 {
            UserDefaults.standard.set("", forKey: self.accountService.selectedAccountID)
            self.stateSubject.onNext(MeState.needToOnboard)
            self.accountService.removeAccount(id: account.id)
            return
        }

        for nextAccount in allAccounts where
            (nextAccount != account && !accountService.needAccountMigration(accountId: nextAccount.id)) {
                UserDefaults.standard.set(nextAccount.id, forKey: self.accountService.selectedAccountID)
                self.accountService.currentAccount = nextAccount
                self.accountService.removeAccount(id: account.id)
                self.stateSubject.onNext(MeState.accountRemoved)
                return
        }
        self.accountService.removeAccount(id: account.id)
        self.stateSubject.onNext(MeState.needAccountMigration(accountId: allAccounts[1].id))
    }

    lazy var accountEnabled: Variable<Bool> = {
        if let account = self.accountService.currentAccount,
            let details = account.details {
            let enable = details.get(withConfigKeyModel:
                ConfigKeyModel.init(withKey: .accountEnable)).boolValue
            return Variable<Bool>(enable)
        }
        return Variable<Bool>(true)
    }()

    func enableAccount(enable: Bool) {
        if self.accountEnabled.value == enable {return}
        guard let account = self.accountService.currentAccount else {return}
        self.accountService.enableAccount(enable: enable, accountId: account.id)
        accountEnabled.value = enable
    }

    // MARK: Sip Credentials
    let sipUsername = Variable<String>("")
    let sipPassword = Variable<String>("")
    let sipServer = Variable<String>("")
    let port = Variable<String>("")
    let proxyServer = Variable<String>("")

    func updateSipSettings() {
        guard let account = self.accountService.currentAccount, let details = account.details, let credentials = account.credentialDetails.first else {return}
        if AccountModelHelper.init(withAccount: account).isAccountRing() {
            return
        }
        let username = credentials.username
        let password = credentials.password
        let server = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountHostname))
        let port = details.get(withConfigKeyModel:
            ConfigKeyModel.init(withKey: .localPort))
        let proxy = details.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountRouteSet))
        if username == sipUsername.value
            && password == sipPassword.value
            && server == sipServer.value
            && port == self.port.value
            && proxy == self.proxyServer.value {
            return
        }
        if username != sipUsername.value || password != sipPassword.value {
            credentials.username = sipUsername.value
            credentials.password = sipPassword.value
            account.credentialDetails = [credentials]
            let dict = credentials.toDictionary()
            self.accountService.setAccountCrdentials(forAccountId: account.id, crdentials: [dict])
        }
        if server != sipServer.value ||
            port != self.port.value ||
            username != sipUsername.value ||
            proxy != self.proxyServer.value {
            details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountHostname), withValue: sipServer.value)
            details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.localPort), withValue: self.port.value)
            details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountUsername), withValue: self.sipUsername.value)
            details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRouteSet), withValue: self.proxyServer.value)
            account.details = details
            self.accountService.setAccountDetails(forAccountId: account.id, withDetails: details)
        }
        sipInfoUpdated.onNext(true)
    }

    let secureTextEntry = ReplaySubject<Bool>.create(bufferSize: 1)
}
