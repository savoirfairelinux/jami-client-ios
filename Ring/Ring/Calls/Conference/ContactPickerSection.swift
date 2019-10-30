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
    var displayName: String
    var presenceStatus: Observable<Bool>?
    lazy var avatar: Observable<Profile> = {
        profileService
            .getProfile(uri: uri,
                        createIfNotexists: false,
                        accountId: accountID)
    }()
    var profileService: ProfilesService

    init (contactUri: String, accountId: String, name: String, profService: ProfilesService) {
        uri = contactUri
        profileService = profService
        accountID = accountId
        displayName = name
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
