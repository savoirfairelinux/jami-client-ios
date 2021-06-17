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

class AdapterService {
    enum MessageAttributes: String {
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

    enum MessageType: String {
        case message = "text/plain"
        case fileTransfer = "application/data-transfer+json"
        case contact = "member"
        case call = "application/call-history+json"
        case location = "location"
        case merge = "merge"
        case initial = "initial"
    }

    enum EventType: Int {
        case message
        case fileTransfer
        case downloadingFile
        case completed
        case call
    }

    enum NotificationType {
        case call(peerId: String, isVideo: Bool)
        case gitMessage
        case unknown
    }

    enum DataTransferEventCode: Int {
        case invalid
        case created
        case unsupported
        case waitPeeracceptance
        case waitHostAcceptance
        case ongoing
        case finished
        case closedByHost
        case closedByPeer
        case invalidPathname
        case unjoinablePeer
    }

    /// Indicates whether the daemon is started or not.
    var daemonStarted = false
    private static let appGroupIdentifier = "group.com.savoirfairelinux.ring"
    private let documentsPath: URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("Documents")
    }()
    private let maxSizeForAutoaccept = 20 * 1024 * 1024

    typealias EventData = (accountId: String, jamiId: String, content: String)

    private let adapter: Adapter
    var eventHandler: ((EventType, EventData) -> Void)?
    var loadingFiles = [String: EventData]()

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

    func startDaemonWithListener(listener: @escaping (EventType, EventData) -> Void) {
        self.eventHandler = listener
        startDaemon()
    }

    func startDaemon() {
        if daemonStarted {
            return
        }
        if adapter.startDaemon() {
            daemonStarted = true
        } else {
            os_log("&&&&&&&&failed to init daemon")
        }
    }

    func stopDaemon() {
        self.adapter.stopDaemon()
    }

    func decrypt(keyPath: String, messagesPath: String, value: [String: Any]) -> NotificationType {
        let result = adapter.decrypt(keyPath, treated: messagesPath, value: value)
        guard let peerId = result?.keys.first,
              let type = result?.values.first else {
            return .unknown}
        switch type {
        case "videoCall":
            return NotificationType.call(peerId: peerId, isVideo: true)
        case "audioCall":
            return NotificationType.call(peerId: peerId, isVideo: false)
        case "gitMessage":
            return NotificationType.gitMessage
        default:
            return .unknown
        }
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
            self.eventHandler!(.message, EventData(receiverAccountId, senderAccount, content))
        }
    }
    func dataTransferEvent(withFileId transferId: String, withEventCode eventCode: Int, accountId: String, conversationId: String, interactionId: String) {
        os_log("&&&&&&&& got file transfer update")

        if eventCode != 6 {
            return
        }

        guard let handler = self.eventHandler else {
            return
        }

        guard let data = loadingFiles[transferId] else {
            return

        }
        DispatchQueue.main.async {
            handler(.fileTransfer, data)
        }
    }

    func conversationSyncCompleted(accountId: String) {
        guard let handler = self.eventHandler else {
            return
        }
        handler(.completed, EventData(accountId, "", ""))
    }

    func receivedCallConnectionRequest(accountId: String, peerId: String, hasVideo: Bool) {
        guard let handler = self.eventHandler else {
            return
        }
        handler(.call, EventData(accountId, peerId, "\(hasVideo)"))
    }

    func newInteraction(conversationId: String, accountId: String, message: [String: String]) {
        guard let handler = self.eventHandler else {
            return
        }
        guard let type = message[MessageAttributes.type.rawValue],
              let messageType = MessageType(rawValue: type),
              messageType == MessageType.fileTransfer || messageType == MessageType.message else {
            return
        }
        var from = ""
        var content = ""
        if let author = message[MessageAttributes.author.rawValue] {
            from = author
        }
        if let body = message[MessageAttributes.body.rawValue] {
            content = body
        }
        switch messageType {
        case .message:
            handler(.message, EventData(accountId, from, content))
        case.fileTransfer:
            guard let fileid = message[MessageAttributes.fileId.rawValue] else {
                return
            }
            os_log("&&&&&&&&file transfer received")
            let fileUrl = self.getFilePathForSwarm(fileName: fileid, accountID: accountId, conversationID: conversationId)
            guard let pathUrl = fileUrl else {
                return
            }
            let data = EventData(accountId, from, pathUrl.path)
            if getImageFromFile(for: fileid, maxSize: 200, accountID: accountId, conversationID: conversationId) != nil {
                handler(.fileTransfer, data)
            } else {
                guard let interactionId = message[MessageAttributes.interactionId.rawValue] else {
                    return
                }
                if let size = message["totalSize"],
                   Int(size) ?? 30 * 1024 * 1024 <= maxSizeForAutoaccept {
                    let path = ""
                    self.adapter.downloadSwarmTransfer(withFileId: fileid, accountId: accountId, conversationId: conversationId, interactionId: interactionId, withFilePath: path)
                    self.loadingFiles[fileid] = data
                    handler(.downloadingFile, data)
                    os_log("&&&&&&&&downloading file")
                }
            }
        default:
            break
        }
    }

    private func getImageFromFile(for name: String,
                                  maxSize: CGFloat,
                                  accountID: String,
                                  conversationID: String) -> UIImage? {
        let fileUrl = self.getFileUrlForSwarm(fileName: name, accountID: accountID, conversationID: conversationID)
        guard let pathUrl = fileUrl else { return nil }
        let fileExtension = pathUrl.pathExtension as CFString
        guard let uti = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension,
                fileExtension,
                nil) else { return nil }
        if UTTypeConformsTo(uti.takeRetainedValue(), kUTTypeImage) {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: pathUrl.path) {
                if fileExtension as String == "gif" {
                    // let image = UIImage.gifImageWithUrl(pathUrl)
                    return nil
                }
                let image = UIImage(contentsOfFile: pathUrl.path)
                return image
            }
        } else {
        }
        return nil
    }
    /// get url for saved file for swarm conversation. If file does not exists return nil
    func getFileUrlForSwarm(fileName: String, accountID: String, conversationID: String) -> URL? {
        guard let documentsURL = documentsPath else {
            return nil
        }
        let pathUrl = documentsURL.appendingPathComponent(accountID)
            .appendingPathComponent("conversation_data")
            .appendingPathComponent(conversationID)
            .appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: pathUrl.path) {
            return pathUrl
        }
        return nil
    }

    /// get url for saved file for swarm conversation. If file does not exists return nil
    func getFilePathForSwarm(fileName: String, accountID: String, conversationID: String) -> URL? {
        guard let documentsURL = documentsPath else {
            return nil
        }
        let pathUrl = documentsURL.appendingPathComponent(accountID)
            .appendingPathComponent("conversation_data")
            .appendingPathComponent(conversationID)
            .appendingPathComponent(fileName)

        return pathUrl
    }

    enum Directories: String {
        case recorded
        case downloads
    }

}
