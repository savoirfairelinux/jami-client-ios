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

public final class AdapterService: AdapterDelegate {
    private var adapter: Adapter?

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
        adapter?.setAccountActive(accountId, active: true)
        adapter?.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
    }

    func setAccountActive(_ accountId: String, newValue: Bool) {
        adapter?.setAccountActive(accountId, active: newValue)
    }

    func sendSwarmFile(accountId: String, conversationId: String, filePath: URL, fileName: String, parentId: String) {
        guard filePath.startAccessingSecurityScopedResource() else {
            return
        }

        defer {
            filePath.stopAccessingSecurityScopedResource()
        }

        guard let duplicatedFilePath = CommonHelpers.createFileUrlForSwarm(fileName: fileName, accountId: accountId, conversationId: conversationId)?.path else {
            return
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
            return

        } catch {
            print("[ShareExtension] sendSwarmFile failed with error: \(error.localizedDescription)")
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
                .map { response in
                    (response.state == .found && !(response.name?.isEmpty ?? true)) ? (response.name!, .single) : (jamiId, .jamiid)
                }
        }
        return .just(("", .single))
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
