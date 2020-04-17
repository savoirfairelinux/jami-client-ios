/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
    var participantUri: String = ""
    var hash = ""
    var accountId: String = ""
    var participantProfile: Profile?
    var conversationId: String = ""
    var lastDisplayedMessage: (id: Int64, timestamp: Date) = (-1, Date())

    convenience init(withParticipantUri participantUri: JamiURI, accountId: String) {
        self.init()
        self.participantUri = participantUri.uriString ?? ""
        self.hash = participantUri.hash ?? ""
        self.accountId = accountId
    }

    convenience init (withParticipantUri participantUri: JamiURI, accountId: String, hash: String) {
    self.init()
    self.participantUri = participantUri.uriString ?? ""
    self.hash = hash
    self.accountId = accountId
    }

    public static func == (lhs: ConversationModel, rhs: ConversationModel) -> Bool {
        return (lhs.participantUri == rhs.participantUri && lhs.accountId == rhs.accountId)
    }

    public func getMessage(withDaemonID daemonID: String) -> MessageModel? {
        return self.messages.filter({ message in
           return message.daemonId == daemonID
        }).first
    }
}
