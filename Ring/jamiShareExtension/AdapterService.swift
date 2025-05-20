import SwiftyBeaver
import RxSwift
import Foundation
import MobileCoreServices
import Photos

public final class AdapterService: AdapterDelegate {
    private let log = SwiftyBeaver.self

    private var adapter: Adapter!

    var usernameLookupStatus = PublishSubject<LookupNameResponse>()
    private let disposeBag = DisposeBag()

    init(withAdapter adapter: Adapter) {
        self.adapter = adapter
        Adapter.delegate = self
    }

    func removeDelegate() {
        Adapter.delegate = nil
        adapter = nil

        usernameLookupStatus.onCompleted()
        fileTransferStatusSubject.onCompleted()
        newInteractionSubject.onCompleted()
        messageStatusChangedSubject.onCompleted()
    }

    func sendSwarmMessage(accountId: String, conversationId: String, message: String, parentId: String) {
        adapter.setAccountActive(accountId, active: true)
        adapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
        log.info("*** Message sent ***")
    }

    func setAccountActive(_ accountId: String, newValue: Bool) {
        adapter.setAccountActive(accountId, active: newValue)
    }

    @discardableResult
    func sendSwarmFile(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String) -> String? {
        adapter.setAccountActive(accountId, active: true)

        let fileURL = URL(fileURLWithPath: filePath)

        guard fileURL.startAccessingSecurityScopedResource() else {
            log.error("Cannot access security scoped resource: \(fileURL)")
            return nil
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

            adapter.sendSwarmFile(
                withName: fileName,
                accountId: accountId,
                conversationId: conversationId,
                withFilePath: duplicatedFilePath,
                parent: parentId
            )

            log.info("*** File duplicated and sent successfully ***")
            return duplicatedFilePath

        } catch {
            log.error("Error duplicating file: \(error.localizedDescription)")
            return nil
        }
    }

    func sendSwarmFileAndClean(accountId: String, conversationId: String, filePath: String, fileName: String, parentId: String) {
        if let tempFilePath = sendSwarmFile(
            accountId: accountId,
            conversationId: conversationId,
            filePath: filePath,
            fileName: fileName,
            parentId: parentId
        ) {
            do {
                try FileManager.default.removeItem(atPath: tempFilePath)
                log.info("*** Temp file deleted: \(tempFilePath) ***")
            } catch {
                log.error("Failed to delete temp file: \(error.localizedDescription)")
            }
        } else {
            log.error("File was not sent; no temp file to delete.")
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

        
        for data in conversationData
        where data[Constants.NotificationUserInfoKeys.accountID.rawValue] == accountId &&
            data[Constants.NotificationUserInfoKeys.conversationID.rawValue] == conversationId {
            return
        }

        
        let conversation = [
            Constants.NotificationUserInfoKeys.accountID.rawValue: accountId,
            Constants.NotificationUserInfoKeys.conversationID.rawValue: conversationId
        ]

        conversationData.append(conversation)
        userDefaults.set(conversationData as Any, forKey: Constants.updatedConversations)
    }

    
    public struct NewInteraction {
        public let conversationId: String
        public let accountId: String
        public let messageId: String
        public let type: String
        public let body: [String: Any]
        public let editions: [[String: String]]
    }

    let newInteractionSubject = ReplaySubject<NewInteraction>.create(bufferSize: 1)
    var newInteractionStream: Observable<NewInteraction> {
        return newInteractionSubject.asObservable()
    }
    
    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        
        let bodyDict: [String: Any] = message.body.mapValues { $0 as Any }

        
        let reactionsArray = message.reactions as [[String: String]]
        let editionsArray = message.editions as [[String: String]]

        
        let statusDict = message.status

        let interaction = NewInteraction(
                conversationId: conversationId,
                accountId: accountId,
                messageId: message.id,
                type: message.type,
                body: bodyDict,
                editions: editionsArray
            )

        newInteractionSubject.onNext(interaction)

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

    func getTransferProgress(withId transferId: String, accountId: String, conversationId: String, isSwarm: Bool) -> [String: Int] {
        let info = NSDataTransferInfo()
        info.conversationId = conversationId

        self.adapter.dataTransferInfo(withId: transferId, accountId: accountId, with: info)

        return [
            "totalsize": Int(info.totalSize),
            "progressbyte": Int(info.bytesProgress)
        ]
    }

    private let registeredNamesKey = "REGISTERED_NAMES_KEY"

    private func contactProfileName(accountId: String, contactId: String, type: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }

        let path = ""

        if type == "account" {
            let path = documents.path + "/" + "\(accountId)" + "/profile.vcf"
            return VCardUtils.getNameFromVCard(filePath: path)
        } else if type == "conversation" {
            let uri = "ring:" + contactId
            let path = documents.path + "/" + "\(accountId)" + "/profiles/" + "\(Data(uri.utf8).base64EncodedString()).vcf"
            return VCardUtils.getNameFromVCard(filePath: path)
        }
        return nil
    }

    private func contactProfileAvatar(accountId: String, contactId: String, type: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }

        let path = ""

        if type == "account" {
            let path = documents.path + "/" + "\(accountId)" + "/profile.vcf"
            return VCardUtils.parseToProfile(filePath: path)?.photo
        } else if type == "conversation" {
            let uri = "ring:" + contactId
            let path = documents.path + "/" + "\(accountId)" + "/profiles/" + "\(Data(uri.utf8).base64EncodedString()).vcf"
            return VCardUtils.parseToProfile(filePath: path)?.photo
        }
        return nil
    }

    func resolveLocalAccountName(from accountId: String) -> Single<String> {
        if let localName = contactProfileName(accountId: accountId, contactId: accountId, type: "account"),
           !localName.isEmpty {
            return .just(localName)
        }

        if let username = adapter.getAccountDetails(accountId)["Account.username"] as? String {
            let jamiId = username.replacingOccurrences(of: "ring:", with: "")
            return lookupUsername(address: jamiId)
                .map { [weak self] response in
                    (response.state == .found && !(response.name?.isEmpty ?? true)) ? response.name! : accountId
                }
        }
        return .just(accountId)
    }

    func resolveLocalAccountDetails(accountId: String) -> Single<[String: String]> {
        return resolveLocalAccountName(from: accountId)
            .do(onSuccess: { _ in
            })
            .map { [weak self] name in
                let details: [String: String] = [
                    "accountId": accountId,
                    "accountName": name,
                    "accountAvatar": self!.contactProfileAvatar(accountId: accountId, contactId: accountId, type: "account") ?? "" 
                ]

                return details
            }
    }

    func registeredNameFound(with response: LookupNameResponse) {
        let status: UsernameValidationStatus

        switch response.state {
        case .found:
            status = .alreadyTaken
        case .notFound:
            status = .valid
        case .invalidName, .error:
            status = .invalid
        default:
            log.error("Lookup name error")
            return
        }

        usernameLookupStatus.onNext(response)
    }

    func lookupUsername(address: String) -> Single<LookupNameResponse> {
        return Single.create { [weak self] single in
            guard let self = self else {
                single(.failure(NSError(domain: "AdapterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self deallocated"])))
                return Disposables.create()
            }

            let subscription = self.usernameLookupStatus
                .filter { $0.requestedName == address }
                .take(1)
                .subscribe(onNext: { single(.success($0)) })

            self.adapter.lookupAddress(withAccount: "", nameserver: "", address: address)

            return Disposables.create { subscription.dispose() }
        }
    }

    func describeState(_ state: LookupNameState) -> String {
        switch state {
        case .notFound: return "Not Found"
        case .found: return "Found"
        case .invalidName: return "Invalid Name"
        case .error: return "Error"
        default: return "Unknown"
        }
    }

    func getConversationInfo(accountId: String, conversationId: String) -> Single<(name: String, avatar: String?, accountType: String)> {
        if let result = adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let name = result["title"] {
            let avatar = result["avatar"]
            return .just((name, avatar, "single"))
        }
        
        guard let members = adapter.getConversationMembers(accountId, conversationId: conversationId),
              !members.isEmpty else {
            return .just((conversationId, nil, "jid"))
        }

        guard let accountDetails = adapter.getAccountDetails(accountId),
              let username = accountDetails["Account.username"] as? String else {
            return .just((conversationId, nil, "jid"))
        }

        let jamiId = username.replacingOccurrences(of: "ring:", with: "")
        let filteredMembers = members.filter { member in
            guard let uri = member["uri"] else { return false }
            return uri != jamiId
        }

        let includeAvatar = filteredMembers.count == 1

        let lookups: [Single<(String, String?)>] = filteredMembers.compactMap { [weak self] member in
            guard let address = member["uri"] else { return nil }
            return lookupUsername(address: address)
                .map { [weak self] response in
                    let profileName = self?.contactProfileName(accountId: accountId, contactId: address, type: "conversation") ?? ""
                    let resolvedName = !profileName.isEmpty
                        ? profileName
                        : ((response.state == .found && !(response.name?.isEmpty ?? true)) ? response.name! : address)
                    let avatar = includeAvatar ? self?.contactProfileAvatar(accountId: accountId, contactId: address, type: "conversation") : nil
                    return (resolvedName, avatar)
                }
        }

        guard !lookups.isEmpty else {
            return .just((conversationId, nil, "jid"))
        }

        return Single.zip(lookups)
            .map { nameAvatarPairs in
                let names = nameAvatarPairs.map { $0.0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                let avatars = nameAvatarPairs.compactMap { $0.1 }
                let firstAvatar = avatars.first
                let accountType = nameAvatarPairs.count == 1 ? "single" : "group"
                return (names, firstAvatar, accountType)
            }

        
    }

}

enum UsernameValidationStatus {
    case empty, lookingUp, invalid, alreadyTaken, valid
}
