//
//  MessageStackViewModel.swift
//  Ring
//
//  Created by kateryna on 2022-11-07.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation

class MessageStackViewModel {

    @Published var username = ""
    var incoming = true

    var getName: ((String) -> Void)?
    var partisipantId: String = ""

    @Published var shouldDisplayName = false {
        didSet {
            if let getName = self.getName, shouldDisplayName, !partisipantId.isEmpty {
                getName(partisipantId)
            }
        }
    }

}
