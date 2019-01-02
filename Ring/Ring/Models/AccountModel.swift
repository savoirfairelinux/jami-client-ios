/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

/**
 Errors that can be thrown when trying to build an AccountModel
 */
enum AccountModelError: Error {
    case unexpectedError
}

/**
 A class representing an account.
 */
class AccountModel: Equatable {
    // MARK: Public members
    var id: String = ""
    var registeringUsername = false
    var details: AccountConfigModel?
    var volatileDetails: AccountConfigModel?
    var credentialDetails = [AccountCredentialsModel]()
    var devices = [DeviceModel]()
    var onBoarded = false

    // MARK: Init
    convenience init(withAccountId accountId: String) {
        self.init()
        self.id = accountId
    }

    convenience init(withAccountId accountId: String,
                     details: AccountConfigModel,
                     volatileDetails: AccountConfigModel,
                     credentials: [AccountCredentialsModel],
                     devices: [DeviceModel]) throws {
        self.init()
        self.id = accountId
        self.details = details
        self.volatileDetails = volatileDetails
        self.devices = devices
    }

    public static func == (lhs: AccountModel, rhs: AccountModel) -> Bool {
        return lhs.id == rhs.id
    }

}
