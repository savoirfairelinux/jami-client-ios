/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

import Foundation

enum DefaultsKeys {
    static let donationStartDateKey = "DONATION_START_DATE_KEY"
    static let donationEndDateKey = "DONATION_END_DATE_KEY"
    static let donationCampaignEnabled = "DONATION_COMPAIGN_ENABLED"
}

enum DefaultValues {
    static let donationStartDate = "27.11.2023"
    static let donationEndDate = "01.04.2024"
}

class PreferenceManager {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static func registerDonationsDefaults() {
        guard let defaultStartDate = dateFormatter.date(from: DefaultValues.donationStartDate),
              let defaultEndDate = dateFormatter.date(from: DefaultValues.donationEndDate)
        else {
            return
        }

        let defaults = [DefaultsKeys.donationStartDateKey: defaultStartDate,
                        DefaultsKeys.donationEndDateKey: defaultEndDate,
                        DefaultsKeys.donationCampaignEnabled: true] as [String: Any]

        UserDefaults.standard.register(defaults: defaults)
        /*
         Force update as the end date could be set in the
         previous application run
         */
        updateEndDonationsDate(date: defaultEndDate)
    }

    static func updateEndDonationsDate(date: Date) {
        UserDefaults.standard.set(date, forKey: DefaultsKeys.donationEndDateKey)
    }

    static func setStartDonationDate(_ dateString: String) {
        if let date = dateFormatter.date(from: dateString) {
            UserDefaults.standard.set(date, forKey: DefaultsKeys.donationStartDateKey)
        }
    }

    static func getStartDonationDate() -> Date? {
        return UserDefaults.standard.object(forKey: DefaultsKeys.donationStartDateKey) as? Date
    }

    static func getEndDonationDate() -> Date? {
        return UserDefaults.standard.object(forKey: DefaultsKeys.donationEndDateKey) as? Date
    }

    static func setCampaignEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: DefaultsKeys.donationCampaignEnabled)
    }

    static func isCampaignEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: DefaultsKeys.donationCampaignEnabled)
    }

    static func isReachEndOfDonationCampaign() -> Bool {
        let currentDate = Date()

        if let endDate = getEndDonationDate() {
            return currentDate > endDate
        }
        return true
    }

    static func temporarilyDisableDonationCampaign() {
        let currentDate = Date()
        if let date7DaysAhead = Calendar.current.date(byAdding: .day, value: 7, to: currentDate) {
            UserDefaults.standard.set(date7DaysAhead, forKey: DefaultsKeys.donationStartDateKey)
        }
    }

    static func isDateWithinCampaignPeriod() -> Bool {
        let currentDate = Date()

        if let startDate = getStartDonationDate(),
           let endDate = getEndDonationDate() {
            return currentDate >= startDate && currentDate < endDate
        }
        return false
    }
}
