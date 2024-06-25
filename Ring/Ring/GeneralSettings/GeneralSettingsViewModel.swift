/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

import RxCocoa
import RxDataSources
import RxSwift
import UIKit

let hardareAccelerationKey = "HARDWARE_ACCELERATION_KEY"
let automaticDownloadFilesKey = "AUTOMATIC_DOWNLOAD_FILES_KEY"
let acceptTransferLimitKey = "ACCEPT_TRANSFER_LIMIT_KEY"
let limitLocationSharingDurationKey = "LIMIT_LOCATION_SHARING_DURATION_KEY"
let locationSharingDurationKey = "LOCATION_SHARING_DURATION_KEY"
let fileRecordingLimitationInBackgroundKey = "FILE_RECORDING_LIMITATION_IN_BACKGROUND"

enum GeneralSettingsSection: SectionModelType {
    typealias Item = SectionRow
    case generalSettings(items: [SectionRow])
    enum SectionRow {
        case hardwareAcceleration
        case automaticallyAcceptIncomingFiles
        case limitLocationSharingDuration
        case acceptTransferLimit
        case locationSharingDuration
        case sectionHeader(title: String)
        case log
        case donationCampaign
    }

    var items: [SectionRow] {
        switch self {
        case let .generalSettings(items):
            return items
        }
    }

    init(original: GeneralSettingsSection, items: [SectionRow]) {
        switch original {
        case .generalSettings:
            self = .generalSettings(items: items)
        }
    }
}

class GeneralSettingsViewModel: ViewModel, Stateable {
    // MARK: - Rx Stateable

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

    lazy var generalSettings: Observable<[GeneralSettingsSection]> = {
        var items: [GeneralSettingsSection.SectionRow] = [
            .sectionHeader(title: L10n.GeneralSettings.videoSettings),
            .hardwareAcceleration,
            .sectionHeader(title: L10n.GeneralSettings.fileTransfer),
            .automaticallyAcceptIncomingFiles,
            .acceptTransferLimit,
            .sectionHeader(title: L10n.GeneralSettings.locationSharing),
            .limitLocationSharingDuration,
            .locationSharingDuration
        ]

        if !PreferenceManager.isReachEndOfDonationCampaign() {
            items.append(contentsOf: [
                .sectionHeader(title: L10n.GeneralSettings.donationCampaign),
                .donationCampaign
            ])
        }

        items.append(contentsOf: [
            .sectionHeader(title: L10n.LogView.title),
            .log
        ])
        return Observable
            .just([GeneralSettingsSection.generalSettings(items: items)])
    }()

    var hardwareAccelerationEnabled: BehaviorRelay<Bool>
    var automaticAcceptIncomingFiles: BehaviorRelay<Bool>
    var acceptTransferLimit: BehaviorRelay<String>
    var limitLocationSharingDuration: BehaviorRelay<Bool>
    var locationSharingDuration: BehaviorRelay<Int>
    var enableDonationCampaign: BehaviorRelay<Bool>
    var locationSharingDurationText: String {
        return convertMinutesToText(minutes: locationSharingDuration.value)
    }

    let videoService: VideoService

    required init(with injectionBag: InjectionBag) {
        videoService = injectionBag.videoService
        let accelerationEnabled = UserDefaults
            .standard.bool(forKey: hardareAccelerationKey)
        let accelerationEnabledSettings = injectionBag.videoService
            .getDecodingAccelerated() && injectionBag.videoService.getEncodingAccelerated()
        if accelerationEnabled != accelerationEnabledSettings {
            injectionBag.videoService.setHardwareAccelerated(withState: accelerationEnabled)
        }
        hardwareAccelerationEnabled = BehaviorRelay<Bool>(value: accelerationEnabled)

        let isAutomaticDownloadEnabled = UserDefaults.standard
            .bool(forKey: automaticDownloadFilesKey)
        automaticAcceptIncomingFiles = BehaviorRelay<Bool>(value: isAutomaticDownloadEnabled)

        let acceptTransferLimitValue = UserDefaults.standard.integer(forKey: acceptTransferLimitKey)
        acceptTransferLimit = BehaviorRelay<String>(value: String(acceptTransferLimitValue))

        let isLocationSharingDurationLimited = UserDefaults.standard
            .bool(forKey: limitLocationSharingDurationKey)
        limitLocationSharingDuration = BehaviorRelay<Bool>(value: isLocationSharingDurationLimited)

        let locationSharingDurationValue = UserDefaults.standard
            .integer(forKey: locationSharingDurationKey)
        locationSharingDuration = BehaviorRelay<Int>(value: locationSharingDurationValue)
        enableDonationCampaign = BehaviorRelay<Bool>(value: PreferenceManager.isCampaignEnabled())
    }

    func togleHardwareAcceleration(enable: Bool) {
        if hardwareAccelerationEnabled.value == enable {
            return
        }
        videoService.setHardwareAccelerated(withState: enable)
        UserDefaults.standard.set(enable, forKey: hardareAccelerationKey)
        hardwareAccelerationEnabled.accept(enable)
    }

    private func convertMinutesToText(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 && remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(remainingMinutes)m"
        }
    }

    func togleAcceptingUnkownIncomingFiles(enable: Bool) {
        if automaticAcceptIncomingFiles.value == enable {
            return
        }
        UserDefaults.standard.set(enable, forKey: automaticDownloadFilesKey)
        automaticAcceptIncomingFiles.accept(enable)
    }

    func togleLimitLocationSharingDuration(enable: Bool) {
        UserDefaults.standard.set(enable, forKey: limitLocationSharingDurationKey)
        limitLocationSharingDuration.accept(enable)
    }

    func openLog() {
        stateSubject.onNext(SettingsState.openLog)
    }

    func togleEnableDonationCampaign(enable: Bool) {
        if enableDonationCampaign.value == enable {
            return
        }
        PreferenceManager.setCampaignEnabled(enable)
        if enable {
            PreferenceManager.setStartDonationDate(DefaultValues.donationStartDate)
        }
        enableDonationCampaign.accept(enable)
    }

    func changeTransferLimit(value: String) {
        if acceptTransferLimit.value == value {
            return
        }
        UserDefaults.standard.set(Int(value) ?? 0, forKey: acceptTransferLimitKey)
        acceptTransferLimit.accept(value)
    }

    func changeLocationSharingDuration(value: Int) {
        if locationSharingDuration.value == value {
            return
        }
        UserDefaults.standard.set(value, forKey: locationSharingDurationKey)
        locationSharingDuration.accept(value)
    }

    func hardwareAccelerationEnabledSettings() -> Bool {
        return videoService.getDecodingAccelerated() && videoService.getEncodingAccelerated()
    }
}
