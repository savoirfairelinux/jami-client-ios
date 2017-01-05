/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

import Foundation

struct AccountModel {
    // MARK: Public members
    let id: String

    var registeringUsername = false
    var devices = Dictionary<String,String>()
    var details: AccountConfigModel
    var volatileDetails: AccountConfigModel
    var credentialDetails = Array<AccountCredentialsModel>()

    // MARK: Private members

    // MARK: Init
    init(withAccountId accountId: String) {
        self.id = accountId
        self.details = AccountConfigModel()
        self.volatileDetails = AccountConfigModel()
    }

    init(withAccountId accountId: String,
         details: Dictionary<String, String>?,
         credentials: Array<Dictionary<String, String>>?,
         volatileDetails: Dictionary<String, String>?) {
        self.id = accountId
        self.details = AccountConfigModel(withDetails: details)
        self.volatileDetails = AccountConfigModel(withDetails: details)
    }

    mutating func setCredentials(_ credentials: Array<Dictionary<String, String>>?) {
        self.credentialDetails.removeAll()
        if credentials != nil {
            for (credential) in credentials! {
                let accountCredentialModel = AccountCredentialsModel(withRawaData: credential)
                self.credentialDetails.append(accountCredentialModel)
            }
        }
    }
}
