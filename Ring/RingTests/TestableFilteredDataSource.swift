//
//  TestableSearchDataSource.swift
//  RingTests
//
//  Created by kateryna on 2023-03-08.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
@testable import Ring

class TestableFilteredDataSource: FilterConversationDataSource {

    var conversationViewModels: [Ring.ConversationViewModel]

    init(conversations: [Ring.ConversationViewModel]) {
        self.conversationViewModels = conversations
    }
}
