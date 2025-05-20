import SwiftyBeaver
import RxSwift
import Foundation
import MobileCoreServices
import Photos

public final class AdapterService: AdapterDelegate {
    private let log = SwiftyBeaver.self
    
    private let adapter: Adapter
    
    var usernameValidationStatus = PublishSubject<UsernameValidationStatus>()
    var usernameLookupStatus = PublishSubject<LookupNameResponse>()

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
        guard let fileURL = URL(string: filePath) else {
            log.error("Invalid file URL string: \(filePath)")
            return
        }
        
        guard fileURL.startAccessingSecurityScopedResource() else {
            log.error("Cannot access security scoped resource: \(fileURL)")
            return
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        
        let fileManager = FileManager.default
        let tempDirectory = NSTemporaryDirectory()
        let duplicatedFilePath = (tempDirectory as NSString).appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: duplicatedFilePath) {
                try fileManager.removeItem(atPath: duplicatedFilePath)
            }
            
            try fileManager.copyItem(at: fileURL, to: URL(fileURLWithPath: duplicatedFilePath))
            
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
    }
    
    public struct NewInteractionEvent {
        public let interaction: NewInteraction
    }
    
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
        let statusDict = message.status
        
        let event = NewInteractionEvent(
            interaction: NewInteraction(
                conversationId: conversationId,
                accountId: accountId,
                messageId: message.id,
                type: message.type,
                parent: message.linearizedParent,
                body: bodyDict,
                reactions: reactionsArray,
                editions: editionsArray
            )
        )
        
        newInteractionSubject.onNext(event)
        log.info("*** New interaction event emitted ***")
    }

    public struct MessageStatusChangedEvent {
        public let conversationId: String
        public let accountId: String
        public let jamiId: String
        public let messageId: String
        public let status: MessageStatus
    }
    
    let messageStatusChangedSubject = ReplaySubject<MessageStatusChangedEvent>.create(bufferSize: 1)

    var messageStatusChangedStream: Observable<MessageStatusChangedEvent> {
        return messageStatusChangedSubject.asObservable()
    }
    
    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String, to jamiId: String, in conversationId: String) {
        let event = MessageStatusChangedEvent(
            conversationId: conversationId,
            accountId: accountId,
            jamiId: jamiId,
            messageId: messageId,
            status: status
        )

        messageStatusChangedSubject.onNext(event)
        log.info("*** Message status changed event emitted ***")
    }
    
    func getTransferProgress(withId transferId: String, accountId: String, conversationId: String, isSwarm: Bool) -> [String : Int] {
        let info = NSDataTransferInfo()
        info.conversationId = conversationId

        self.adapter.dataTransferInfo(withId: transferId, accountId: accountId, with: info)

        return [
            "totalsize": Int(info.totalSize),
            "progressbyte": Int(info.bytesProgress)
        ]
    }
    
    func contactProfileName(accountId: String, contactId: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        let uri = "ring:" + contactId
        let encodedFileName = Data(uri.utf8).base64EncodedString() + ".vcf"
        let profilesFolderPath = documents.path + "/" + "\(accountId)" + "/profiles"
        let fullFilePath = profilesFolderPath + "/" + encodedFileName

        if !FileManager.default.fileExists(atPath: fullFilePath) { return nil }

        return VCardUtils.getNameFromVCard(filePath: fullFilePath)
    }
    
    func resolveLocalAccountName(from accountId: String) -> String {
        if let ylookup = self.adapter.getAccountDetails(accountId),
           let username = ylookup["Account.username"] as? String {
            let jamiId = username.replacingOccurrences(of: "ring:", with: "")
            let xlookup = lookupUsername(account: accountId, address: jamiId)
                .subscribe()
        }
        
        let registeredNamesKey = "REGISTERED_NAMES_KEY"
        
        if let registeredName = contactProfileName(accountId: accountId, contactId: accountId),
           !registeredName.isEmpty {
            return registeredName
        }
        
        
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            if let userNameData = sharedDefaults.dictionary(forKey: registeredNamesKey),
               let accountName = userNameData[accountId] as? String,
               !accountName.isEmpty {
                return accountName
            }
        }


        return accountId
    }
    
    func resolveLocalAccountDetails(accountId: String) -> [String: String] {
        return [
            "accountId": accountId,
            "accountName": resolveLocalAccountName(from: accountId),
            "accountAvatar": resolveLocalAccountName(from: accountId),
        ]
    }

    func registeredNameFound(with response: LookupNameResponse) {
        if response.state == .notFound {
            usernameValidationStatus.onNext(.valid)
        } else if response.state == .found {
            usernameValidationStatus.onNext(.alreadyTaken)
        } else if response.state == .invalidName || response.state == .error {
            usernameValidationStatus.onNext(.invalid)
        } else {
            log.error("Lookup name error")
        }

        usernameLookupStatus.onNext(response)
    }

    func lookupUsername(account: String, address: String) -> Single<LookupNameResponse> {
        return Single<LookupNameResponse>.create { single in
            // Start the actual lookup
            //self.setAccountActive(account, newValue: true)
            
            self.adapter.lookupAddress(withAccount: "", nameserver: "", address: address)

            let subscription = self.usernameLookupStatus
                .take(1)
                .subscribe(onNext: { response in
                    // Debug print block
                    print("\n--- Lookup Response ---")
                    print("Requested Name: \(response.requestedName ?? "<nil>")")
                    print("Name: \(response.name ?? "<nil>")")
                    print("Account ID: \(response.accountId ?? "<nil>")")
                    print("Address: \(response.address ?? "<nil>")")
                    print("State: \(self.describeState(response.state))")
                    print("-----------------------\n")
                    
                    single(.success(response))
                })

            return Disposables.create {
                subscription.dispose()
            }
        }
    }

    // Helper function to describe state
    func describeState(_ state: LookupNameState) -> String {
        switch state {
        case .notFound: return "Not Found"
        case .found: return "Found"
        case .invalidName: return "Invalid Name"
        case .error: return "Error"
        default: return "Unknown"
        }
    }

}

enum UsernameValidationStatus {
    case empty
    case lookingUp
    case invalid
    case alreadyTaken
    case valid
}
