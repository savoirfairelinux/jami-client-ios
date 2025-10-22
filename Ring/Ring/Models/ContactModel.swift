/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

class ContactModel: Equatable {

    var hash: String = ""
    var conversationId: String = ""
    var userName: String?
    var uriString: String?
    var confirmed: Bool = false
    var added: Date = Date()
    var blocked: Bool = false
    var type = URIType.ring

    static func == (lhs: ContactModel, rhs: ContactModel) -> Bool {
        return lhs.uriString == rhs.uriString
    }

    init(withUri contactUri: JamiURI) {
        self.uriString = contactUri.uriString
        type = contactUri.schema
        self.hash = contactUri.hash ?? ""
    }

    // only jami contacts
    init(withDictionary dictionary: [String: String]) {
        if let hash = dictionary["id"] {
            self.hash = hash
            if let uriString = JamiURI.init(schema: URIType.ring,
                                            infoHash: hash).uriString {
                self.uriString = uriString
            }
        }

        if let confirmed = dictionary["confirmed"] {
            self.confirmed = confirmed.toBool() ?? false
        }

        if let added = dictionary["added"], let dateAdded = Double(added) {
            let addedDate = Date(timeIntervalSince1970: dateAdded)
            self.added = addedDate
        }
        if let blocked = dictionary["blocked"],
           let isBlocked = blocked.toBool() {
            self.blocked = isBlocked
        }

        if let conversationId = dictionary["conversationId"] {
            self.conversationId = conversationId
        }
    }
}
