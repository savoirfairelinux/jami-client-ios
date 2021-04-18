/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
 Errors that can be thrown when trying create an AccountCredentialsModel

 - NotEnoughData: some information are missing to create the object
 */
enum CredentialsError: Error {
    case notEnoughData
}

/**
 A structure representing the credentials of an account.

 Its responsability:
 - keep the credentials of an account.
 */
class AccountCredentialsModel: Object {
    @objc dynamic var username: String = ""
    @objc dynamic var password: String = ""
    @objc dynamic var accountRealm: String = ""

    /**
     Constructor.

     - Parameters:
        - username: the username of the account
        - password: the password of the account
        - accountRealm : the realm of the account
     */
    convenience init(withUsername username: String, password: String, accountRealm: String) {
        self.init()
        self.username = username
        self.password = password
        self.accountRealm = accountRealm
    }

    /**
     Constructor.

     - Parameter raw: raw data to populate the credentials. This collection must contain all the
     needed elements (username, password, accountRealm).

     - Throws: CredentialsError
     */
    convenience init(withRawaData raw: [String: String]) throws {
        self.init()
        let username = raw[ConfigKey.accountUsername.rawValue]
        let password = raw[ConfigKey.accountPassword.rawValue]
        let accountRealm = raw[ConfigKey.accountRealm.rawValue]

        if username == nil || password == nil || accountRealm == nil {
            throw CredentialsError.notEnoughData
        }

        self.username = username!
        self.password = password!
        self.accountRealm = accountRealm!
    }

    func toDictionary() -> [String: String] {
        var dictionary = [String: String]()
        dictionary[ConfigKey.accountUsername.rawValue] = self.username
        dictionary[ConfigKey.accountPassword.rawValue] = self.password
        dictionary[ConfigKey.accountRealm.rawValue] = self.accountRealm
        return dictionary
    }
}
