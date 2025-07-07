/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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

import RxSwift
import Foundation
import Photos
import Atomics

// swiftlint:disable type_body_length
public final class AdapterService: AdapterDelegate {
    private var adapter: Adapter?

    private var accountIsActive = ManagedAtomic<Bool>(false)

    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    var usernameLookupStatus = PublishSubject<LookupNameResponse>()
    private let disposeBag = DisposeBag()

    static let notificationExtensionResponse = Notification.Name(Constants.appIdentifier + ".shareExtensionQueryGotResponseFromNotificationExtension.internal")

    init(withAdapter adapter: Adapter) {
        self.adapter = adapter
        Adapter.delegate = self
    }

    func startDaemon() {
        guard let adapter = self.adapter else { return }
        guard adapter.initDaemon() else { return }

        // Start daemon - returns NO if already initialized (doing nothing),
        // or YES if it actually started the daemon
        if adapter.startDaemon() {
            // Daemon was actually started so set accounts active
            accountIsActive.store(true, ordering: .relaxed)
        }
    }

    func canStartDaemon() -> Bool {
        return canStartDaemon(timeout: 10.0, pollInterval: 1.0)
    }

    private func canStartDaemon(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        guard notificationExtensionHasActiveAccount() else {
            return true
        }

        return waitForNotificationExtensionInactive(timeout: timeout, pollInterval: pollInterval)
    }

    private func waitForNotificationExtensionInactive(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let result = WaitResult()

        let maxPolls = Int(timeout / pollInterval)
        let timer = createPollingTimer(
            pollInterval: pollInterval,
            maxPolls: maxPolls,
            result: result,
            semaphore: semaphore
        )

        guard let timer = timer else {
            return false
        }

        timer.resume()
        semaphore.wait()

        return result.success
    }

    private func createPollingTimer(
        pollInterval: TimeInterval,
        maxPolls: Int,
        result: WaitResult,
        semaphore: DispatchSemaphore
    ) -> DispatchSourceTimer? {

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        var pollCount = 0

        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            pollCount += 1

            let shouldComplete: Bool
            let success: Bool

            if let self = self, !self.notificationExtensionHasActiveAccount() {
                shouldComplete = true
                success = true
            } else if pollCount >= maxPolls {
                shouldComplete = true
                success = false
            } else {
                shouldComplete = false
                success = false
            }

            if shouldComplete {
                timer.cancel()
                result.success = success
                semaphore.signal()
            }
        }

        return timer
    }

    func removeDelegate() {
        accountIsActive.store(false, ordering: .relaxed)

        // Clear signal handlers to prevent duplication on next extension launch
        adapter?.cleanup()

        Adapter.delegate = nil
        adapter = nil

        usernameLookupStatus.onCompleted()
        fileTransferStatusSubject.onCompleted()
        newInteractionSubject.onCompleted()
        messageStatusChangedSubject.onCompleted()
    }

    func sendSwarmMessage(accountId: String, conversationId: String, message: String, parentId: String) {
        setAccountActive(accountId, newValue: true)
        adapter?.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
    }

    func setAccountActive(_ accountId: String, newValue: Bool) {
        if newValue {
            if accountIsActive.compareExchange(expected: false, desired: true, ordering: .relaxed).exchanged {
                adapter?.setAccountActive(accountId, active: true)
            }
        } else {
            adapter?.setAccountActive(accountId, active: false)
        }
    }

    func setAllAccountsInactive() {
        let accounts = getAccountList()
        for accountId in accounts {
            adapter?.setAccountActive(accountId, active: false)
        }
        accountIsActive.store(false, ordering: .relaxed)
    }

    func pushNotificationReceived(data: [String: Any]) {
        var notificationData = [String: String]()
        for key in data.keys {
            if let value = data[key] {
                let valueString = String(describing: value)
                let keyString = String(describing: key)
                notificationData[keyString] = valueString
            }
        }
        self.adapter?.pushNotificationReceived("", message: notificationData)
    }

    /// Check if share extension has an active account
    func hasActiveAccount() -> Bool {
        return accountIsActive.load(ordering: .relaxed)
    }

    func createFileUrlForSwarm(fileName: String, accountId: String, conversationId: String) -> URL? {
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(accountId)
            .appendingPathComponent("conversation_data")
            .appendingPathComponent(conversationId)
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
            var finalFileName = fileNameOnly + "." + fileExtensionOnly
            var filePathCheck = directoryURL.appendingPathComponent(finalFileName)
            var fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
            var duplicates = 2
            while fileExists {
                finalFileName = fileNameOnly + "_" + String(duplicates) + "." + fileExtensionOnly
                filePathCheck = directoryURL.appendingPathComponent(finalFileName)
                fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
                duplicates += 1
            }
            return filePathCheck
        }
        return nil
    }

    @discardableResult
    func sendSwarmFile(accountId: String, conversationId: String, filePath: URL, fileName: String, parentId: String) -> String? {
        guard filePath.startAccessingSecurityScopedResource() else {
            return nil
        }

        defer {
            filePath.stopAccessingSecurityScopedResource()
        }

        guard let duplicatedFilePath = self.createFileUrlForSwarm(fileName: fileName, accountId: accountId, conversationId: conversationId)?.path else {
            return nil
        }

        let fileManager = FileManager.default

        do {

            try fileManager.copyItem(at: filePath, to: URL(fileURLWithPath: duplicatedFilePath))

            self.adapter?.setAccountActive(accountId, active: true)

            self.adapter?.sendSwarmFile(
                withName: fileName,
                accountId: accountId,
                conversationId: conversationId,
                withFilePath: duplicatedFilePath,
                parent: parentId
            )
            return duplicatedFilePath

        } catch {
            print("[ShareExtension] sendSwarmFile failed with error: \(error.localizedDescription)")
            print("[ShareExtension] Error details: \(error)")
            return nil
        }
    }

    func getAccountList() -> [String] {
        return adapter?.getAccountList() as? [String] ?? []
    }

    func getConversationsByAccount() -> [String: [String]] {
        var result: [String: [String]] = [:]
        for account in getAccountList() {
            let conversations = adapter?.getSwarmConversations(forAccount: account) as? [String] ?? []

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
        print("[ShareExtension] dataTransferEvent - transferId: \(transferId), eventCode: \(eventCode), accountId: \(accountId), conversationId: \(conversationId), interactionId: \(interactionId)")

        // Log human readable event description
        if let dataTransferEvent = DataTransferEvent(rawValue: UInt32(eventCode)) {
            print("[ShareExtension] Transfer event: \(dataTransferEvent.description)")
        } else {
            print("[ShareExtension] Unknown transfer event code: \(eventCode)")
        }

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
    }

    let newInteractionSubject = ReplaySubject<NewInteraction>.create(bufferSize: 1)
    var newInteractionStream: Observable<NewInteraction> {
        return newInteractionSubject.asObservable()
    }

    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        print("[ShareExtension] newInteraction - conversationId: \(conversationId), accountId: \(accountId), messageId: \(message.id), type: \(message.type)")

        // Log file transfer related interactions
        if message.type == "application/data-transfer+json" {
            print("[ShareExtension] File transfer interaction detected")
            if let body = message.body["body"] as? String {
                print("[ShareExtension] Transfer body: \(body)")
            }
        }

        let bodyDict: [String: Any] = message.body.mapValues { $0 as Any }

        let statusDict = message.status

        let interaction = NewInteraction(
            conversationId: conversationId,
            accountId: accountId,
            messageId: message.id,
            type: message.type,
            body: bodyDict
        )

        newInteractionSubject.onNext(interaction)
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
    }

    func getTransferProgress(withId transferId: String, accountId: String, conversationId: String, isSwarm: Bool) -> [String: Int] {
        let info = NSDataTransferInfo()
        info.conversationId = conversationId

        self.adapter?.dataTransferInfo(withId: transferId, accountId: accountId, with: info)

        return [
            "totalsize": Int(info.totalSize),
            "progressbyte": Int(info.bytesProgress)
        ]
    }

    private func contactProfileName(accountId: String, contactId: String, type: String) -> String? {
        guard let path = buildVCardPath(accountId: accountId, contactId: contactId, type: type) else {
            return nil
        }
        return VCardUtils.getNameFromVCard(filePath: path)
    }

    private func contactProfileAvatar(accountId: String, contactId: String, type: String) -> String? {
        guard let path = buildVCardPath(accountId: accountId, contactId: contactId, type: type) else {
            return nil
        }
        return VCardUtils.parseToProfile(filePath: path)?.photo
    }

    private func buildVCardPath(accountId: String, contactId: String, type: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }

        switch type {
        case "account":
            return documents.path + "/" + accountId + "/profile.vcf"
        case "conversation":
            let uri = "ring:" + contactId
            let encoded = Data(uri.utf8).base64EncodedString()
            return documents.path + "/" + accountId + "/profiles/" + encoded + ".vcf"
        default:
            return nil
        }
    }

    func resolveLocalAccountName(from accountId: String) -> Single<(value: String, avatarType: AvatarType)> {
        if let localName = contactProfileName(accountId: accountId, contactId: accountId, type: "account"),
           !localName.isEmpty {
            return .just((localName, .single))
        }

        if let username = adapter?.getAccountDetails(accountId)["Account.username"] as? String {
            let jamiId = username.replacingOccurrences(of: "ring:", with: "")
            return lookupUsername(accountId: accountId, address: jamiId)
                .map { [weak self] response in
                    (response.state == .found && !(response.name?.isEmpty ?? true)) ? (response.name!, .single) : (jamiId, .jamiid)
                }
        }
        return .just(("", .single))
    }

    struct AccountDetails {
        let accountId: String
        let accountName: String
        let accountAvatarType: AvatarType
        let accountAvatar: String
    }

    func getDefaultAccount() -> String? {
        if let sharedDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            if let selectedAccountID = sharedDefaults.string(forKey: "SELECTED_ACCOUNT_ID") {
                print("==========ACFTSET: \(selectedAccountID)")
                return selectedAccountID
            }
        }
        return nil
    }

    func resolveLocalAccountDetails(accountId: String) -> Single<AccountDetails> {
        return resolveLocalAccountName(from: accountId)
            .map { [weak self] name in
                return AccountDetails(
                    accountId: accountId,
                    accountName: name.value,
                    accountAvatarType: name.avatarType,
                    accountAvatar: self?.contactProfileAvatar(accountId: accountId, contactId: accountId, type: "account") ?? ""
                )
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
            return
        }

        usernameLookupStatus.onNext(response)
    }

    func lookupUsername(accountId: String, address: String) -> Single<LookupNameResponse> {
        return Single.create { [weak self] single in
            guard let self = self else {
                single(.failure(NSError(domain: "AdapterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self deallocated"])))
                return Disposables.create()
            }

            let subscription = self.usernameLookupStatus
                .filter { $0.requestedName == address }
                .take(1)
                .subscribe(onNext: { single(.success($0)) })

            self.adapter?.lookupAddress(withAccount: accountId, nameserver: "", address: address)

            return Disposables.create { subscription.dispose() }
        }
    }

    func getConversationInfo(accountId: String, conversationId: String) -> Single<(name: String, avatar: String?, avatarType: AvatarType)> {
        let conversationInfo = adapter?.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String]
        let title = conversationInfo?["title"]
        let baseAvatar = conversationInfo?["avatar"]

        guard let members = adapter?.getConversationMembers(accountId, conversationId: conversationId),
              !members.isEmpty else {
            let fallbackName = title ?? conversationId
            return .just((fallbackName, baseAvatar, .jamiid))
        }

        guard let accountDetails = adapter?.getAccountDetails(accountId),
              let username = accountDetails["Account.username"] as? String else {
            let fallbackName = title ?? conversationId
            return .just((fallbackName, baseAvatar, .jamiid))
        }

        let jamiId = username.replacingOccurrences(of: "ring:", with: "")
        let filteredMembers = members.filter { member in
            guard let uri = member["uri"] else { return false }
            return uri != jamiId
        }

        let includeAvatar = filteredMembers.count == 1
        let lookups: [Single<(String, String?, Bool)>] = filteredMembers.compactMap { [weak self] member in
            guard let address = member["uri"] else { return nil }
            return self?.lookupUsername(accountId: accountId, address: address)
                .map { [weak self] response in
                    let profileName = self?.contactProfileName(accountId: accountId, contactId: address, type: "conversation") ?? ""
                    let nameFromLookup = (response.state == .found && !(response.name?.isEmpty ?? true)) ? response.name! : nil
                    let resolvedName = !profileName.isEmpty ? profileName : (nameFromLookup ?? address)
                    let isAddress = resolvedName == address
                    let avatar = includeAvatar ? self?.contactProfileAvatar(accountId: accountId, contactId: address, type: "conversation") : nil
                    return (resolvedName, avatar, isAddress)
                }
        }

        guard !lookups.isEmpty else {
            let fallbackName = title ?? conversationId
            return .just((fallbackName, baseAvatar, .jamiid))
        }

        return Single.zip(lookups)
            .map { nameAvatarFlagTriplets in
                let names = nameAvatarFlagTriplets.map { $0.0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                let avatars = nameAvatarFlagTriplets.compactMap { $0.1 }
                let firstAvatar = baseAvatar ?? avatars.first

                let avatarType: AvatarType
                if nameAvatarFlagTriplets.count == 1 {
                    avatarType = nameAvatarFlagTriplets.first!.2 ? .jamiid : .single
                } else {
                    avatarType = .group
                }

                let finalName = title?.isEmpty == false ? title! : names
                return (finalName, firstAvatar, avatarType)
            }
    }

    private var darwinObserver: UnsafeMutableRawPointer?
    private var notificationObserver: NSObjectProtocol?

    private func notificationExtensionHasActiveAccount() -> Bool {
        let group = DispatchGroup()
        defer {
            removeNotificationObserver()
            group.leave()
        }
        var hasResponse = false
        group.enter()

        listenForNotificationResponse(completion: { _ in
            hasResponse = true
        })

        CFNotificationCenterPostNotification(notificationCenter, CFNotificationName(Constants.notificationExtensionIsActive), nil, nil, true)

        _ = group.wait(timeout: .now() + 0.3)

        return hasResponse
    }

    private func listenForNotificationResponse(completion: @escaping (Bool) -> Void) {
        removeNotificationObserver()

        darwinObserver = Unmanaged.passRetained(self).toOpaque()

        CFNotificationCenterAddObserver(notificationCenter,
                                        darwinObserver, { (_, _, _, _, _) in
                                            NotificationCenter.default.post(name: AdapterService.notificationExtensionResponse,
                                                                            object: nil,
                                                                            userInfo: nil)
                                        },
                                        Constants.notificationExtensionResponse,
                                        nil,
                                        .deliverImmediately)

        notificationObserver = NotificationCenter.default.addObserver(forName: AdapterService.notificationExtensionResponse, object: nil, queue: nil) { _ in
            completion(true)
        }
    }

    private func removeNotificationObserver() {
        if let observer = darwinObserver {
            CFNotificationCenterRemoveEveryObserver(notificationCenter, observer)
            Unmanaged<AdapterService>.fromOpaque(observer).release()
            darwinObserver = nil
        }
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }
}

private class WaitResult {
    private let lock = NSLock()
    private var _success: Bool = false

    var success: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _success
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _success = newValue
        }
    }
}

enum UsernameValidationStatus {
    case empty, lookingUp, invalid, alreadyTaken, valid
}

enum AvatarType: String {
    case jamiid
    case single
    case group
}
