/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import UIKit
import RxSwift
import RxDataSources

let hardareAccelerationKey = "HARDWARE_ACCELERATION_KEY"

enum GeneralSettingsSection: SectionModelType {
    typealias Item = SectionRow
    case generalSettings(items: [SectionRow])
    enum SectionRow {
        case hardwareAcceleration
        case sectionHeader(title: String)
    }

    var items: [SectionRow] {
        switch self {
        case .generalSettings(let items):
            return items
        }
    }

    public init(original: GeneralSettingsSection, items: [SectionRow]) {
        switch original {
        case .generalSettings:
            self = .generalSettings(items: items)
        }
    }
}

class GeneralSettingsViewModel: ViewModel {

    lazy var generalSettings: Observable<[GeneralSettingsSection]> = {
        return Observable
            .just([GeneralSettingsSection.generalSettings(items:
                [.hardwareAcceleration])])
    }()

    var hardwareAccelerationEnabled: Variable<Bool>

    let videoService: VideoService

    required init(with injectionBag: InjectionBag) {
        self.videoService = injectionBag.videoService
        let accelerationEnabled = UserDefaults
            .standard.bool(forKey: hardareAccelerationKey)
        let accelerationEnabledSettings = injectionBag.videoService.getDecodingAccelerated() && injectionBag.videoService.getEncodingAccelerated()
        if accelerationEnabled != accelerationEnabledSettings {
            injectionBag.videoService.setHardwareAccelerated(withState: accelerationEnabled)
        }
        hardwareAccelerationEnabled = Variable<Bool>(accelerationEnabled)
    }

    func togleHardwareAcceleration(enable: Bool) {
        if hardwareAccelerationEnabled.value == enable {
            return
        }
        self.videoService.setHardwareAccelerated(withState: enable)
        UserDefaults.standard.set(enable, forKey: hardareAccelerationKey)
        hardwareAccelerationEnabled.value = enable
    }

    func hardwareAccelerationEnabledSettings() -> Bool {
        return self.videoService.getDecodingAccelerated() && self.videoService.getEncodingAccelerated()
    }
}
