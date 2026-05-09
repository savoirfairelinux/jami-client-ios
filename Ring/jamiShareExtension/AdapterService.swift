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

    var accountRegistrationStatus = PublishSubject<AccountStatus>()
    private var readyAccounts = Set<String>()
    private let readyAccountsQueue = DispatchQueue(label: "jamiShareExtensionReadyAccounts", attributes: .concurrent)

    private let disposeBag = DisposeBag()

    static let notificationExtensionResponse = Notification.Name(Constants.appIdentifier + ".shareExtensionQueryGotResponseFromNotificationExtension.internal")

    private func containsReadyAccount(_ accountId: String) -> Bool {
        return readyAccountsQueue.sync {
            return readyAccounts.contains(accountId)
        }
    }

    private func insertReadyAccountSync(_ accountId: String) {
        readyAccountsQueue.sync(flags: .barrier) {
            _ = self.readyAccounts.insert(accountId)
        }
    }

    init(withAdapter adapter: Adapter) {
        self.adapter = adapter
        Adapter.delegate = self
    }

    deinit {
        self.removeDarwinNotificationListener()
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
        let canStart = canStartDaemon(timeout: 10.0, pollInterval: 1.0)
        if canStart {
            setupDarwinNotificationListener()
        }
        return canStart
    }

    private func canStartDaemon(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        guard notificationExtensionHasActiveAccount() else {
            return true
        }

        // wait up to 10 seconds for notification extension to complete
        return waitForNotificationExtensionInactive(timeout: timeout, pollInterval: pollInterval)
    }

    private func waitForNotificationExtensionInactive(timeout: TimeInterval, pollInterval: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let result = WaitResult()

        let maxPolls = Int(timeout / pollInterval)
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

        timer.resume()
        semaphore.wait()

        return result.success
    }

    func removeDelegate() {
        accountIsActive.store(false, ordering: .relaxed)
        self.removeDarwinNotificationListener()

        adapter?.cleanup()

        Adapter.delegate = nil
        adapter = nil

        usernameLookupStatus.onCompleted()
        fileTransferStatusSubject.onCompleted()
        newInteractionSubject.onCompleted()
        messageStatusChangedSubject.onCompleted()
    }

    private func waitForAccountReady(accountId: String) -> Bool {
        if containsReadyAccount(accountId) {
            return true
        }

        let semaphore = DispatchSemaphore(value: 0)
        var isReady = false

        let subscription = accountRegistrationStatus
            .filter { $0.accountId == accountId }
            .timeout(.seconds(10), scheduler: MainScheduler.instance)
            .subscribe(
                onNext: { [weak self] status in
                    guard let self = self else {
                        semaphore.signal()
                        return
                    }
                    let accountState = AccountState(rawValue: status.status)
                    if accountState == .registered {
                        self.insertReadyAccountSync(status.accountId)
                        NSLog("[ShareExtension] Account \(accountId) is registered")
                        isReady = true
                        semaphore.signal()
                    }
                },
                onError: { error in
                    NSLog("[ShareExtension] Account registration status timeout or error: \(error)")
                    semaphore.signal()
                }
            )

        subscription.disposed(by: disposeBag)
        setAccountActive(accountId, newValue: true)

        let waitResult = semaphore.wait(timeout: .now() + 12)

        subscription.dispose()
        if waitResult == .timedOut {
            return false
        }

        return isReady
    }

    func sendSwarmMessage(accountId: String, conversationId: String, message: String, parentId: String) {
        if waitForAccountReady(accountId: accountId) {
            CommonHelpers.setUpdatedConversations(accountId: accountId, conversationId: conversationId)
            adapter?.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
        } else {
            NSLog("[ShareExtension] Failed to send swarm message - account \(accountId) not ready")
        }
    }

    private func setAccountActive(_ accountId: String, newValue: Bool) {
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

    func sendSwarmFile(accountId: String, conversationId: String, filePath: URL?, fileData: Data?, fileName: String, parentId: String) {
        guard let destinationURL = CommonHelpers.createFileUrlForSwarm(fileName: fileName, accountId: accountId, conversationId: conversationId) else {
            return
        }

        do {
            // Write file data or copy from source URL
            if let fileData = fileData {
                try fileData.write(to: destinationURL, options: .atomic)
            } else if let filePath = filePath {
                guard filePath.startAccessingSecurityScopedResource() else {
                    return
                }
                defer {
                    filePath.stopAccessingSecurityScopedResource()
                }
                try FileManager.default.copyItem(at: filePath, to: destinationURL)
            } else {
                return
            }

            CommonHelpers.setUpdatedConversations(accountId: accountId, conversationId: conversationId)

            guard waitForAccountReady(accountId: accountId) else {
                NSLog("[ShareExtension] Failed to send swarm file - account \(accountId) not ready")
                return
            }

            NSLog("[ShareExtension] Account \(accountId) is ready, sending swarm file")
            self.adapter?.sendSwarmFile(
                withName: fileName,
                accountId: accountId,
                conversationId: conversationId,
                withFilePath: destinationURL.path,
                parent: parentId
            )

        } catch {
            NSLog("[ShareExtension] sendSwarmFile failed with error: \(error.localizedDescription)")
            return
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

    let newInteractionSubject = ReplaySubject<NewInteraction>.create(bufferSize: 1)
    var newInteractionStream: Observable<NewInteraction> {
        return newInteractionSubject.asObservable()
    }

    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        let bodyDict: [String: Any] = message.body.mapValues { $0 as Any }

        let interaction = NewInteraction(
            conversationId: conversationId,
            accountId: accountId,
            messageId: message.id,
            type: message.type,
            body: bodyDict
        )

        newInteractionSubject.onNext(interaction)
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
            return ProfilePathHelper.accountProfilePath(accountId: accountId, documents: documents)
        case "conversation":
            return ProfilePathHelper.existingContactProfilePath(accountId: accountId, contactId: contactId, documents: documents)
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
            let jamiId = ProfilePathHelper.jamiHash(from: username)
            return lookupUsername(accountId: accountId, address: jamiId)
                .map { response in
                    (response.state == .found && !(response.name?.isEmpty ?? true)) ? (response.name!, .single) : (jamiId, .jamiid)
                }
        }
        return .just(("", .single))
    }

    func resolveLocalAccountAvatar(accountId: String) -> Single<String> {
        return Single.create { [weak self] observer in
            DispatchQueue.global(qos: .background).async {
                let avatar = self?.contactProfileAvatar(accountId: accountId, contactId: accountId, type: "account") ?? ""
                observer(.success(avatar))
            }
            return Disposables.create()
        }
    }

    func registeredNameFound(with response: LookupNameResponse) {
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

    func getConversationName(accountId: String, conversationId: String) -> Single<(name: String, avatarType: AvatarType)> {
        let conversationInfo = adapter?.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String]
        let title = conversationInfo?["title"]

        if let title = title, !title.isEmpty {
            return .just((title, .group))
        }

        guard let members = adapter?.getConversationMembers(accountId, conversationId: conversationId),
              !members.isEmpty else {
            return .just((conversationId, .jamiid))
        }

        guard let accountDetails = adapter?.getAccountDetails(accountId),
              let username = accountDetails["Account.username"] as? String else {
            return .just((conversationId, .jamiid))
        }

        let selfJamiId = ProfilePathHelper.jamiHash(from: username)
        let mode = conversationInfo?["mode"].flatMap { Int($0) } ?? 0
        let isGroup = mode > 0

        if !isGroup {
            return buildCoreDialogName(members: members, selfJamiId: selfJamiId, accountId: accountId)
        }

        return buildGroupName(members: members, selfJamiId: selfJamiId, accountId: accountId, totalMemberCount: members.count)
    }

    private func buildCoreDialogName(members: [[String: String]], selfJamiId: String, accountId: String) -> Single<(name: String, avatarType: AvatarType)> {
        guard let otherMember = members.first(where: { member in
            guard let uri = member["uri"] else { return false }
            return ProfilePathHelper.jamiHash(from: uri) != selfJamiId
        }), let address = otherMember["uri"] else {
            return .just((selfJamiId, .jamiid))
        }

        let profileName = contactProfileName(accountId: accountId, contactId: address, type: "conversation") ?? ""
        if !profileName.isEmpty {
            return .just((profileName, .single))
        }

        return lookupUsername(accountId: accountId, address: address)
            .map { response in
                let name = (response.state == .found && !(response.name?.isEmpty ?? true)) ? response.name! : address
                let isAddress = name == address
                return (name, isAddress ? .jamiid : .single)
            }
    }

    private func buildGroupName(members: [[String: String]], selfJamiId: String, accountId: String, totalMemberCount: Int) -> Single<(name: String, avatarType: AvatarType)> {
        let selfSuffix = " (\(L10n.Conversation.yourself))"

        let nameLookups: [Single<String>] = members.compactMap { [weak self] member in
            guard let address = member["uri"] else { return nil }
            let isSelf = ProfilePathHelper.jamiHash(from: address) == selfJamiId

            if isSelf {
                let selfName = self?.contactProfileName(accountId: accountId, contactId: accountId, type: "account") ?? ""
                if !selfName.isEmpty {
                    return .just(selfName + selfSuffix)
                }
                return self?.lookupUsername(accountId: accountId, address: address)
                    .map { response in
                        let name = (response.state == .found && !(response.name?.isEmpty ?? true)) ? response.name! : address
                        return name + selfSuffix
                    }
            }

            let profileName = self?.contactProfileName(accountId: accountId, contactId: address, type: "conversation") ?? ""
            if !profileName.isEmpty {
                return .just(profileName)
            }

            return self?.lookupUsername(accountId: accountId, address: address)
                .map { response in
                    (response.state == .found && !(response.name?.isEmpty ?? true)) ? response.name! : address
                }
        }

        guard !nameLookups.isEmpty else {
            return .just(("", .group))
        }

        return Single.zip(nameLookups)
            .map { names in
                var uniqueSet = Set<String>()
                let uniqueNames = names
                    .filter { !$0.isEmpty && uniqueSet.insert($0).inserted }
                    .sorted { $0.count < $1.count }

                let displayCount = min(uniqueNames.count, 3)
                let displayedNames = uniqueNames.prefix(displayCount).joined(separator: ", ")
                let othersCount = max(totalMemberCount - displayCount, 0)
                let name = othersCount > 0 ? "\(displayedNames), + \(othersCount)" : displayedNames

                return (name, AvatarType.group)
            }
    }

    func getConversationAvatar(accountId: String, conversationId: String) -> Single<String?> {
        let conversationInfo = adapter?.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String]
        let baseAvatar = conversationInfo?["avatar"]

        if let baseAvatar = baseAvatar, !baseAvatar.isEmpty {
            return .just(baseAvatar)
        }

        let mode = conversationInfo?["mode"].flatMap { Int($0) } ?? 0
        guard mode == 0 else { return .just(nil) }

        guard let members = adapter?.getConversationMembers(accountId, conversationId: conversationId),
              !members.isEmpty else {
            return .just(nil)
        }

        guard let accountDetails = adapter?.getAccountDetails(accountId),
              let username = accountDetails["Account.username"] as? String else {
            return .just(nil)
        }

        let jamiId = ProfilePathHelper.jamiHash(from: username)
        let otherMember = members.first { member in
            guard let uri = member["uri"] else { return false }
            return ProfilePathHelper.jamiHash(from: uri) != jamiId
        }

        guard let address = otherMember?["uri"] else {
            return .just(nil)
        }

        return Single.create { [weak self] observer in
            DispatchQueue.global(qos: .background).async {
                let avatar = self?.contactProfileAvatar(accountId: accountId, contactId: address, type: "conversation")
                observer(.success(avatar))
            }
            return Disposables.create()
        }
    }

    func getGroupMemberProfiles(accountId: String, conversationId: String) -> Single<(members: [GroupAvatarMember], overflowCount: Int)> {
        let conversationInfo = adapter?.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String]
        let mode = conversationInfo?["mode"].flatMap { Int($0) } ?? 0
        guard mode > 0 else { return .just(([], 0)) }

        guard let members = adapter?.getConversationMembers(accountId, conversationId: conversationId),
              !members.isEmpty else {
            return .just(([], 0))
        }

        guard let accountDetails = adapter?.getAccountDetails(accountId),
              let username = accountDetails["Account.username"] as? String else {
            return .just(([], 0))
        }

        let selfJamiId = ProfilePathHelper.jamiHash(from: username)
        let maxAvatars = 3

        struct MemberProfile {
            let address: String
            let isSelf: Bool
            let photo: String?
            let name: String?
            let priority: Int
        }

        let profiles: [MemberProfile] = members.compactMap { member in
            guard let address = member["uri"] else { return nil }
            let isSelf = ProfilePathHelper.jamiHash(from: address) == selfJamiId
            let type = isSelf ? "account" : "conversation"
            let contactId = isSelf ? accountId : address
            let photo = self.contactProfileAvatar(accountId: accountId, contactId: contactId, type: type)
            let name = self.contactProfileName(accountId: accountId, contactId: contactId, type: type)
            let priority: Int
            if photo != nil { priority = 2 } else if let name = name, !name.isEmpty { priority = 1 } else { priority = 0 }
            return MemberProfile(address: address, isSelf: isSelf, photo: photo, name: name, priority: priority)
        }

        let sorted = profiles.sorted { $0.priority > $1.priority }
        let overflowCount = max(sorted.count - maxAvatars, 0)
        let capped = Array(sorted.prefix(maxAvatars))

        let memberLookups: [Single<GroupAvatarMember>] = capped.map { [weak self] profile in
            if profile.name != nil || profile.photo != nil {
                return .just(GroupAvatarMember.resolve(
                    profilePhoto: profile.photo,
                    profileName: profile.name,
                    registeredName: nil,
                    jamiId: profile.address
                ))
            }

            guard let self = self else {
                return .just(GroupAvatarMember(image: nil, name: profile.address))
            }
            return self.lookupUsername(accountId: accountId, address: profile.address)
                .map { response in
                    let registeredName = (response.state == .found && !(response.name?.isEmpty ?? true)) ? response.name : nil
                    return GroupAvatarMember.resolve(
                        profilePhoto: nil,
                        profileName: nil,
                        registeredName: registeredName,
                        jamiId: profile.address
                    )
                }
        }

        guard !memberLookups.isEmpty else { return .just(([], 0)) }
        return Single.zip(memberLookups).map { (members: $0, overflowCount: overflowCount) }
    }

    func registrationStateChanged(for accountId: String, state: String) {
        let status = AccountStatus(accountId: accountId, status: state)
        accountRegistrationStatus.onNext(status)
    }
}

extension AdapterService {
    private func notificationExtensionHasActiveAccount() -> Bool {
        let group = DispatchGroup()
        var nsObserverToken: NSObjectProtocol?

        defer {
            if let token = nsObserverToken {
                NotificationCenter.default.removeObserver(token)
            }
            let observer = Unmanaged.passUnretained(self).toOpaque()
            CFNotificationCenterRemoveObserver(notificationCenter, observer, CFNotificationName(Constants.notificationExtensionResponse), nil)
            group.leave()
        }

        var hasResponse = false
        group.enter()

        nsObserverToken = listenForNotificationResponse(completion: { _ in
            hasResponse = true
        })

        CFNotificationCenterPostNotification(notificationCenter, CFNotificationName(Constants.notificationExtensionIsActive), nil, nil, true)

        _ = group.wait(timeout: .now() + 0.3)

        return hasResponse
    }

    private func listenForNotificationResponse(completion: @escaping (Bool) -> Void) -> NSObjectProtocol {
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

        return NotificationCenter.default.addObserver(forName: AdapterService.notificationExtensionResponse, object: nil, queue: nil) { _ in
            completion(true)
        }
    }

    private func setupDarwinNotificationListener() {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(notificationCenter,
                                        observer,
                                        { (_, observer, _, _, _) in
                                            guard let observer = observer else { return }
                                            let adapterService = Unmanaged<AdapterService>
                                                .fromOpaque(observer).takeUnretainedValue()
                                            adapterService
                                                .handleAccountQuery()
                                        },
                                        Constants.notificationShareExtensionIsActive,
                                        nil,
                                        .deliverImmediately)
    }

    private func handleAccountQuery() {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(notificationCenter,
                                             CFNotificationName(Constants.notificationShareExtensionResponse),
                                             nil,
                                             nil,
                                             true)
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier),
              let notificationData = userDefaults.object(forKey: Constants.notificationData) as? [[String: String]] else {
            return
        }
        userDefaults.set([[String: String]](), forKey: Constants.notificationData)
        if notificationData.isEmpty { return }
        for data in notificationData {
            self.pushNotificationReceived(data: data)
        }
    }

    private func removeDarwinNotificationListener() {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(notificationCenter, observer, CFNotificationName(Constants.notificationShareExtensionIsActive), nil)
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

struct MessageStatusChangedEvent {
    let conversationId: String
    let accountId: String
    let jamiId: String
    let messageId: String
    let status: MessageStatus
}

struct NewInteraction {
    let conversationId: String
    let accountId: String
    let messageId: String
    let type: String
    let body: [String: Any]
}

struct FileTransferStatus {
    let transferId: String
    let eventCode: Int
    let accountId: String
    let conversationId: String
    let interactionId: String
}

struct AccountStatus {
    var accountId: String
    var status: String
}
