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

    // MARK: - Keys
    fileprivate let accountAliasKey = "Account.alias"
    fileprivate let accountVideoEnabledKey = "Account.videoEnabled"
    fileprivate let accountUsernameKey = "Account.username"
    fileprivate let accountAutoAnswerKey = "Account.autoAnswer"
    fileprivate let accountTurnEnabledKey = "TURN.enable"
    fileprivate let accountTurnUsernameKey = "TURN.username"
    fileprivate let accountTurnServerKey = "TURN.server"
    fileprivate let accountTurnPasswordKey = "TURN.password"
    fileprivate let accountEnabledKey = "Account.enable"
    fileprivate let accountUpnpEnabledKey = "Account.upnpEnabled"
    fileprivate let accountHostnameKey = "Account.hostname"
    fileprivate let accountTypeKey = "Account.type"
    fileprivate let accountDisplayNameKey = "Account.displayName"

    // MARK: Public members
    let id: String
    var registeringUsername = false

    // MARK: Private members
    fileprivate let details: AccountConfigModel
    fileprivate let volatileDetails: AccountConfigModel
    fileprivate let devices = Dictionary<String,String>()
    fileprivate var credentialDetails = Array<AccountCredentialsModel>()

    init(withAccountId accountId: String) {
        self.id = accountId
        self.details = AccountConfigModel()
        self.volatileDetails = AccountConfigModel()
    }

    func test() {
        
    }

//    var displayName: String? {
//        get {return details[accountDisplayNameKey]}
//        set {details[accountDisplayNameKey] = newValue}
//    }
}
