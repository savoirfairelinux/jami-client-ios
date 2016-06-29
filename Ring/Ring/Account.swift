/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

struct Account {
    
    //MARK: - Properties
    let id: String
    
    //FIXME: This should be private
    var details: Dictionary<String, String>
    
    var alias: String? {
        get {
            return details["Account.alias"]
        }
        set {
            details["Account.alias"] = newValue
        }
    }
    
    var videoEnabled: Bool {
        get {
            return (details["Account.videoEnabled"]?.toBool())!
        }
        set {
            details["Account.videoEnabled"] = newValue.toString()
        }
    }
    var username: String? {
        get {
            return details["Account.username"]
        }
        set {
            details["Account.username"] = newValue
        }
    }

    var autoAnswer: Bool {
        get {
            return (details["Account.autoAnswer"]?.toBool())!
        }
        set {
            details["Account.autoAnswer"] = newValue.toString()
        }
    }

    var turnEnabled: Bool {
        get {
            return (details["TURN.enable"]?.toBool())!
        }
        set {
            details["TURN.enable"] = newValue.toString()
        }
    }

    var turnUsername: String? {
        get {
            return details["TURN.username"]
        }
        set {
            details["TURN.username"] = newValue
        }
    }

    var turnServer: String? {
        get {
            return details["TURN.server"]
        }
        set {
            details["TURN.server"] = newValue
        }
    }

    var turnPassword: String? {
        get {
            return details["TURN.password"]
        }
        set {
            details["TURN.password"] = newValue
        }
    }

    var isEnabled: Bool {
        get {
            return (details["Account.enable"]?.toBool())!
        }
        set {
            details["Account.enable"] = newValue.toString()
            ConfigurationManagerAdaptator.sharedManager().setAccountActive(self.id, newValue)
        }
    }

    var upnpEnabled: Bool {
        get {
            return (details["Account.upnpEnabled"]?.toBool())!
        }
        set {
            details["Account.upnpEnabled"] = newValue.toString()
        }
    }

    var accountHostname: String? {
        get {
            return details["Account.hostname"]
        }
        set {
            details["Account.hostname"] = newValue
        }
    }

    var accountType: AccountType {
        get {
            return AccountType(rawValue: details["Account.type"]!)!
        }
        set {
            details["Account.type"] = newValue.rawValue
        }
    }

    var displayName: String? {
        get {
            return details["Account.displayName"]
        }
        set {
            details["Account.displayName"] = newValue
        }
    }
    
    //MARK: - Init
    init(accID: String) {
        id = accID
        details = ConfigurationManagerAdaptator.sharedManager().getAccountDetails(id) as! Dictionary<String, String>
    }
    
    func save() {
        ConfigurationManagerAdaptator.sharedManager().setAccountDetails(id, details)
    }
}