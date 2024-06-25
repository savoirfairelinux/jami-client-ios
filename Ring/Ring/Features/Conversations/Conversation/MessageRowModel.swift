//
//  MessageRowModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation

class MessageRowModel: ObservableObject {
    @Published var avatarImage: UIImage?
    @Published var read: [UIImage]? {
        didSet {
            if read != nil {
                print("********read indicator updated")
            }
        }
    }

    var incoming = false
    var timeString: String?
    var getAvatar: ((String) -> Void)?
    var partisipantId: String = ""
    var messageId: String = ""
    var shouldDisplayAavatar = false {
        didSet {
            if let getAvatar = getAvatar, shouldDisplayAavatar, !partisipantId.isEmpty {
                getAvatar(partisipantId)
            }
        }
    }

    func fetchLastRead() {
        if let getlastRead = getlastRead, !messageId.isEmpty {
            getlastRead(messageId)
        }
    }

    var getlastRead: ((String) -> Void)?
}
