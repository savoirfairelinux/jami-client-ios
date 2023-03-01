//
//  TestableSwarmInfo.swift
//  RingTests
//
//  Created by kateryna on 2023-03-08.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxRelay
import RxSwift
@testable import Ring

class TestableSwarmInfo: SwarmInfoProtocol {
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var title = BehaviorRelay(value: "")
    var color = BehaviorRelay<String>(value: "")
    var type = BehaviorRelay(value: ConversationType.oneToOne)
    var description = BehaviorRelay(value: "")
    var participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    var participantsAvatars: BehaviorRelay<[UIImage]> = BehaviorRelay(value: [UIImage()])

    var avatarHeight: CGFloat = 40
    var avatarSpacing: CGFloat = 2
    var maximumLimit: Int = 8
    lazy var id: String = {
        return conversation?.id ?? ""
    }()

    var finalTitle: Observable<String> = Observable.just("")
    var finalAvatar: Observable<UIImage> = Observable.just(UIImage())
    var participants = BehaviorRelay(value: [ParticipantInfo]())
    var contacts = BehaviorRelay(value: [ParticipantInfo]())
    var conversation: ConversationModel?

    init(participants: [ParticipantInfo]) {
        self.participants.accept(participants)
    }

    func addContacts(contacts: [Ring.ContactModel]) {}

    func hasParticipantWithRegisteredName(name: String) -> Bool {
        return true
    }

    func hasParticipantWithProfileName(name: String) -> Bool {
        return true
    }

    func hasParticipantWithRegisteredNameContains(name: String) -> Bool {
        return true
    }

    func hasParticipantWithProfileNameContains(name: String) -> Bool {
        return true
    }

    func hasParticipantWithJamiIdContains(name: String) -> Bool {
        return true
    }

}
