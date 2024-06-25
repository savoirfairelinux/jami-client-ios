/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

@objc protocol MessagesAdapterDelegate {
    func didReceiveMessage(_ message: [String: String],
                           from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String)
    func messageStatusChanged(
        _ status: MessageStatus,
        for messageId: String,
        from accountId: String,
        to jamiId: String,
        in conversationId: String
    )
    func detectingMessageTyping(_ from: String, for accountId: String, status: Int)

    func conversationLoaded(
        conversationId: String,
        accountId: String,
        messages: [SwarmMessageWrap],
        requestId: Int
    )
    func messageLoaded(conversationId: String, accountId: String, messages: [[String: String]])
    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap)
    func conversationReady(conversationId: String, accountId: String)
    func conversationRemoved(conversationId: String, accountId: String)
    func conversationDeclined(conversationId: String, accountId: String)
    func conversationMemberEvent(
        conversationId: String,
        accountId: String,
        memberUri: String,
        event: Int
    )
    func conversationProfileUpdated(
        conversationId: String,
        accountId: String,
        profile: [String: String]
    )
    func conversationPreferencesUpdated(
        conversationId: String,
        accountId: String,
        preferences: [String: String]
    )
    func reactionAdded(
        conversationId: String,
        accountId: String,
        messageId: String,
        reaction: [String: String]
    )
    func reactionRemoved(
        conversationId: String,
        accountId: String,
        messageId: String,
        reactionId: String
    )
    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap)
}
