/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
import RxSwift

enum ProfileType: String {
    case ring = "RING"
    case sip = "SIP"
}

enum ProfileStatus: String {
    case trusted = "TRUSTED"
    case untrasted = "UNTRUSTED"
}

enum MessageDirection {
    case incoming
    case outgoing
}

enum InteractionStatus: String {
    case invalid = "INVALID"
    case unknown = "UNKNOWN"
    case sending = "SENDING"
    case failed = "FAILED"
    case succeed = "SUCCEED"
    case read = "READ"
    case unread = "UNREAD"

    func toMessageStatus() -> MessageStatus {
        switch self {
        case .invalid:
            return MessageStatus.unknown
        case .unknown:
            return MessageStatus.unknown
        case .sending:
            return MessageStatus.sending
        case .failed:
            return MessageStatus.failure
        case .succeed:
            return MessageStatus.sent
        case .read:
            return MessageStatus.read
        case .unread:
            return MessageStatus.unknown
        }
    }
}

enum InteractionType: String {
    case invalid = "INVALID"
    case text = "TEXT"
    case call = "CALL"
    case contact = "CONTACT"
}

final class DBBridging {
    let profileHepler: ProfileDataHelper
    let conversationHelper: ConversationDataHelper
    let interactionHepler: InteractionDataHelper

    // used to create object to save to db. When inserting in table defaultID will be replaced by
    // autoincrementedID
    let defaultID: Int64 = 1

    init(profileHepler: ProfileDataHelper, conversationHelper: ConversationDataHelper,
         interactionHepler: InteractionDataHelper) {
        self.profileHepler = profileHepler
        self.conversationHelper = conversationHelper
        self.interactionHepler = interactionHepler
    }

    func start() throws {
        try profileHepler.createTable()
        try conversationHelper.createTable()
        try interactionHepler.createTable()
    }
}
