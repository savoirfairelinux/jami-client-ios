//
//  File.swift
//  Ring
//
//  Created by kate on 2019-11-01.
//  Copyright © 2019 Savoir-faire Linux. All rights reserved.
//

import RxDataSources
import RxSwift

struct Contact {
    var uri: String
    var accountID: String
    var registeredName: String
    var hash: String

    lazy var presenceStatus: Variable<Bool>?  = {
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
