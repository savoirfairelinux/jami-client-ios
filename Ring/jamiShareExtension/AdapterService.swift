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

    // Atomic property to track if share extension has an active account
    private var accountIsActive = ManagedAtomic<Bool>(false)

    // Darwin notification center for inter-extension communication
    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    // Polling mechanism for notification extension monitoring
    private var notificationExtensionMonitorTimer: Timer?
    private var monitoringStartTime: Date?
    private let monitoringTimeout: TimeInterval = 10.0
    private let pollingInterval: TimeInterval = 1.0

    var usernameLookupStatus = PublishSubject<LookupNameResponse>()
    private let disposeBag = DisposeBag()

    static let notificationExtensionResponse = Notification.Name(Constants.appIdentifier + ".shareExtensionQueryGotResponseFromNotificationExtension.internal")

    init(withAdapter adapter: Adapter) {
        print("[ShareExtension] AdapterService init - setting up adapter and delegate")
        self.adapter = adapter
        Adapter.delegate = self
        print("[ShareExtension] AdapterService init completed")
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

    /// Check if daemon can be started (waits up to 10 seconds for notification extension to become free)
    /// Returns true if daemon can be started, false if notification extension is still active after timeout
    func canStartDaemon() -> Bool {
        // If notification extension doesn't have active account, we can proceed immediately
        if !notificationExtensionHasActiveAccount() {
            return true
        }

        // Wait and poll for 10 seconds to see if notification extension becomes inactive
        let semaphore = DispatchSemaphore(value: 0)
        var canProceed = false
        var pollCount = 0
        let maxPolls = 10 // 10 seconds with 1-second intervals

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            pollCount += 1

            if !self.notificationExtensionHasActiveAccount() {
                // Notification extension became inactive, we can proceed
                canProceed = true
                timer.invalidate()
                semaphore.signal()
            } else if pollCount >= maxPolls {
                // Timeout reached, notification extension still active
                canProceed = false
                timer.invalidate()
                semaphore.signal()
            }
        }

        // Wait for either success or timeout
        semaphore.wait()
        return canProceed
    }

    func removeDelegate() {
        accountIsActive.store(false, ordering: .relaxed)

        Adapter.delegate = nil
        adapter = nil

        usernameLookupStatus.onCompleted()
        fileTransferStatusSubject.onCompleted()
        newInteractionSubject.onCompleted()
        messageStatusChangedSubject.onCompleted()
    }

    func sendSwarmMessage(accountId: String, conversationId: String, message: String, parentId: String) {
        print("[ShareExtension] sendSwarmMessage - accountId: \(accountId), conversationId: \(conversationId), message: \(message), parentId: \(parentId)")
        setAccountActive(accountId, newValue: true)
        adapter?.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
        print("[ShareExtension] sendSwarmMessage completed")
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

    @discardableResult
    func sendSwarmFile(accountId: String, conversationId: String, filePath: URL, fileName: String, parentId: String) -> String? {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }

            print("[ShareExtension] Starting security scoped resource access")
            guard filePath.startAccessingSecurityScopedResource() else {
                print("[ShareExtension] sendSwarmFile failed - could not start accessing security scoped resource")
                return
            }

            defer {
                filePath.stopAccessingSecurityScopedResource()
                print("[ShareExtension] Security scoped resource access stopped")
            }

            let fileManager = FileManager.default

            // Use shared app group container instead of extension's temp directory
            guard let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) else {
                return
            }

            print("[ShareExtension] Shared container URL: \(sharedContainerURL.path)")

            let tempDirectory = sharedContainerURL.appendingPathComponent("ShareExtensionTemp")
            let duplicatedFilePath = tempDirectory.appendingPathComponent(fileName).path

            do {
                if !fileManager.fileExists(atPath: tempDirectory.path) {
                    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
                    print("[ShareExtension] Temp directory created successfully")
                } else {
                    print("[ShareExtension] Temp directory already exists")
                }

                if fileManager.fileExists(atPath: duplicatedFilePath) {
                    try fileManager.removeItem(atPath: duplicatedFilePath)
                    print("[ShareExtension] Existing file removed")
                }

                try fileManager.copyItem(at: filePath, to: URL(fileURLWithPath: duplicatedFilePath))
                print("[ShareExtension] File copied successfully")

                self.setAccountActive(accountId, newValue: true)

                print("[ShareExtension] Calling adapter sendSwarmFile")
                self.adapter?.sendSwarmFile(
                    withName: fileName,
                    accountId: accountId,
                    conversationId: conversationId,
                    withFilePath: duplicatedFilePath,
                    parent: parentId
                )
                print("[ShareExtension] sendSwarmFile call completed")

            } catch {
                print("[ShareExtension] sendSwarmFile failed with error: \(error.localizedDescription)")
                print("[ShareExtension] Error details: \(error)")
            }
        }
        return nil
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

        CFNotificationCenterPostNotification(notificationCenter, CFNotificationName(Constants.notificationExtensionQuery), nil, nil, true)

        _ = group.wait(timeout: .now() + 0.3)

        return hasResponse
    }

    private func listenForNotificationResponse(completion: @escaping (Bool) -> Void) {
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(notificationCenter,
                                        observer, { (_, _, _, _, _) in
                                            NotificationCenter.default.post(name: AdapterService.notificationExtensionResponse,
                                                                            object: nil,
                                                                            userInfo: nil)
                                        },
                                        Constants.notificationExtensionResponse,
                                        nil,
                                        .deliverImmediately)

        NotificationCenter.default.addObserver(forName: AdapterService.notificationExtensionResponse, object: nil, queue: nil) { _ in
            completion(true)
        }
    }

    private func removeNotificationObserver() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(notificationCenter, observer)
        NotificationCenter.default.removeObserver(self, name: AdapterService.notificationExtensionResponse, object: nil)
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
