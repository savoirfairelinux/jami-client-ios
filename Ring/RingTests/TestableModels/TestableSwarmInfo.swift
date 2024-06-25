/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
@testable import Ring
import RxRelay
import RxSwift

class TestableSwarmInfo: SwarmInfoProtocol {
    var avatar: BehaviorRelay<UIImage?> = BehaviorRelay(value: nil)
    var title = BehaviorRelay(value: "")
    var color = BehaviorRelay<String>(value: "")
    var type = BehaviorRelay(value: ConversationType.oneToOne)
    var description = BehaviorRelay(value: "")
    var participantsNames: BehaviorRelay<[String]> = BehaviorRelay(value: [""])
    var participantsAvatars: BehaviorRelay<[UIImage]> = BehaviorRelay(value: [UIImage()])

    var avatarHeight: CGFloat = 55
    var avatarSpacing: CGFloat = 2
    lazy var id: String = conversation?.id ?? ""

    var finalTitle: Observable<String> = Observable.just("")
    var finalAvatar: Observable<UIImage> = Observable.just(UIImage())
    var participants = BehaviorRelay(value: [ParticipantInfo]())
    var contacts = BehaviorRelay(value: [ParticipantInfo]())
    var conversation: ConversationModel?

    // parameters
    let containsSearchQuery: Bool
    let hasParticipantWithRegisteredName: Bool

    init(
        participants: [ParticipantInfo],
        containsSearchQuery: Bool,
        hasParticipantWithRegisteredName: Bool
    ) {
        self.participants.accept(participants)
        self.containsSearchQuery = containsSearchQuery
        self.hasParticipantWithRegisteredName = hasParticipantWithRegisteredName
    }

    func addContacts(contacts _: [Ring.ContactModel]) {}

    func hasParticipantWithRegisteredName(name _: String) -> Bool {
        return hasParticipantWithRegisteredName
    }

    func contains(searchQuery _: String) -> Bool {
        return containsSearchQuery
    }
}
