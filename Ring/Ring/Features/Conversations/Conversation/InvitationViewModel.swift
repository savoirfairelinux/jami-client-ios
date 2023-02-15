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

/*
 This class manages the presentation of received requests and requests that we are going to send.
 Initial parameters could be RequestModel for incoming requests or jamiId for a search result that we are going to send the request.
 */

enum InvitationStatus {
    case temporary ///  result from search
    case pending /// received request
    case synchronizing ///  conversation request in synchronization
    case added
    case refused
    case invalid
}

class InvitationViewModel: ViewModel {

    // MARK: observable properties for view
    var invitationStatus = BehaviorRelay<InvitationStatus>(value: .invalid)
    var displayName = BehaviorRelay<String>(value: "")
    var profileImageData = BehaviorRelay<Data?>(value: nil)

    private var contactJamiId: String = "" ///  for conversation from search result
    private var conversationId: String = "" ///  will be empty for search result
    private var accountId: String = ""
    private var alias: String = "" ///  name to save to db
    private var request: RequestModel? ///  for requests
    private var invitationHandeledCB: ((_ conversationId: String) -> Void)!

    private let contactsService: ContactsService
    private let requestsService: RequestsService
    private let conversationsService: ConversationsService
    private let nameService: NameService

    private let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.nameService = injectionBag.nameService
    }

    // MARK: set initial info

    func setInfoForSearchResult(contactJamiId: String, accountId: String, displayName: String, alias: String, avatar: Data?, invitationHandeledCB: @escaping ((_ conversationId: String) -> Void)) {
        self.invitationHandeledCB = invitationHandeledCB
        self.contactJamiId = contactJamiId
        self.accountId = accountId
        self.alias = alias
        let initialDisplayName = displayName.isEmpty ? contactJamiId : displayName
        self.displayName.accept(initialDisplayName)
        self.profileImageData.accept(avatar)
        invitationStatus.accept(.temporary)
        self.listenConversationStatusForContact()
    }

    func setInfoForRequest(request: RequestModel, displayName: String, invitationHandeledCB: @escaping ((_ conversationId: String) -> Void)) {
        self.invitationHandeledCB = invitationHandeledCB
        self.accountId = request.accountId
        self.displayName.accept(displayName)
        self.request = request
        self.conversationId = request.conversationId
        if displayName.isEmpty {
            self.displayName.accept(request.name)
        }
        if self.displayName.value == request.participants.first?.jamiId {
            self.lookupUserName(request: request)
        }
        self.profileImageData.accept(request.avatar)
        if let participantId = request.participants.first?.jamiId, request.isDialog() {
            self.contactJamiId = participantId
        }
        // invitation status presentation
        invitationStatus.accept(.pending)
        if request.type == .contact {
            self.listenConversationStatusForContact()
            return
        }
        self.listenConversationStatus()
        // request became in synchronization right after accepting and before contact became online and synchronization finished
        self.request!.synchronizing
            .startWith(self.request!.synchronizing.value)
            .subscribe(onNext: { [weak self] synchronizing in
                if synchronizing {
                    self?.invitationStatus.accept(.synchronizing)
                }
            }, onError: { _ in
            })
            .disposed(by: self.disposeBag)
    }

    private func lookupUserName(request: RequestModel) {
        guard let jamiId = request.participants.first?.jamiId else { return }

        self.nameService.usernameLookupStatus.asObservable()
            .filter({ lookupNameResponse in
                return lookupNameResponse.address == jamiId
            })
            .take(1)
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if lookupNameResponse.state == .found && !lookupNameResponse.name.isEmpty {
                    self?.displayName.accept(lookupNameResponse.name)
                }
            })
            .disposed(by: self.disposeBag)

        self.nameService.lookupAddress(withAccount: request.accountId,
                                       nameserver: "",
                                       address: jamiId)
    }

    // MARK: listen conversation ready

    private func listenConversationStatus() {
        self.conversationsService.conversationReady
            .subscribe { [weak self] conversationId in
                guard let self = self else { return }
                if conversationId == self.conversationId {
                    self.invitationStatus.accept(.added)
                    self.invitationHandeledCB(conversationId)
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    /**
     When we send request to peer from search result we do not have conversation id.
     We need to check participants for conversation to find if conversationReady related to current request
     */
    private func listenConversationStatusForContact() {
        self.conversationsService.conversationReady
            .subscribe { [weak self] conversationId in
                guard let self = self else { return }
                guard let conversation = self.conversationsService.getConversationForId(conversationId: conversationId, accountId: self.accountId) else { return }
                if conversation.isCoredialog() && conversation.containsParticipant(participant: self.contactJamiId) {
                    self.invitationStatus.accept(.added)
                    self.invitationHandeledCB(conversationId)
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    // MARK: Request actions
    /**
     For contact requests or for one-to-one conversation requests when a peer is not added to contacts yet call acceptContactRequest.
     Otherwise acceptConverversationRequest. In case of succes request will became in synchronization.
     */
    func acceptRequest() {
        guard let request = self.request else { return }
        guard let jamiId = request.participants.first?.jamiId else { return }
        if request.type == .contact || (request.isDialog() && self.contactsService.contact(withHash: jamiId) == nil) {
            self.requestsService
                .acceptContactRequest(jamiId: jamiId, withAccount: self.accountId)
                .subscribe()
                .disposed(by: self.disposeBag)
        } else {
            self.requestsService
                .acceptConverversationRequest(conversationId: self.conversationId, withAccount: self.accountId)
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }
    /**
     For contact requests or for one-to-one conversation requests when a peer is not added to contacts yet call discardContactRequest.
     Otherwise discardConverversationRequest. In case of succes request will be removed. invitationStatus became refused.
     */
    func refuseRequest() {
        guard let request = self.request else { return }
        guard let jamiId = request.participants.first?.jamiId else { return }
        if request.type == .contact || (request.isDialog() && self.contactsService.contact(withHash: jamiId) == nil) {
            self.requestsService
                .discardContactRequest(jamiId: jamiId, withAccount: self.accountId)
                .subscribe { _ in
                } onError: {[weak self] _ in
                    self?.log.error("refuse contact request failed")
                } onCompleted: { [weak self] in
                    self?.invitationHandeledCB("")
                    self?.invitationStatus.accept(.refused)
                }
                .disposed(by: self.disposeBag)
        } else {
            self.requestsService
                .discardConverversationRequest(conversationId: self.conversationId, withAccount: self.accountId)
                .subscribe { _ in
                } onError: { [weak self] _ in
                    self?.log.error("refuse conversation request failed")
                } onCompleted: {[weak self] in
                    self?.invitationHandeledCB("")
                    self?.invitationStatus.accept(.refused)
                }
                .disposed(by: self.disposeBag)
        }
    }
    /**
     For contact requests or for one-to-one conversation requests when a peer is not added to contacts yet call discardContactRequest.
     Otherwise discardConverversationRequest. In case of succes request will be removed. invitationStatus became refused.
     */
    func banRequest() {
        guard let request = self.request else { return }
        guard let jamiId = request.participants.first?.jamiId else { return }
        if request.type == .contact || (request.isDialog() && self.contactsService.contact(withHash: jamiId) == nil) {
            self.requestsService
                .discardContactRequest(jamiId: jamiId, withAccount: self.accountId)
                .subscribe { _ in
                } onError: { [weak self] _ in
                    self?.log.error("ban contact request failed")
                } onCompleted: {[weak self] in
                    guard let self = self else { return }
                    self.invitationHandeledCB("")
                    self.invitationStatus.accept(.refused)
                    self.contactsService.removeContact(withId: jamiId,
                                                       ban: true,
                                                       withAccountId: request.accountId)
                        .subscribe()
                        .disposed(by: self.disposeBag)
                }
                .disposed(by: self.disposeBag)

        } else {
            self.requestsService.discardConverversationRequest(conversationId: self.conversationId, withAccount: self.accountId)
                .subscribe { _ in
                } onError: { [weak self] _ in
                    self?.log.error("ban conversation request failed")
                } onCompleted: { [weak self] in
                    self?.invitationHandeledCB("")
                    self?.invitationStatus.accept(.refused)
                }
                .disposed(by: self.disposeBag)
        }
    }

    func sendRequest() {
        let avatar = self.profileImageData.value != nil ? String(data: self.profileImageData.value!.base64EncodedData(), encoding: .utf8) : nil

        self.requestsService
            .sendContactRequest(to: self.contactJamiId,
                                withAccountId: self.accountId,
                                avatar: avatar,
                                alias: self.alias)
            .subscribe(onCompleted: { [weak self] in
                self?.log.info("contact request sent")
            }, onError: { [weak self] (_) in
                self?.log.error("error sending contact request")
            })
            .disposed(by: self.disposeBag)
    }
}
