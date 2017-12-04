/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class ConversationModel: Equatable {

    var messages = [MessageModel]()
    var recipientRingId: String = ""
    var accountId: String = ""
    var accountUri: String = ""
    var participantProfile: Profile?

    convenience init(withRecipientRingId recipientRingId: String, accountId: String, accountUri: String) {
        self.init()
        self.recipientRingId = recipientRingId
        self.accountId = accountId
        self.accountUri = accountUri
    }
    public static func == (lhs: ConversationModel, rhs: ConversationModel) -> Bool {
        return (lhs.recipientRingId == rhs.recipientRingId && lhs.accountId == rhs.accountId)
    }
}
