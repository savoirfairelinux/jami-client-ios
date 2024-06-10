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

class GeneralSettings: ObservableObject {
    @Published var automaticlyDownloadIncomingFiles = UserDefaults.standard.bool(forKey: automaticDownloadFilesKey)

    @Published var downloadLimit = String(UserDefaults.standard.integer(forKey: acceptTransferLimitKey))
    @Published var videoAccelerationEnabled: Bool = UserDefaults
        .standard.bool(forKey: hardareAccelerationKey)
    @Published var limitLocationSharing: Bool = UserDefaults.standard.bool(forKey: limitLocationSharingDurationKey)
    @Published var locationSharingDurationString: String = ""
    @Published var locationSharingDuration = UserDefaults.standard.integer(forKey: locationSharingDurationKey) {
        didSet {
            self.locationSharingDurationString = convertMinutesToText(minutes: locationSharingDuration)
        }
    }

    let videoService: VideoService

    init(injectionBag: InjectionBag) {
        self.videoService = injectionBag.videoService
        self.locationSharingDurationString = convertMinutesToText(minutes: locationSharingDuration)
    }

    func enableAutomaticlyDownload(enable: Bool) {
        if automaticlyDownloadIncomingFiles == enable {
            return
        }
        UserDefaults.standard.set(enable, forKey: automaticDownloadFilesKey)
        automaticlyDownloadIncomingFiles = enable
    }

    func enableVideoAcceleration(enable: Bool) {
        if self.videoAccelerationEnabled == enable {
            return
        }
        self.videoService.setHardwareAccelerated(withState: enable)
        UserDefaults.standard.set(enable, forKey: hardareAccelerationKey)
        self.videoAccelerationEnabled = enable
    }

    func enableLocationSharingLimit(enable: Bool) {
        if self.limitLocationSharing == enable {
            return
        }
        UserDefaults.standard.set(enable, forKey: limitLocationSharingDurationKey)
        self.limitLocationSharing = enable
    }

    func saveDownloadLimit() {
        UserDefaults.standard.set(Int(downloadLimit) ?? 0, forKey: acceptTransferLimitKey)
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
}
