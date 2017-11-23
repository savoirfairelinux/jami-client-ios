/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

import SwiftyBeaver
import RxSwift
import RxDataSources

enum SettingsSection: SectionModelType {

    typealias Item = SectionRow

    case linkedDevices(header: String, items: [SectionRow])
    case linkNewDevice(header: String, items: [SectionRow])

    enum SectionRow {
        case device(device: DeviceModel)
        case linkNew
    }

    var header: String {

        switch self {
        case .linkedDevices(let header, _):
            return header

        case .linkNewDevice(let header, _):
            return header

        }
    }

    var items: [SectionRow] {
        switch self {
        case .linkedDevices(_, let items):
            return items

        case .linkNewDevice(_, let items):
            return items
        }
    }

    public init(original: SettingsSection, items: [SectionRow]) {
        switch original {
        case .linkedDevices(let header, _):
            self = .linkedDevices(header: header, items: items)

        case .linkNewDevice(let header, _):
            self = .linkNewDevice(header: header, items: items)
        }
    }
}

final class MeViewModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()

    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let disposeBag = DisposeBag()

    private let accountService: NewAccountsService
    private let nameService: NameService

    private let log = SwiftyBeaver.self

    //table section
    lazy var settings: Observable<[SettingsSection]> = {
//        if let account = self.accountService.currentAccount {
//            let accountHelper = AccountModelHelper(withAccount: account)
//            let uri = accountHelper.ringId
//            let devices = Observable.from(optional: account.devices)
//            let accountDevice: Observable<[DeviceModel]> = self.accountService
//                .sharedResponseStream
//                .filter({ (event) in
//                    return event.eventType == ServiceEventType.knownDevicesChanged &&
//                        event.getEventInput(ServiceEventInput.uri) == uri
//                }).map({ _ in
//                    return account.devices
//                })
//
//            return devices.concat(accountDevice)
//                .map { devices in
//                    let addNewDevice = SettingsSection.linkNewDevice(header: "", items: [SettingsSection.SectionRow.linkNew])
//                    var rows: [SettingsSection.SectionRow]?
//
//                    if !devices.isEmpty {
//                        rows = [SettingsSection.SectionRow.device(device: devices[0])]
//                        for i in 1 ..< devices.count {
//                            let device = devices[i]
//                            rows!.append (SettingsSection.SectionRow.device(device: device))
//                        }
//                    }
//
//                    if rows != nil {
//                        let devicesSection = SettingsSection.linkedDevices(header: L10n.Accountpage.devicesListHeader, items: rows!)
//                        return [devicesSection, addNewDevice]
//                    } else {
//                        return [addNewDevice]
//                    }
//            }
//        }
//        return Observable.just([SettingsSection]())
        return Observable.just([])
    }()

    private let accountUsername = Variable<String>("")
    lazy var accountUsernameObservable: Observable<String> = {
        return self.accountUsername.asObservable()
    }()

    private let accountRingId = Variable<String>("")
    lazy var accountRingIdObservable: Observable<String> = {
        return self.accountRingId.asObservable()
    }()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.newAccountsService
        self.nameService = injectionBag.nameService

        self.accountService.currentAccount()
            .do(onNext: { [weak self] (account) in
                let accountUsernameKey = ConfigKeyModel(withKey: ConfigKey.accountUsername)
                let ringId = account.details?.get(withConfigKeyModel: accountUsernameKey)
                self?.accountRingId.value = ringId ?? "No RingId found"
            }, onError: { [weak self] (error) in
                self?.accountRingId.value = "No RingId found"
                self?.log.error("No RingId found - \(error.localizedDescription)")
            })
            .flatMap { (account) -> PrimitiveSequence<SingleTrait, String> in
                let registeredNameKey = ConfigKeyModel(withKey: ConfigKey.accountRegisteredName)
                if let registeredName = account.volatileDetails?.get(withConfigKeyModel: registeredNameKey) {
                    return Single.just(registeredName)
                } else {
                    //TODO: call nameserver single
                    return Single.just("")
                }
            }
            .subscribe(onSuccess: { [weak self] (username) in
                self?.accountUsername.value = username
            }, onError: { [weak self] (error) in
                self?.accountUsername.value = "No username found"
                self?.log.error("No username found - \(error.localizedDescription)")
            })
            .disposed(by: self.disposeBag)
    }

    func linkDevice() {
        self.stateSubject.onNext(MeState.linkNewDevice)
    }
}
