/*
 *  Copyright (C) 2021-2022 Savoir-faire Linux Inc.
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

class AdapterService {

    enum EventType: Int {
        case message
        case fileTransfer
    }

    enum NotificationType: Int {
        case call
        case message
        case fileTransfer
        case other
    }

    /// Indicates whether the daemon is started or not.
    var daemonStarted = false

    typealias EventData = (accountId: String, jamiId: String, content: String, messageId: String, callId: String)

    private let adapter: Adapter
    var eventHandler: ((EventType, EventData) -> Void)?

    init(withAdapter adapter: Adapter, withEventHandler eventHandler: @escaping (EventType, EventData) -> Void) {
        self.eventHandler = eventHandler
        self.adapter = adapter
        Adapter.delegate = self
    }

    init(withAdapter adapter: Adapter) {
        self.eventHandler = nil
        self.adapter = adapter
        Adapter.delegate = self
    }

    func startDaemon() {
        if daemonStarted { return }
        if self.adapter.initDaemon() {
            adapter.startDaemon()
            daemonStarted = true
        } else {
            print("***failed to init daemon")
        }
    }

    func decrypt(keyPath: String, messagesPath: String, value: [String: Any]) -> NotificationType {
        return NotificationType(rawValue: adapter.decrypt(keyPath, treated: messagesPath, value: value).rawValue) ?? NotificationType.other
    }

    func pushNotificationReceived(from: String, message: [AnyHashable: Any]) {
        adapter.pushNotificationReceived(from, message: message)
    }
}

extension AdapterService: AdapterDelegate {

    func didReceiveMessage(_ message: [String: String],
                           from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String) {
        guard let content = message["text/plain"] else { return }
        if self.eventHandler != nil {
            self.eventHandler!(.message, EventData(receiverAccountId, senderAccount, content, messageId, ""))
        }
    }

    func newInteraction(conversationId: String, accountId: String, message: [String: String]) {
        if self.eventHandler != nil {
            guard let type = message["type"], type == "text/plain" else { return }
            var from = ""
            var content = ""
            if let author = message["author"] {
                from = author
            }
            if let body = message["body"] {
                content = body
            }
            self.eventHandler!(.message, EventData(accountId, from, content, "", ""))
        }
    }
}
