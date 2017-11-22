//
//  DataModel.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation

typealias Profile = (
    id: Int64?,
    uri: String,
    alias: String?,
    photo: String?,
    type: String,
    status: String
)

typealias Conversation = (
    id: Int64,
    participantID: Int64
)

typealias Interaction = (
    id: Int64?,
    accountID: Int64,
    authorID: Int64,
    conversationID: Int64,
    timestamp: Int64,
    body: String,
    type: String,
    status: String,
    daemonID: String
)
