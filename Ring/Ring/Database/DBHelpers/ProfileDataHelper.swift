/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

import SQLite
import SwiftyBeaver

typealias Profile = (
    uri: String,
    alias: String?,
    photo: String?,
    type: String
)

final class ProfileDataHelper {
    let contactsProfileTable = Table("profiles")
    let accountProfileTable = Table("account_profile")
    let uri = Expression<String>("uri")
    let alias = Expression<String?>("alias")
    let photo = Expression<String?>("photo")
    let type = Expression<String>("type")
    private let log = SwiftyBeaver.self

    func dropAccountTable(accountDb: Connection) {
        do {
            try accountDb.run(accountProfileTable.drop(ifExists: true))
        } catch {
            debugPrint(error)
        }
    }

    func dropProfileTable(accountDb: Connection) {
        do {
            try accountDb.run(contactsProfileTable.drop(ifExists: true))
        } catch {
            debugPrint(error)
        }
    }

    func getAccountProfile(dataBase: Connection) -> Profile? {
        do {
            guard let row = try dataBase.pluck(accountProfileTable) else { return nil}
            // account profile saved in db does not have uri and type,
            // return default values that need to be updated by function caller
            return Profile("", row[alias], row[photo], ProfileType.ring.rawValue)
        } catch {
            return nil
        }
    }

    func selectAll(dataBase: Connection) throws -> [Profile]? {
        var profiles = [Profile]()
        let items = try dataBase.prepare(contactsProfileTable)
        for item in items {
            profiles.append(Profile(uri: item[uri], alias: item[alias],
                                    photo: item[photo], type: item[type]))
        }
        return profiles
    }
}
