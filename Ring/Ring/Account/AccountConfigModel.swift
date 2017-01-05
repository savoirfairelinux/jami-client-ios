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

enum AccountType: String {
    case Ring = "RING"
    case SIP = "SIP"
}

struct AccountConfigModel {
    fileprivate var values = Dictionary<ConfigKeyModel, String>()

    init() {
        //~ Empty initializer
    }

    init(withDetails details: Dictionary<String, String>?) {
        if details != nil {
            for (key, value) in details! {
                if let confKey = ConfigKey(rawValue: key) {
                    let configKeyModel = ConfigKeyModel(withKey: confKey)
                    values.updateValue(value, forKey: configKeyModel)
                }
                else {
                    print("Can't find key", key)
                }
            }
        }
    }
}
