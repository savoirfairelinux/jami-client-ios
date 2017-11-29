//
//  ConversationModel1.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-23.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation

class ConversationModel: Equatable {

    var messages = [MessageModel]()
    var recipientRingId: String = ""
    var accountId: String = ""
    var participantProfile: Profile?

    convenience init(withRecipientRingId recipientRingId: String, accountId: String) {
        self.init()
        self.recipientRingId = recipientRingId
        self.accountId = accountId
    }
    public static func == (lhs: ConversationModel, rhs: ConversationModel) -> Bool {
        return (lhs.recipientRingId == rhs.recipientRingId && lhs.accountId == rhs.accountId)
    }
}
