//
//  DBManager.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

class DBBridging {

    let profileHepler = ProfileDataHelper()
    let conversationHelper = ConversationDataHelper()
    let interactionHepler = InteractionDataHelper()

    func start() throws {
        do {
            try profileHepler.createTable()
            try conversationHelper.createTable()
            try interactionHepler.createTable()
        } catch {
            throw DataAccessError.datastoreConnectionError
        }
    }
}
