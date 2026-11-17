/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import Combine

struct ReactionChoices {
    let preferred: [String]
    let others: [String]
    let own: Set<String>

    var all: [String] { preferred + others }
}

final class ReactionActions {
    @Published private(set) var pendingRemovals = [String: String]()

    private(set) var conversation: ConversationModel?
    private(set) var localJamiId: String?

    private let conversationService: ConversationsService
    private let recentReactions: RecentReactions

    init(conversationService: ConversationsService, recentReactions: RecentReactions = RecentReactions()) {
        self.conversationService = conversationService
        self.recentReactions = recentReactions
    }

    func configure(conversation: ConversationModel, localJamiId: String?) {
        self.conversation = conversation
        self.localJamiId = localJamiId
        pendingRemovals = [:]
    }

    func ownEmojis(on message: MessageModel) -> Set<String> {
        Set(ownReactions(on: message).map(\.content))
    }

    func choices(on message: MessageModel) -> ReactionChoices {
        let preferred = recentReactions.reactions
        let own = ownEmojis(on: message)
        return ReactionChoices(preferred: preferred,
                               others: own.subtracting(preferred).sorted(),
                               own: own)
    }

    func toggle(_ emoji: String, on message: MessageModel) {
        if let own = ownReactions(on: message).first(where: { $0.content == emoji }) {
            remove(reactionId: own.id, from: message)
        } else {
            add(emoji, to: message)
        }
    }

    func remove(reactionId: String, from message: MessageModel) {
        guard let conversation = conversation, pendingRemovals[reactionId] == nil else { return }
        pendingRemovals[reactionId] = message.id
        conversationService.editSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: "", parentId: reactionId)
    }

    func reactionsUpdated(_ message: MessageModel) {
        let current = Set(message.reactions.map(\.id))
        let settled = pendingRemovals.filter { $0.value == message.id && !current.contains($0.key) }
        guard !settled.isEmpty else { return }
        settled.keys.forEach { pendingRemovals.removeValue(forKey: $0) }
    }

    private func ownReactions(on message: MessageModel) -> [MessageAction] {
        guard let localJamiId = localJamiId else { return [] }
        return message.reactions.filter {
            $0.author == localJamiId && pendingRemovals[$0.id] == nil
        }
    }

    private func add(_ emoji: String, to message: MessageModel) {
        guard let conversation = conversation, !emoji.isEmpty else { return }
        recentReactions.record(emoji)
        conversationService.sendEmojiReactionMessage(conversationId: conversation.id, accountId: conversation.accountId, message: emoji, parentId: message.id)
    }
}
