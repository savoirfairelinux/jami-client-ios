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

enum AccountType: String {
    case SIP = "SIP"
    case RING = "RING"
}

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

    // MARK: - Properties
    let id: String

    fileprivate var details: Dictionary<String, String>

    var alias: String? {
        get {return details[accountAliasKey]}
        set {details[accountAliasKey] = newValue}
    }

    var videoEnabled: Bool {
        get {return (details[accountVideoEnabledKey]?.toBool())!}
        set {details[accountVideoEnabledKey] = newValue.toString()}
    }
    var username: String? {
        get {return details[accountUsernameKey]}
        set {details[accountUsernameKey] = newValue}
    }

    var autoAnswer: Bool {
        get {return (details[accountAutoAnswerKey]?.toBool())!}
        set {details[accountAutoAnswerKey] = newValue.toString()}
    }

    var turnEnabled: Bool {
        get {return (details[accountTurnEnabledKey]?.toBool())!}
        set {details[accountTurnEnabledKey] = newValue.toString()}
    }

    var turnUsername: String? {
        get {return details[accountTurnUsernameKey]}
        set {details[accountTurnUsernameKey] = newValue}
    }

    var turnServer: String? {
        get {return details[accountTurnServerKey]}
        set {details[accountTurnServerKey] = newValue}
    }

    var turnPassword: String? {
        get {return details[accountTurnPasswordKey]}
        set {details[accountTurnPasswordKey] = newValue}
    }

    var isEnabled: Bool {
        get {return (details[accountEnabledKey]?.toBool())!}
        set {
            details[accountEnabledKey] = newValue.toString()
            (AccountConfigurationManagerAdaptator.sharedManager() as AnyObject).setAccountActive(self.id, active: newValue)
        }
    }

    var upnpEnabled: Bool {
        get {return (details[accountUpnpEnabledKey]?.toBool())!}
        set {details[accountUpnpEnabledKey] = newValue.toString()}
    }

    var accountHostname: String? {
        get {return details[accountHostnameKey]}
        set {details[accountHostnameKey] = newValue}
    }

    var accountType: AccountType {
        get {return AccountType(rawValue: details[accountTypeKey]!)!}
        set {details[accountTypeKey] = newValue.rawValue}
    }

    var displayName: String? {
        get {return details[accountDisplayNameKey]}
        set {details[accountDisplayNameKey] = newValue}
    }

    // MARK: - Init
    init(accountID: String) {
        id = accountID
        details = (AccountConfigurationManagerAdaptator.sharedManager() as AnyObject).getAccountDetails(id) as! Dictionary<String, String>
    }

    func save() {
        (AccountConfigurationManagerAdaptator.sharedManager() as AnyObject).setAccountDetails(id, details: details)
    }
}
