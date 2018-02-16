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

    case linkedDevices(header: String, items: [SectionRow])
    case linkNewDevice(header: String, items: [SectionRow])
    case enableProxy(header: String, items: [SectionRow])

    enum SectionRow {
        case device(device: DeviceModel)
        case linkNew
        case proxy
        case blockedList
    }

    var header: String {

        switch self {
        case .linkedDevices(let header, _):
            return header

        case .linkNewDevice(let header, _):
            return header

        case .enableProxy(let header, _):
            return header
        }
    }

    var items: [SectionRow] {
        switch self {
        case .linkedDevices(_, let items):
            return items

        case .linkNewDevice(_, let items):
            return items

        case .enableProxy(_, let items):
            return items
        }
    }

    public init(original: SettingsSection, items: [SectionRow]) {
        switch original {
        case .linkedDevices(let header, _):
            self = .linkedDevices(header: header, items: items)

        case .linkNewDevice(let header, _):
            self = .linkNewDevice(header: header, items: items)

        case .enableProxy(let header, _):
            self = .enableProxy(header: header, items: items)
        }
    }
}

class MeViewModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()

    lazy var userName: Observable<String?> = {
        // return username if exists, is no start name lookup
        let accountName = self.accountService.currentAccount?.volatileDetails?.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRegisteredName))
        if accountName != nil && !accountName!.isEmpty {
            return Observable.from(optional: accountName)
        }
        guard let account = self.accountService.currentAccount else {
            return Observable.from(optional: accountName)
        }
        let accountHelper = AccountModelHelper(withAccount: account)
        guard let uri = accountHelper.ringId else {
            return Observable.from(optional: accountName)
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

    lazy var ringId: Observable<String?> = {
        return Observable.from(optional: self.accountService.currentAccount?.details?.get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername)))
    }()

    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let disposeBag = DisposeBag()

    let accountService: AccountsService
    let nameService: NameService

    //table section
    lazy var settings: Observable<[SettingsSection]> = {
        if let account = self.accountService.currentAccount {
            let accountHelper = AccountModelHelper(withAccount: account)
            let uri = accountHelper.ringId
            let devices = Observable.from(optional: account.devices)
            let accountDevice: Observable<[DeviceModel]> = self.accountService
                .sharedResponseStream
                .filter({ (event) in
                    return event.eventType == ServiceEventType.knownDevicesChanged &&
                        event.getEventInput(ServiceEventInput.uri) == uri
                }).map({ _ in
                    return account.devices
                })

            return devices.concat(accountDevice)
                .map { devices in
                    let addNewDevice = SettingsSection.linkNewDevice(header: "", items: [SettingsSection.SectionRow.linkNew])
                    let enableProxy = SettingsSection.enableProxy(header: L10n.Accountpage.settingsHeader, items: [SettingsSection.SectionRow.blockedList])
                    var rows: [SettingsSection.SectionRow]?

                    if !devices.isEmpty {
                        rows = [SettingsSection.SectionRow.device(device: devices[0])]
                        for i in 1 ..< devices.count {
                            let device = devices[i]
                            rows!.append (SettingsSection.SectionRow.device(device: device))
                        }
                    }

                    if rows != nil {
                        let devicesSection = SettingsSection.linkedDevices(header: L10n.Accountpage.devicesListHeader, items: rows!)
                        return [devicesSection, addNewDevice, enableProxy]
                    } else {
                        return [addNewDevice, enableProxy]
                    }
            }
        }
        return Observable.just([SettingsSection]())
    }()

    lazy var proxyEnabled: Observable<Bool>? = {
        if let account = self.accountService.currentAccount {
            return self.accountService.proxyEnabled(accountID: account.id)
        }
        return nil
    }()

    lazy var proxyInitialState: Bool = {
        if let account = self.accountService.currentAccount {
            return self.accountService.getCurrentProxyState(accountID: account.id)
        }
        return false
    }()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
    }

    func linkDevice() {
        self.stateSubject.onNext(MeState.linkNewDevice)
    }

    func enableProxy(enable: Bool) {
        guard let account = self.accountService.currentAccount else {
            return
        }
        self.accountService.changeProxyAvailability(accountID: account.id, enable: enable)
    }

    func showBlockedContacts() {
       self.stateSubject.onNext(MeState.blockedContacts)
    }
}
