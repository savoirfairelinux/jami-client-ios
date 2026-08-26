/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation

/// Blocking libjami conversation calls.
protocol LibJamiConversationAPI: AnyObject, Sendable {

    func conversations(accountId: String) -> [String]
    func info(accountId: String, conversationId: String) -> [String: String]
    func members(accountId: String, conversationId: String) -> [[String: String]]
    func preferences(accountId: String, conversationId: String) -> [String: String]
    func countInteractions(accountId: String, conversationId: String,
                           from fromMessage: String, to toMessage: String,
                           authorUri: String) -> UInt32

    @discardableResult
    func loadMessages(accountId: String, conversationId: String,
                      from: String, size: Int) -> UInt32
    @discardableResult
    func loadUntil(accountId: String, conversationId: String,
                   from: String, until: String) -> UInt32

    func sendSwarmMessage(accountId: String, conversationId: String,
                          message: String, parentId: String, flag: Int32)
    func sendAccountMessage(content: [String: String], accountId: String,
                            to peerUri: String, flag: Int) -> UInt
    func setComposing(accountId: String, conversationUri: String, isComposing: Bool)
    func setDisplayed(accountId: String, conversationUri: String,
                      messageId: String, status: MessageStatus)

    func updateInfos(accountId: String, conversationId: String, infos: [String: String])
    func updatePreferences(accountId: String, conversationId: String, prefs: [String: String])
    func addMember(accountId: String, conversationId: String, memberId: String)
    func removeMember(accountId: String, conversationId: String, memberId: String)
    func removeConversation(accountId: String, conversationId: String)
    func startConversation(accountId: String) -> String
    func reloadConversationsAndRequests(accountId: String)
    func clearCache(accountId: String, conversationId: String)
}

final class LibJamiConversationClient: LibJamiConversationAPI, @unchecked Sendable {

    private let adapter: ConversationsAdapter

    init(adapter: ConversationsAdapter) {
        self.adapter = adapter
    }

    func conversations(accountId: String) -> [String] {
        return adapter.getSwarmConversations(forAccount: accountId) as? [String] ?? []
    }

    func info(accountId: String, conversationId: String) -> [String: String] {
        return adapter.getConversationInfo(forAccount: accountId,
                                           conversationId: conversationId) as? [String: String] ?? [:]
    }

    func members(accountId: String, conversationId: String) -> [[String: String]] {
        return adapter.getConversationMembers(accountId, conversationId: conversationId) ?? []
    }

    func preferences(accountId: String, conversationId: String) -> [String: String] {
        return adapter.getConversationPreferences(forAccount: accountId,
                                                  conversationId: conversationId) as? [String: String] ?? [:]
    }

    func countInteractions(accountId: String, conversationId: String,
                           from fromMessage: String, to toMessage: String,
                           authorUri: String) -> UInt32 {
        return adapter.countInteractions(accountId, conversationId: conversationId,
                                         from: fromMessage, to: toMessage, authorUri: authorUri)
    }

    @discardableResult
    func loadMessages(accountId: String, conversationId: String,
                      from: String, size: Int) -> UInt32 {
        return adapter.loadConversationMessages(accountId, conversationId: conversationId,
                                                from: from, size: size)
    }

    @discardableResult
    func loadUntil(accountId: String, conversationId: String,
                   from: String, until: String) -> UInt32 {
        return adapter.loadConversation(forAccountId: accountId, conversationId: conversationId,
                                        from: from, until: until)
    }

    func sendSwarmMessage(accountId: String, conversationId: String,
                          message: String, parentId: String, flag: Int32) {
        adapter.sendSwarmMessage(accountId, conversationId: conversationId,
                                 message: message, parentId: parentId, flag: flag)
    }

    func sendAccountMessage(content: [String: String], accountId: String,
                            to peerUri: String, flag: Int) -> UInt {
        return adapter.sendMessage(withContent: content, withAccountId: accountId,
                                   to: peerUri, flag: Int32(flag))
    }

    func setComposing(accountId: String, conversationUri: String, isComposing: Bool) {
        adapter.setComposingMessageTo(conversationUri, fromAccount: accountId,
                                      isComposing: isComposing)
    }

    func setDisplayed(accountId: String, conversationUri: String,
                      messageId: String, status: MessageStatus) {
        adapter.setMessageDisplayedFrom(conversationUri, byAccount: accountId,
                                        messageId: messageId, status: status)
    }

    func updateInfos(accountId: String, conversationId: String, infos: [String: String]) {
        adapter.updateConversationInfos(for: accountId, conversationId: conversationId, infos: infos)
    }

    func updatePreferences(accountId: String, conversationId: String, prefs: [String: String]) {
        adapter.updateConversationPreferences(for: accountId, conversationId: conversationId, prefs: prefs)
    }

    func addMember(accountId: String, conversationId: String, memberId: String) {
        adapter.addConversationMember(for: accountId, conversationId: conversationId, memberId: memberId)
    }

    func removeMember(accountId: String, conversationId: String, memberId: String) {
        adapter.removeConversationMember(for: accountId, conversationId: conversationId, memberId: memberId)
    }

    func removeConversation(accountId: String, conversationId: String) {
        adapter.removeConversation(accountId, conversationId: conversationId)
    }

    func startConversation(accountId: String) -> String {
        return adapter.startConversation(accountId)
    }

    func reloadConversationsAndRequests(accountId: String) {
        adapter.reloadConversationsAndRequests(accountId)
    }

    func clearCache(accountId: String, conversationId: String) {
        adapter.clearCashe(forConversationId: conversationId, accountId: accountId)
    }
}
