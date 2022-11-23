//
//  EventData.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/23/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation

struct EventData {
    var accountId, jamiId, conversationId, content, groupTitle: String
    
    init(accountId: String = "", jamiId: String = "", conversationId: String = "", content: String = "", groupTitle: String = "") {
        self.accountId = accountId
        self.jamiId = jamiId
        self.conversationId = conversationId
        self.content = content
        self.groupTitle = groupTitle
    }
}
