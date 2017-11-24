//
//  ConversationModel1.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-12-04.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation

class ConversationModel1 {
    var messages = [MessageModel]()
    var recipientRingId: String = ""
    var accountId: String = ""
    var participantProfile: Profile?

    convenience init(withRecipientRingId recipientRingId: String, accountId: String) {
        self.init()
        self.recipientRingId = recipientRingId
        self.accountId = accountId
    }
}
