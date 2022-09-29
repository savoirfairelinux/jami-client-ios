//
//  TestMessageModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation

class TestMessageModel: ObservableObject {
    @Published var content = "SDFERgreg ewfew sdefe w fe re w fdew fe f ewf ew fe fgre grt hg rgtrgrfereg re gher f er gfer gregret"
    @Published var image: UIImage?// UIImage(asset: Asset.fallbackAvatar)
    @Published var avatarImage: UIImage? = UIImage(asset: Asset.addAvatar)
    @Published var username = "Eduard"
    @Published var replyTo: TestMessageModel?
    @Published var replied: [TestMessageModel]?
    @Published var receivedDate: Date? = Date()
    var isIncoming = false
    @Published var read: [UIImage]?// = [UIImage(asset: Asset.fallbackAvatar)!, UIImage(asset: Asset.fallbackAvatar)!]
    var timeString: String?

    convenience init(messageModel: MessageViewModel) {
        self.init()
        if messageModel.shouldShowTimeString {
            self.timeString = MessageViewModel.getTimeLabelString(forTime: messageModel.receivedDate)
        }
        self.messageModel = messageModel
    }

    var messageModel: MessageViewModel?

    init() {}
}
