/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

import Contacts
import SwiftyBeaver

class ContactRequestModel {

    let ringId: String
    let accountId: String
    var vCard: CNContact?
    var receivedDate: Date

    enum ContactRequestKey: String {
        case from
        case payload
        case received
    }

    private let log = SwiftyBeaver.self

    init(withRingId ringId: String, vCard: CNContact?, receivedDate: Date, accountId: String) {
        self.ringId = ringId
        self.vCard = vCard
        self.receivedDate = receivedDate
        self.accountId = accountId
    }

    init(withDictionary dictionary: [String: String], accountId: String) {

        if let ringId = dictionary[ContactRequestKey.from.rawValue] {
            self.ringId = ringId
        } else {
            self.ringId = ""
        }

        if let vCardString = dictionary[ContactRequestKey.payload.rawValue] {
            if let data = vCardString.data(using: String.Encoding.utf8), !data.isEmpty {
                do {
                    let vCards = try CNContactVCardSerialization.contacts(with: data)
                    if let contactVCard = vCards.first {
                        self.vCard = contactVCard
                    }
                } catch {
                    log.error("Unable to serialize the vCard : \(error)")
                    self.vCard = CNContact()
                }
            }
        }

        if let receivedDateString = dictionary[ContactRequestKey.received.rawValue] {
            let timestamp = Double(receivedDateString)
            self.receivedDate = Date(timeIntervalSince1970: timestamp!)
        } else {
            self.receivedDate = Date()
        }

        self.accountId = accountId
    }
}
