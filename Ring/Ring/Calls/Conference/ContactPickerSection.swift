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

struct Contact {
    var uri: String
    var accountID: String
    var registeredName: String
    var hash: String

    lazy var presenceStatus: BehaviorRelay<Bool>?  = {
         self.presenceService
            .contactPresence[self.hash]
    }()

    lazy var firstLine: String! = {
        if let contactProfile = profile,
            let profileAlias = contactProfile.alias,
            !profileAlias.isEmpty {
            return profileAlias
        }
        return registeredName.isEmpty ? hash : registeredName
    }()

    lazy var secondLine: String! = {
        if firstLine == hash {
            return ""
        }
        if firstLine == registeredName {
            return hash
        }
        return registeredName.isEmpty ? hash : registeredName
    }()

    var profile: Profile?
    var presenceService: PresenceService

    init (contactUri: String, accountId: String,
          registrName: String, presService: PresenceService,
          contactProfile: Profile?) {
        uri = contactUri
        presenceService = presService
        accountID = accountId
        registeredName = registrName
        profile = contactProfile
        hash = ""
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
