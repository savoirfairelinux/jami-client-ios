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
    let vCard: CNContact
    let receivedDate: Date

    private let log = SwiftyBeaver.self

    init(withRingId ringId: String, vCard: CNContact, receivedDate: Date) {
        self.ringId = ringId
        self.vCard = vCard
        self.receivedDate = receivedDate
    }

    init(withDictionary dictionary: [String : String]) {

        if let ringId = dictionary["from"] {
            self.ringId = ringId
        } else {
            self.ringId = ""
        }

        if let vCardString = dictionary["payload"] {
            do {
                self.vCard = try CNContactVCardSerialization.contacts(with: vCardString.data(using: String.Encoding.utf8)!).first!
            } catch {
                log.error("Unable to serialize the vCard : \(error)")
                self.vCard = CNContact()
            }
        } else {
            self.vCard = CNContact()
        }

        if let receivedDateString = dictionary["received"] {
            let timestamp = Double(receivedDateString)
            self.receivedDate = Date(timeIntervalSince1970: timestamp!)
        } else {
            self.receivedDate = Date()
        }
    }
}
