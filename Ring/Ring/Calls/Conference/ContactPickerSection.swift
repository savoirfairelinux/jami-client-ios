/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import RxDataSources
import RxSwift
import RxCocoa

class Contact {
    var uri: String
    var accountID: String
    var registeredName: String
    var hash: String

    lazy var presenceStatus: BehaviorRelay<Bool>? = {
        self.presenceService
            .getSubscriptionsForContact(contactId: self.hash)
    }()

    var firstLine: BehaviorRelay<String> = BehaviorRelay(value: "")
    var secondLine: String = ""

    var profile: Profile?
    var presenceService: PresenceService

    init (contactUri: String, accountId: String,
          registeredName: String, presService: PresenceService,
          contactProfile: Profile?, hash: String) {
        self.uri = contactUri
        self.presenceService = presService
        self.accountID = accountId
        self.registeredName = registeredName
        self.profile = contactProfile
        self.hash = hash
        self.updateFirestLine()
        self.updateSecondLine()
    }

    func registeredNameFound(name: String) {
        self.registeredName = name
        self.updateFirestLine()
        self.updateSecondLine()
    }

    private func updateFirestLine() {
        self.firstLine.accept({
            if let contactProfile = profile,
               let profileAlias = contactProfile.alias,
               !profileAlias.isEmpty {
                return profileAlias
            }
            return registeredName.isEmpty ? hash : registeredName
        }())

    }

    private func updateSecondLine() {
        self.secondLine = {
            if firstLine.value == hash {
                return ""
            }
            if firstLine.value == registeredName {
                return hash
            }
            return registeredName.isEmpty ? hash : registeredName
        }()
    }

    static func == (lhs: Contact, rhs: Contact) -> Bool {
        return (lhs.uri == rhs.uri &&
                    lhs.accountID == rhs.accountID &&
                    lhs.registeredName == rhs.registeredName)
    }
}

struct ConferencableItem {
    var conferenceID: String
    var contacts: [Contact]
}

struct ContactPickerSection {
    var header: String
    var items: [ConferencableItem]
}

extension ContactPickerSection: SectionModelType {
    typealias Item = ConferencableItem
    init(original: ContactPickerSection, items: [Item]) {
        self = original
        self.items = items
    }
}
