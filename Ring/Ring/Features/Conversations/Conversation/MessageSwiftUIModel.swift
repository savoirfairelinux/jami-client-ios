//
//  TestMessageModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation

class MessageSwiftUIModel: ObservableObject {
    @Published var avatarImage: UIImage?
    @Published var read: [UIImage]?
    var incoming = false
    var timeString: String?
    var player: PlayerViewModel?
    var getAvatar: ((String) -> Void)?
    var partisipantId: String = ""
    var messageId: String = ""
    var shouldDisplayAavatar = false {
        didSet {
            if let getAvatar = self.getAvatar, self.shouldDisplayAavatar, !partisipantId.isEmpty {
                getAvatar(partisipantId)
            }
        }
    }

    func fetchLastRead() {
        if let getlastRead = self.getlastRead, !messageId.isEmpty {
            getlastRead(messageId)
        }
    }

    var getlastRead: ((String) -> Void)?

}
