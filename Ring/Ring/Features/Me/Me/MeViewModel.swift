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

class MeViewModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()

    var userName: Single<String?>
    let ringId: Single<String?>

    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    let disposeBag = DisposeBag()

    let accountService: AccountsService

    //table section
    var settings: Observable<[SettingsSection]> = Observable.just([SettingsSection]())

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.userName = Single.just(accountService.currentAccount?.volatileDetails?.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountRegisteredName)))
        self.ringId = Single.just(accountService.currentAccount?.details?.get(withConfigKeyModel: ConfigKeyModel(withKey: .accountUsername)))
        if let account = accountService.currentAccount {
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

            self.settings = devices.concat(accountDevice)
                .map { devices in

                    let addNewDevice = SettingsSection.linkNewDevice(header: "", items: [SettingsSection.SectionRow.linkNew])

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
                        return [devicesSection, addNewDevice]
                    } else {
                        return [addNewDevice]
                    }
            }
        }
    }

    func linkDevice() {
        self.stateSubject.onNext(MeState.linkNewDevice)
    }
}
