/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
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

import RealmSwift

/**
 The different states that an account can have during time.

 Contains :
 - lifecycle account states
 - errors concerning the state of the accounts
 */
enum AccountState: String {
    case Registered = "REGISTERED"
    case Ready = "READY"
    case Unregistered = "UNREGISTERED"
    case Trying = "TRYING"
    case Error = "ERROR"
    case ErrorGeneric = "ERROR_GENERIC"
    case ErrorAuth = "ERROR_AUTH"
    case ErrorNetwork = "ERROR_NETWORK"
    case ErrorHost = "ERROR_HOST"
    case ErrorConfStun = "ERROR_CONF_STUN"
    case ErrorExistStun = "ERROR_EXIST_STUN"
    case ErrorServiceUnavailable = "ERROR_SERVICE_UNAVAILABLE"
    case ErrorNotAcceptable = "ERROR_NOT_ACCEPTABLE"
    case ErrorRequestTimeout = "Request Timeout"
    case ErrorNeedMigration = "ERROR_NEED_MIGRATION"
    case Initializing = "INITIALIZING"
}

/**
 The different types of account handled by Ring.
 */
enum AccountType: String {
    case Ring = "RING"
    case SIP = "SIP"
}

/**
 A structure representing the configuration of an account.

 The collection uses ConfigKeyModels as keys.

 Its responsabilities:
 - expose a clear interface to manipulate the configuration of an account
 - keep this configuration
 */
class AccountConfigModel :Object {
    /**
     The collection of configuration elements.
     */
    fileprivate var configValues = Dictionary<ConfigKeyModel, String>()

    /**
     Constructor.

     The keys of the configuration elements must be known from Ring to be taken in account.

     - Parameter details: an optional collection of configuration elements
     */
    convenience init(withDetails details: Dictionary<String, String>?) {
        self.init()
        if details != nil {
            for (key, value) in details! {
                if let confKey = ConfigKey(rawValue: key) {
                    let configKeyModel = ConfigKeyModel(withKey: confKey)
                    configValues.updateValue(value, forKey: configKeyModel)
                } else {
                    //~ The key given in parameter is not known from Ring.
                    print("Can't find key", key)
                }
            }
        }
    }

    /**
     Getter for the configuration elements.

     - Parameter configKeyModel: the ConfigKeyModel identifying the configuration element to get

     - Returns: a boolean indicating the value of the configuration element.
     */
    func getBool(forConfigKeyModel configKeyModel : ConfigKeyModel) -> Bool {
        return "true".caseInsensitiveCompare(self.get(withConfigKeyModel: configKeyModel))
            == ComparisonResult.orderedSame
    }

    /**
     Getter for the configuration elements.

     - Parameter configKeyModel: the ConfigKeyModel identifying the configuration element to get

     - Returns: the value of the configuration element as a String. The result will be an empty
     string in case of an issue.
     */
    func get(withConfigKeyModel configKeyModel : ConfigKeyModel) -> String {
        let value:String? = self.configValues[configKeyModel]
        return value != nil ? value! : ""
    }
}
