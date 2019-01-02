/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class ContactModel: Equatable {

    var ringId: String = ""
    var userName: String?
    var confirmed: Bool = false
    var added: Date = Date()
    var banned: Bool = false

    init(withRingId ringId: String) {
        self.ringId = ringId
    }

    init(withDictionary dictionary: [String: String]) {

        if let ringId = dictionary["id"] {
            self.ringId = ringId
        }

        if let confirmed = dictionary["confirmed"] {
            self.confirmed = confirmed.toBool()!
        }

        if let added = dictionary["added"] {
            let addedDate = Date(timeIntervalSince1970: Double(added)!)
            self.added = addedDate
        }
        if let banned = dictionary["banned"] {
            if let banned  = banned.toBool() {
                self.banned = banned
            }
        }
    }

    public static func == (lhs: ContactModel, rhs: ContactModel) -> Bool {
        return lhs.ringId == rhs.ringId
    }
}
