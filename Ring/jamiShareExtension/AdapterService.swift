import SwiftyBeaver
import RxSwift
import Foundation
import MobileCoreServices
import Photos

public final class AdapterService: AdapterDelegate {
    private let log = SwiftyBeaver.self

    private let adapter: Adapter

    init(withAdapter adapter: Adapter) {
        self.adapter = adapter
        Adapter.delegate = self
    }
    
    func sendSwarmMessage(accountId: String, conversationId: String, message: String, parentId: String) {
        adapter.setAccountActive(accountId, active: true)
        adapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
        log.info("*** Message sent ***")
    }

    func setAccountActive(_ accountId: String, newValue: Bool) {
        adapter.setAccountActive(accountId, active: newValue)
    }

    func sendSwarmFile(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String) {
        let cleanedPath = filePath.replacingOccurrences(of: "file://", with: "")
        let fileManager = FileManager.default
        let tempDirectory = NSTemporaryDirectory()
        let duplicatedFilePath = (tempDirectory as NSString).appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: duplicatedFilePath) {
                try fileManager.removeItem(atPath: duplicatedFilePath)
            }

            try fileManager.copyItem(atPath: cleanedPath, toPath: duplicatedFilePath)

            adapter.sendSwarmFile(withName: fileName, accountId: accountId, conversationId: conversationId, withFilePath: duplicatedFilePath, parent: parentId)
            log.info("*** File duplicated and sent successfully ***")
        } catch {
            log.error("Error duplicating file: \(error.localizedDescription)")
        }
    }

    func getAccountList() -> [String] {
        return adapter.getAccountList() as? [String] ?? []
    }

    func getConversationsByAccount() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for account in getAccountList() {
            let conversations = adapter.getSwarmConversations(forAccount: account) as? [String] ?? []
            result[account] = conversations
        }
        return result
    }

    struct FileTransferStatus {
        let transferId: String
        let eventCode: Int
        let accountId: String
        let conversationId: String
        let interactionId: String
    }
    
    let fileTransferStatusSubject = ReplaySubject<FileTransferStatus>.create(bufferSize: 1)

    var fileTransferStatusStream: Observable<FileTransferStatus> {
        return fileTransferStatusSubject.asObservable()
    }

    func dataTransferEvent(withFileId transferId: String, withEventCode eventCode: Int, accountId: String, conversationId: String, interactionId: String) {
        print("****************")
        print("Data transfer event received - fileId: \(transferId), eventCode: \(eventCode), accountId: \(accountId), conversationId: \(conversationId), interactionId: \(interactionId)")

        let status = FileTransferStatus(
            transferId: transferId,
            eventCode: eventCode,
            accountId: accountId,
            conversationId: conversationId,
            interactionId: interactionId
        )

        fileTransferStatusSubject.onNext(status)
    }
    
    func setUpdatedConversations(accountId: String, conversationId: String) {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            return
        }
        var conversationData = [[String: String]]()
        if let existingData = userDefaults.object(forKey: Constants.updatedConversations) as? [[String: String]] {
            conversationData = existingData
        }
        
        // Check if this conversation with the same accountId and conversationId already exists
        for data in conversationData
        where data[Constants.NotificationUserInfoKeys.accountID.rawValue] == accountId &&
              data[Constants.NotificationUserInfoKeys.conversationID.rawValue] == conversationId {
            return
        }

        // Add new conversation dictionary
        let conversation = [
            Constants.NotificationUserInfoKeys.accountID.rawValue: accountId,
            Constants.NotificationUserInfoKeys.conversationID.rawValue: conversationId
        ]

        conversationData.append(conversation)
        userDefaults.set(conversationData as Any, forKey: Constants.updatedConversations)
    }

    // Define NewInteraction and NewInteractionEvent structs (adjust fields as needed)
    public struct NewInteraction {
        public let conversationId: String
        public let accountId: String
        public let messageId: String
        public let type: String
        public let parent: String?
        public let body: [String: Any]
        public let reactions: [[String: String]]
        public let editions: [[String: String]]
        public let status: [String: String]
    }

    public struct NewInteractionEvent {
        public let interaction: NewInteraction
    }

    // AdapterService additions/modifications

    let newInteractionSubject = ReplaySubject<NewInteractionEvent>.create(bufferSize: 1)

    var newInteractionStream: Observable<NewInteractionEvent> {
        return newInteractionSubject.asObservable()
    }

    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        // Convert body dictionary [String: String] to [String: Any] for compatibility
        let bodyDict: [String: Any] = message.body.mapValues { $0 as Any }

        // reactions and editions are already arrays of dictionaries [String: String]
        let reactionsArray = message.reactions as [[String: String]]
        let editionsArray = message.editions as [[String: String]]

        // Convert status dictionary [String: NSNumber] to [String: String]
        let statusDict = message.status.mapValues { $0.stringValue }

        let event = NewInteractionEvent(
            interaction: NewInteraction(
                conversationId: conversationId,
                accountId: accountId,
                messageId: message.id,
                type: message.type,
                parent: message.linearizedParent,
                body: bodyDict,
                reactions: reactionsArray,
                editions: editionsArray,
                status: statusDict
            )
        )

        newInteractionSubject.onNext(event)
        log.info("*** New interaction event emitted ***")
    }
}
