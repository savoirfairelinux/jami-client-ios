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
    @Published var avatarDidSet = false
    @Published var read: [UIImage]? {
        didSet {
            if read != nil && !read!.isEmpty {
                print("@@@@@@@@@update read")
            }
        }
    }
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

    var getlastRead: ((String) -> Void)?

    lazy var shouldDisplayRead: Bool = {
        if let getlastRead = self.getlastRead, !messageId.isEmpty {
            getlastRead(messageId)
        }
        return true
    }()

}
