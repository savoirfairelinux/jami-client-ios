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
import UIKit
import MobileCoreServices
import Photos
import os

struct ActiveCall: Hashable {
    let id: String
    let uri: String
    let device: String
    let conversationId: String
    let accountId: String
    let isFromLocalDevice: Bool

    func constructURI() -> String {
        return "rdv:" + self.conversationId + "/" + self.uri + "/" + self.device + "/" + self.id
    }
}

enum ConversationAttributes: String {
    case title = "title"
    case description = "description"
    case avatar = "avatar"
    case mode = "mode"
    case conversationId = "id"
}

class AdapterService {
    enum InteractionAttributes: String {
        case interactionId = "id"
        case type = "type"
        case invited = "invited"
        case fileId = "fileId"
        case displayName = "displayName"
        case body = "body"
        case author = "author"
        case timestamp = "timestamp"
        case parent = "linearizedParent"
        case action = "action"
        case duration = "duration"
    }

    enum InteractionType: String {
        case message = "text/plain"
        case fileTransfer = "application/data-transfer+json"
        case collabDocument = "application/collab-doc+json"
    }

    enum EventType: Int {
        case message
        case fileTransferDone
        case fileTransferInProgress
        case syncCompleted
        case conversationCloned
        case invitation
        case activeCall
        case documentShared
        case documentReplicated
        case fileUploadStarted
        case fileUploadEnded
    }

    enum PeerConnectionRequestType {
        case call(peerId: String, isVideo: Bool)
        case gitMessage(convId: String)
        case fileRequest(convId: String)
        case clone
        case unknown
    }

    private enum ConnectionType: String {
        case gitMessage = "application/im-gitmessage-id"
        case fileRequest = "application/file-request"
        case clone = "application/clone"
        case videoCall
        case audioCall
    }

    private let maxSizeForAutoaccept = 20 * 1024 * 1024

    private var adapter: Adapter!
    var eventHandler: ((EventType, EventData) -> Void)?
    var loadingFiles = [String: EventData]()

    init(withAdapter adapter: Adapter) {
        self.adapter = adapter
        Adapter.delegate = self
    }

    func startAccountsWithListener(accountId: String, convId: String, loadAll: Bool, listener: @escaping (EventType, EventData) -> Void) {
        self.eventHandler = listener
        start(accountId: accountId, convId: convId, loadAll: loadAll)
    }

    func startAccount(accountId: String, convId: String, loadAll: Bool) {
        start(accountId: accountId, convId: convId, loadAll: loadAll)
    }

    func pushNotificationReceived(accountId: String, data: [String: String]) {
        self.adapter.pushNotificationReceived(accountId, message: data)
    }

    func decrypt(keyPath: String, accountId: String, messagesPath: String, value: [String: Any]) -> PeerConnectionRequestType {
        if self.adapter == nil {
            return .unknown
        }
        let result = adapter.decrypt(keyPath, accountId: accountId, treated: messagesPath, value: value)
        guard let peerId = result?.keys.first,
              let type = result?.values.first else {
            return .unknown}
        let components = type.components(separatedBy: "/")
        let hasConversation = components.count == 3
        let kind = hasConversation ? components.prefix(2).joined(separator: "/") : type
        let convId = hasConversation ? components[2] : ""
        switch (ConnectionType(rawValue: kind), hasConversation) {
        case (.gitMessage, true):
            return .gitMessage(convId: convId)
        case (.fileRequest, true):
            return convId.isEmpty ? .unknown : .fileRequest(convId: convId)
        case (.clone, false):
            return .clone
        case (.videoCall, false):
            return .call(peerId: peerId, isVideo: true)
        case (.audioCall, false):
            return .call(peerId: peerId, isVideo: false)
        default:
            return .unknown
        }
    }

    func start(accountId: String, convId: String, loadAll: Bool) {
        self.adapter.start(accountId, convId: convId, loadAll: loadAll)
    }

    func removeDelegate() {
        Adapter.delegate = nil
        self.adapter = nil
    }

    func stop(accountId: String) {
        self.adapter.stop(forAccountId: accountId)
        removeDelegate()
    }

    func getNameFor(address: String, accountId: String) -> String {
        return adapter.getNameFor(address, accountId: accountId)
    }

    func getNameServerFor(accountId: String) -> String {
        return adapter.nameServer(forAccountId: accountId)
    }

    func allowsIncomingCallsFromUnknown(accountId: String) -> Bool {
        return adapter.allowsIncomingCallsFromUnknown(for: accountId)
    }

    func getContacts(accountId: String) -> [[String: String]] {
        return adapter.getContactsFromStorage(accountId)
    }

    private func fileAlreadyDownloaded(fileName: String, accountId: String, conversationId: String) -> Bool {
        guard let url = getFileUrlFor(fileName: fileName, accountId: accountId, conversationId: conversationId) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func getFileUrlFor(fileName: String, accountId: String, conversationId: String) -> URL? {
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let pathUrl = documentsURL.appendingPathComponent(accountId)
            .appendingPathComponent("conversation_data")
            .appendingPathComponent(conversationId)
            .appendingPathComponent(fileName)
        return pathUrl
    }
}

extension AdapterService: AdapterDelegate {

    func didReceiveMessage(_ message: [String: String],
                           from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String) {
        guard let content = message["text/plain"],
              let handler = self.eventHandler else { return }
        handler(.message, EventData(accountId: receiverAccountId, jamiId: senderAccount, conversationId: "", content: content, groupTitle: ""))
    }

    func dataTransferEvent(withFileId transferId: String, withEventCode eventCode: Int, accountId: String, conversationId: String, interactionId: String) {
        guard let handler = self.eventHandler,
              let data = loadingFiles[transferId],
              let code = DataTransferEvent(rawValue: UInt32(eventCode)),
              code.isCompleted() else { return }
        handler(.fileTransferDone, data)
        loadingFiles.removeValue(forKey: transferId)
    }

    func conversationSyncCompleted(accountId: String) {
        guard let handler = self.eventHandler else {
            return
        }
        handler(.syncCompleted, EventData(accountId: accountId))
    }

    func conversationCloned(accountId: String) {
        guard let handler = self.eventHandler else {
            return
        }
        handler(.conversationCloned, EventData(accountId: accountId))
    }

    func receivedConversationRequest(accountId: String, conversationId: String, metadata: [String: String]) {
        guard let handler = self.eventHandler else {
            return
        }
        let contentMessage = L10n.Conversation.incomingRequest
        var groupTitle = ""
        var peerId = ""
        if let title = metadata["title"], !title.isEmpty {
            groupTitle = title
        }
        if let from = metadata["from"] {
            peerId = from
        }
        if !peerId.isEmpty || !groupTitle.isEmpty {
            handler(.invitation, EventData(accountId: accountId, jamiId: peerId, conversationId: conversationId, content: contentMessage, groupTitle: groupTitle))
        }
    }

    func newInteraction(conversationId: String, accountId: String, message: [String: String]) {
        guard let handler = self.eventHandler else {
            return
        }
        guard let type = message[InteractionAttributes.type.rawValue],
              let interactionType = InteractionType(rawValue: type) else {
            return
        }
        let from = message[InteractionAttributes.author.rawValue] ?? ""
        let content = message[InteractionAttributes.body.rawValue] ?? ""
        switch interactionType {
        case .message:
            handler(.message, EventData(accountId: accountId, jamiId: from, conversationId: conversationId, content: content, groupTitle: ""))
        case.fileTransfer:
            guard let fileId = message[InteractionAttributes.fileId.rawValue],
                  let url = self.getFileUrlFor(fileName: fileId, accountId: accountId, conversationId: conversationId) else {
                return
            }
            let data = EventData(accountId: accountId, jamiId: from, conversationId: conversationId, content: url.path, groupTitle: "")
            // check if the file has already been downloaded. If no, download the file if filesize is less than a downloading limit
            if fileAlreadyDownloaded(fileName: fileId, accountId: accountId, conversationId: conversationId) {
                handler(.fileTransferDone, data)
            } else {
                guard let interactionId = message[InteractionAttributes.interactionId.rawValue],
                      let size = message["totalSize"],
                      (Int(size) ?? (maxSizeForAutoaccept + 1)) <= maxSizeForAutoaccept else { return }
                let path = ""
                self.adapter.downloadFile(withFileId: fileId, accountId: accountId, conversationId: conversationId, interactionId: interactionId, withFilePath: path)
                self.loadingFiles[fileId] = data
                handler(.fileTransferInProgress, data)
            }
        case .collabDocument:
            guard let announcement = CollabDocumentAnnouncement(message: message) else { return }
            handler(.documentShared, EventData(accountId: accountId, jamiId: from, conversationId: conversationId,
                                               content: announcement.name, groupTitle: "", documentId: announcement.documentId))
        }
    }

    func collaborativeDocumentReplicated(accountId: String, conversationId: String, documentId: String) {
        guard let handler = self.eventHandler else {
            return
        }
        handler(.documentReplicated, EventData(accountId: accountId, conversationId: conversationId, documentId: documentId))
    }

    func outgoingFileTransferEvent(accountId: String, conversationId: String, eventCode: Int) {
        guard let handler = self.eventHandler,
              let code = DataTransferEvent(rawValue: UInt32(eventCode)) else {
            return
        }
        let data = EventData(accountId: accountId, conversationId: conversationId)
        if code == .ongoing {
            handler(.fileUploadStarted, data)
        } else if code.isCompleted() {
            handler(.fileUploadEnded, data)
        }
    }

    func activeCallsChanged(conversationId: String, accountId: String, calls: [[String: String]]) {
        guard let handler = self.eventHandler else {
            return
        }

        let parsedCalls: [ActiveCall] = calls.compactMap { dict -> ActiveCall? in
            guard let id = dict["id"], let uri = dict["uri"], let device = dict["device"] else {
                return nil
            }

            return ActiveCall(
                id: id,
                uri: uri,
                device: device,
                conversationId: conversationId,
                accountId: accountId,
                isFromLocalDevice: false
            )
        }

        let data = EventData(accountId: accountId, jamiId: "", conversationId: conversationId, content: "", groupTitle: "", calls: parsedCalls)
        handler(.activeCall, data)
    }

    func getConversationInfo(accountId: String, conversationId: String) -> [String: String]? {
        return adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String]
    }

    func getConversationMemebers(accountId: String, conversationId: String) -> [String]? {
        return adapter.getConversationMembers(accountId, conversationId: conversationId)?.compactMap { $0["uri"]?.replacingOccurrences(of: "ring:", with: "") }
    }

    func getAccountDetails(accountId: String) -> [String: String]? {
        return adapter.getAccountDetails(accountId) as? [String: String]
    }

    func getAccountJamiId(accountId: String) -> String? {
        return getAccountDetails(accountId: accountId)?["Account.username"]?.replacingOccurrences(of: "ring:", with: "")
    }

}
