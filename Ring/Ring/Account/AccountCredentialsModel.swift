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

struct AccountCredentialsModel {
    fileprivate let username: String
    fileprivate let password: String
    fileprivate let realm: String

    init(withUsername username: String, password: String, realm: String) {
        self.username = username
        self.password = password
        self.realm = realm
    }

    init(withRawaData raw: Dictionary<String, String>) {
        self.username = raw[ConfigKey.AccountUsername.rawValue]!
        self.password = raw[ConfigKey.AccountPassword.rawValue]!
        self.realm = raw[ConfigKey.AccountRealm.rawValue]!
    }
}
