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

typealias ProfileAccount = (
    profileId: Int64,
    accountId: String,
    isAccount: Bool?
)
let table = RingDB.instance.tableAccountProfiles
let profileId = Expression<Int64>("profile_id")
let accountId = Expression<String>("account_id")
let isAccount = Expression<String?>("is_account")

final class AccountProfileHelper {
    func createTable() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        do {
            try dataBase.run(table.create(ifNotExists: true) { table in
                table.column(profileId)
                table.column(accountId)
                table.column(isAccount)
                table.foreignKey(profileId, references: RingDB.instance.tableProfiles, Expression<Int64>("id"), delete: .noAction)
            })
        } catch _ {
            print("Table already exists")
        }
    }

    func insert(item: ProfileAccount) {
        guard let dataBase = RingDB.instance.ringDB else {
            return
        }

        let isAccountString = item.isAccount.map { "\($0)" } ?? nil

        let getQuery = table.filter((profileId == item.profileId) &&
            (accountId == item.accountId) &&
            (isAccount == isAccountString))

        let insertQuery = table.insert(profileId <- item.profileId,
                                       accountId <- item.accountId,
                                       isAccount <- isAccountString)
        do {
            let rows = try dataBase.scalar(getQuery.count)
            if rows > 0 {
                return
            }
            try dataBase.run(insertQuery)
        } catch _ {
        }
    }
}
