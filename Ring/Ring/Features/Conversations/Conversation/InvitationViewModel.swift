/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
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

import UIKit
import RxSwift
import RxRelay
import SwiftyBeaver

enum InvitationStatus {
    case temporary // result from search
    case pending // received contact request
    case inSynchronization
    case added
    case banned
    case invalid
}

class InvitationViewModel: ViewModel {

    var invitationStatus = BehaviorRelay<InvitationStatus>(value: .invalid)
    var displayName = BehaviorRelay<String>(value: "")
    var profileImageData = BehaviorRelay<Data?>(value: nil)

    private var contactUri: String = ""
    private var conversationId: String = ""
    private var accountId: String = ""
    private let contactsService: ContactsService
    private let requestsService: RequestsService
    private let conversationsService: ConversationsService
    private let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self
    private var conversation: ConversationModel!

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
    }

    func setInfo(conversation: ConversationModel, displayName: String) {
        self.displayName.accept(displayName)
        self.conversation = conversation
        guard let participant = conversation.getParticipants().first?.uri else { return }
        self.contactUri = participant
        if displayName.isEmpty {
            self.displayName.accept(self.contactUri)
        }
        self.conversationId = conversation.conversationId
        self.accountId = conversation.accountId
        if conversation.conversationId.isEmpty {
            // could be temporary or pending
           // let status: InvitationStatus = conversation.isRequest ? .pending : .temporary
           // self.invitationStatus.accept(status)
            self.contactsService.contactStatus
                .filter({ contact in
                    contact.uriString == self.contactUri
                })
                .subscribe { [weak self] contact in
                    self?.updateStatus(contact: contact)
                } onError: {[weak self] _ in
                    self?.log.error("error receiving contactStatus")
                }
                .disposed(by: self.disposeBag)
            if let profile = self.contactsService.getProfile(uri: self.contactUri, accountId: self.accountId),
               let alias = profile.alias, let photo = profile.photo {
                self.displayName.accept(alias)
                if let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    self.profileImageData.accept(data)
                }
            }
            return
        }
        if let info = self.conversationsService.getConversationInfo(for: self.conversationId, accountId: conversation.accountId) {
            if let avatar = info[ConversationAttributes.avatar.rawValue] {
                profileImageData.accept(avatar.data(using: .utf8))
            }
            if let title = info[ConversationAttributes.title.rawValue] {
                self.displayName.accept(title)
            }
        }
//        if conversation.isRequest {
//            self.invitationStatus.accept(.pending)
//        }
    }

    func updateStatus(contact: ContactModel) {
        if contact.banned {
            self.invitationStatus.accept(.banned)
        } else {
            self.invitationStatus.accept(.added)
        }
    }

    func acceptRequest() {
        if self.conversation.isCoredialog() && self.contactsService.contact(withUri: self.contactUri.replacingOccurrences(of: "ring:", with: "")) == nil {
            self.requestsService.acceptContactRequest(jamiId: self.contactUri.replacingOccurrences(of: "ring:", with: ""), withAccount: self.accountId)
                .subscribe { _ in
                } onError: { error in
                    self.log.error("accept contact request failed")
                }
                .disposed(by: self.disposeBag)
        } else {
            self.requestsService.acceptConverversationRequest(conversationId: self.conversation.conversationId, withAccount: self.accountId)
                .subscribe { _ in
                } onError: { error in
                    self.log.error("accept conversation request failed")
                }
                .disposed(by: self.disposeBag)
        }
    }

    func refuseRequest() {
        if self.conversation.isCoredialog() && self.contactsService.contact(withUri: self.contactUri.replacingOccurrences(of: "ring:", with: "")) == nil {
            self.requestsService.discardContactRequest(jamiId: self.contactUri.replacingOccurrences(of: "ring:", with: ""), withAccount: self.accountId)
                .subscribe { _ in
                } onError: { error in
                    self.log.error("refuse contact request failed")
                }
                .disposed(by: self.disposeBag)
        } else {
            self.requestsService.discardConverversationRequest(conversationId: self.conversation.conversationId, withAccount: self.accountId)
                .subscribe { _ in
                } onError: { error in
                    self.log.error("refuse conversation request failed")
                }
                .disposed(by: self.disposeBag)
        }
    }

    func banRequest() {
        if self.conversation.isCoredialog() && self.contactsService.contact(withUri: self.contactUri.replacingOccurrences(of: "ring:", with: "")) == nil {
            self.requestsService.discardContactRequest(jamiId: self.contactUri.replacingOccurrences(of: "ring:", with: ""), withAccount: self.accountId).subscribe { _ in
            } onError: { error in
                self.log.error("ban contact request failed")
            }
            .disposed(by: self.disposeBag)
        } else {
            self.requestsService.discardConverversationRequest(conversationId: self.conversation.conversationId, withAccount: self.accountId)
                .subscribe { _ in
                } onError: { error in
                    self.log.error("ban conversation request failed")
                }
                .disposed(by: self.disposeBag)
        }
    }

    func sendRequest() {
        self.contactsService
            .sendContactRequest(toContactRingId: self.contactUri.replacingOccurrences(of: "ring:", with: ""),
                                withAccount: self.accountId)
            .subscribe(onCompleted: { [weak self] in
                self?.log.info("contact request sent")
            }, onError: { [weak self] (error) in
                self?.log.error("error sending contact request")
            })
            .disposed(by: self.disposeBag)
    }
}
