/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import UIKit
import RxSwift
import RxCocoa
import SwiftyBeaver

// swiftlint:disable type_body_length
class ShareConversationViewModel {

    /// Logger
    private let log = SwiftyBeaver.self

    // Services
    private let shareService: ShareAdapterService
    private let nameService: ShareNameService

    let injectionBag: ShareInjectionBag

    internal let disposeBag = DisposeBag()

    private var isJamsAccount: Bool { self.shareService.isJams(for: self.conversation.value.accountId) }

    var isAccountSip: Bool = false

    var displayName = BehaviorRelay<String?>(value: nil)
    var userName = BehaviorRelay<String>(value: "")
    lazy var bestName: Observable<String> = {
        return Observable
            .combineLatest(userName.asObservable(),
                           displayName.asObservable(),
                           resultSelector: {(userName, displayname) in
                            guard let displayname = displayname, !displayname.isEmpty else { return userName }
                            return displayname
                           })
    }()

    /// Group's image data
    var profileImageData = BehaviorRelay<Data?>(value: nil)

    var swarmInfo: ShareSwarmInfoProtocol?

    required init(with injectionBag: ShareInjectionBag) {
        self.injectionBag = injectionBag
        self.nameService = injectionBag.nameService
        self.shareService = injectionBag.daemonService
    }

    func setConversation(_ conversation: ShareConversationModel) {
        if self.conversation != nil {
            self.conversation.accept(conversation)
        } else {
            self.conversation = BehaviorRelay(value: conversation)
        }
    }

    convenience init(with injectionBag: ShareInjectionBag, conversation: ShareConversationModel, user: JamsUserSearchModel) {
        self.init(with: injectionBag)
        self.userName.accept(user.username)
        self.displayName.accept(user.firstName + " " + user.lastName)
        self.profileImageData.accept(user.profilePicture)
        self.setConversation(conversation) // required to trigger the didSet
    }

    var conversation: BehaviorRelay<ShareConversationModel>! {
        didSet {
            guard let account = self.shareService.getAccount(fromAccountId: self.conversation.value.accountId) else { return }
            if account.type == AccountType.sip {
                self.userName.accept(self.conversation.value.hash)
                self.isAccountSip = true
                return
            }

            if conversation.value.isSwarm() && self.swarmInfo == nil && !self.conversation.value.id.isEmpty {
                self.swarmInfo = ShareSwarmInfo(injectionBag: self.injectionBag, conversation: self.conversation.value)
                self.swarmInfo!.finalAvatar.share()
                    .observe(on: MainScheduler.instance)
                    .subscribe { [weak self] image in
                        self?.profileImageData.accept(image.pngData())
                    } onError: { _ in
                    }
                    .disposed(by: self.disposeBag)
                self.swarmInfo!.finalTitle.share()
                    .observe(on: MainScheduler.instance)
                    .subscribe { [weak self] name in
                        self?.userName.accept(name)
                    } onError: { _ in
                    }
                    .disposed(by: self.disposeBag)
            } else {
                let filterParicipants = conversation.value.getParticipants()
                self.userName.accept(filterParicipants.first?.jamiId ?? "")
                self.subscribeUserServiceLookupStatus()
                self.nameService.lookupAddress(withAccount: self.conversation.value.accountId, nameserver: "", address: filterParicipants.first?.jamiId ?? "")
            }
        }
    }

    /// Displays the entire date ( for messages received before the current week )
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    /// Displays the hour of the message reception ( for messages received today )
    private lazy var hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    func sendMessage(withContent content: String, contactURI: String? = nil, parentId: String = "") {
        let conversation = self.conversation.value
        if !conversation.isSwarm() {
            /// send not swarm message
            guard let participantJamiId = conversation.getParticipants().first?.jamiId,
                  let account = self.shareService.currentAccount else { return }
            // TODO: Send Non Swam Message
            print("Error Non Swarm Account")
            //            self.shareService
            //                .sendNonSwarmMessage(withContent: content,
            //                                     from: account,
            //                                     jamiId: participantJamiId)
            //                .subscribe(onCompleted: { [weak self] in
            //                    self?.log.debug("Message sent")
            //                })
            //                .disposed(by: self.disposeBag)
            return
        }
        if conversation.id.isEmpty {
            return
        }
        /// send swarm message
        //                self.shareService.sendSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: content, parentId: parentId)
    }

    deinit {}

    let shouldDismiss = BehaviorRelay<Bool>(value: false)

    var conversationCreated = BehaviorRelay(value: true)
}

// MARK: Conversation didSet functions
extension ShareConversationViewModel {
    private func subscribeUserServiceLookupStatus() {
        // Return an observer for the username lookup
        self.nameService
            .usernameLookupStatus
            .filter({ [weak self] lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    (lookupNameResponse.address == self?.conversation.value.getParticipants().first?.jamiId ||
                        lookupNameResponse.address == self?.conversation.value.getParticipants().first?.jamiId)
            })
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if let name = lookupNameResponse.name, !name.isEmpty {
                    self?.userName.accept(name)
                } else if let address = lookupNameResponse.address {
                    self?.userName.accept(address)
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: Location sharing
extension ShareConversationViewModel {
    func model() -> ShareConversationModel {
        return self.conversation.value
    }
}

// MARK: share message
extension ShareConversationViewModel {

    private func shareMessage(message: ShareMessageModel, with contact: ShareContact, fileURL: URL?, fileName: String) {
        if message.messageType != .fileTransfer {
            self.sendMessage(withContent: message.content, contactURI: contact.uri)
            return
        }
        //        if let url = fileURL {
        //            if let jamiId = self.conversation.value.getParticipants().first?.jamiId, contact.hash == jamiId {
        //                // if contact.hash == self.conversation.value.getParticipants().first!.jamiId {
        //                self.sendFile(filePath: url.path, displayName: fileName, contactHash: contact.hash)
        //            } else if let data = FileManager.default.contents(atPath: url.path),
        //                      let convId = self.shareService.getConversationForParticipant(jamiId: contact.hash, accontId: contact.accountID)?.id {
        //                self.sendAndSaveFile(displayName: fileName, imageData: data, conversationId: convId, accountId: contact.accountID)
        //            }
        //            return
        //        }
    }

    private func shareMessage(message: ShareMessageModel, with selectedContacts: [ShareConferencableItem]) {
        // to send file we need to have file url or image
        let url = message.url
        var fileName = message.content
        if message.content.contains("\n") {
            guard let substring = message.content.split(separator: "\n").first else { return }
            fileName = String(substring)
        }
        selectedContacts.forEach { (item) in
            guard let contact = item.contacts.first else { return }
            self.shareMessage(message: message, with: contact, fileURL: url, fileName: fileName)
        }
    }
}

// MARK: file transfer
extension ShareConversationViewModel {
    func sendFile(filePath: String, displayName: String, localIdentifier: String? = nil, contactHash: String? = nil) {
        //        self.shareService.sendFile(conversation: self.conversation.value, filePath: filePath, displayName: displayName, localIdentifier: localIdentifier)
    }

    func sendAndSaveFile(displayName: String, imageData: Data, conversationId: String? = nil, accountId: String? = nil) {
        //        if let conversationId = conversationId,
        //           let accountId = accountId,
        //           let conversation = self.shareService.getConversationForId(conversationId: conversationId, accountId: accountId) {
        //            self.shareService.sendAndSaveFile(displayName: displayName, conversation: conversation, imageData: imageData)
        //        } else {
        //            self.shareService.sendAndSaveFile(displayName: displayName, conversation: self.conversation.value, imageData: imageData)
        //        }
    }
}

extension ShareConversationViewModel: Equatable {
    static func == (lhs: ShareConversationViewModel, rhs: ShareConversationViewModel) -> Bool {
        lhs.conversation.value == rhs.conversation.value
    }
}
