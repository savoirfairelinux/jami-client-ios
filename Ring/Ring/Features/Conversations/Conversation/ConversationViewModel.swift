/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
import RxCocoa
import SwiftyBeaver

// swiftlint:disable type_body_length
class ConversationViewModel: Stateable, ViewModel {

    /// Logger
    private let log = SwiftyBeaver.self

    // Services
    private let conversationsService: ConversationsService
    private let accountService: AccountsService
    private let nameService: NameService
    private let contactsService: ContactsService
    private let presenceService: PresenceService
    private let profileService: ProfilesService
    private let callService: CallsService
    private let locationSharingService: LocationSharingService
    let dataTransferService: DataTransferService

    let injectionBag: InjectionBag

    internal let disposeBag = DisposeBag()

    private var players = [String: PlayerViewModel]()

    func getPlayer(messageID: String) -> PlayerViewModel? {
        return players[messageID]
    }
    func setPlayer(messageID: String, player: PlayerViewModel) { players[messageID] = player }
    func closeAllPlayers() {
        let queue = DispatchQueue.global(qos: .default)
        queue.sync {
            self.players.values.forEach { (player) in
                player.closePlayer()
            }
            self.players.removeAll()
        }
    }

    let showInvitation = BehaviorRelay<Bool>(value: false)

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    var synchronizing = BehaviorRelay<Bool>(value: false)

    lazy var typingIndicator: Observable<Bool> = {
        return self.conversationsService
            .sharedResponseStream
            .filter({ [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.messageTypingIndicator &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.conversation.value.accountId &&
                    event.getEventInput(ServiceEventInput.peerUri) == self?.conversation.value.hash
            })
            .map({ (event) -> Bool in
                if let status: Int = event.getEventInput(ServiceEventInput.state), status == 1 {
                    return true
                }
                return false
            })
    }()

    private var isJamsAccount: Bool { self.accountService.isJams(for: self.conversation.value.accountId) }

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
    /// My profile's image data
    var myOwnProfileImageData: Data?

    var contactPresence = BehaviorRelay<Bool>(value: false)
    var swarmInfo: SwarmInfoProtocol?

    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.contactsService = injectionBag.contactsService
        self.presenceService = injectionBag.presenceService
        self.profileService = injectionBag.profileService
        self.dataTransferService = injectionBag.dataTransferService
        self.callService = injectionBag.callService
        self.locationSharingService = injectionBag.locationSharingService
    }

    private func setConversation(_ conversation: ConversationModel) {
        if self.conversation != nil {
            self.conversation.accept(conversation)
        } else {
            self.conversation = BehaviorRelay(value: conversation)
        }
    }

    convenience init(with injectionBag: InjectionBag, conversation: ConversationModel, user: JamiSearchViewModel.JamsUserSearchModel) {
        self.init(with: injectionBag)
        self.userName.accept(user.username)
        self.displayName.accept(user.firstName + " " + user.lastName)
        self.profileImageData.accept(user.profilePicture)
        self.setConversation(conversation) // required to trigger the didSet
    }

    var request: RequestModel? {
        didSet {
            if request != nil && !self.showInvitation.value {
                self.showInvitation.accept(true)
            }
        }
    }

    var conversation: BehaviorRelay<ConversationModel>! {
        didSet {
            self.subscribeUnreadMessages()
            self.subscribeProfileServiceMyPhoto()

            guard let account = self.accountService.getAccount(fromAccountId: self.conversation.value.accountId) else { return }
            if account.type == AccountType.sip {
                self.userName.accept(self.conversation.value.hash)
                self.isAccountSip = true
                self.subscribeLastMessagesUpdate()
                return
            }
            ///
            let showInv = self.request != nil || self.conversation.value.id.isEmpty
            if self.showInvitation.value != showInv {
                self.showInvitation.accept(showInv)
            }

            self.subscribePresenceServiceContactPresence()
            if conversation.value.isSwarm() && self.swarmInfo == nil && !self.conversation.value.id.isEmpty {
                self.swarmInfo = SwarmInfo(injectionBag: self.injectionBag, conversation: self.conversation.value)
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
                if let contact = self.contactsService.contact(withHash: filterParicipants.first?.jamiId ?? "") {
                    if let profile = self.contactsService.getProfile(uri: "ring:" + (filterParicipants.first?.jamiId ?? ""), accountId: self.conversation.value.accountId),
                       let alias = profile.alias, let photo = profile.photo {
                        if !alias.isEmpty {
                            self.displayName.accept(alias)
                        }
                        if !photo.isEmpty {
                            let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? // {
                            self.profileImageData.accept(data)
                        }
                    }
                    if let contactUserName = contact.userName {
                        self.userName.accept(contactUserName)
                    } else if self.userName.value.isEmpty {
                        self.userName.accept(filterParicipants.first?.jamiId ?? "")
                        self.subscribeUserServiceLookupStatus()
                        self.nameService.lookupAddress(withAccount: self.conversation.value.accountId, nameserver: "", address: filterParicipants.first?.jamiId ?? "")
                    }
                } else {
                    self.userName.accept(filterParicipants.first?.jamiId ?? "")
                    self.subscribeUserServiceLookupStatus()
                    self.nameService.lookupAddress(withAccount: self.conversation.value.accountId, nameserver: "", address: filterParicipants.first?.jamiId ?? "")
                }
            }
            subscribeLastMessagesUpdate()
            subscribeConversationSynchronization()
            // self.subscribeConversationServiceTypingIndicator()
        }
    }

    private func subscribeConversationSynchronization() {
        let syncObservable = self.conversation.flatMap { conversation -> BehaviorRelay<Bool> in
            let innerObservable = conversation.synchronizing
            return innerObservable
        }
        syncObservable
            .startWith(self.conversation.value.synchronizing.value)
            .subscribe { [weak self] synchronizing in
                guard let self = self else { return }
                self.synchronizing.accept(synchronizing)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func subscribeLastMessagesUpdate() {
        conversation.value.newMessages
            .subscribe { [weak self] _ in
                guard let self = self, let lastMessage = self.conversation.value.lastMessage else { return }
                self.lastMessage.accept(lastMessage.content)
                let lastMessageDate = lastMessage.receivedDate
                let dateToday = Date()
                var dateString = ""
                let todayWeekOfYear = Calendar.current.component(.weekOfYear, from: dateToday)
                let todayDay = Calendar.current.component(.day, from: dateToday)
                let todayMonth = Calendar.current.component(.month, from: dateToday)
                let todayYear = Calendar.current.component(.year, from: dateToday)
                let weekOfYear = Calendar.current.component(.weekOfYear, from: lastMessageDate)
                let day = Calendar.current.component(.day, from: lastMessageDate)
                let month = Calendar.current.component(.month, from: lastMessageDate)
                let year = Calendar.current.component(.year, from: lastMessageDate)
                if todayDay == day && todayMonth == month && todayYear == year {
                    dateString = self.hourFormatter.string(from: lastMessageDate)
                } else if day == todayDay - 1 {
                    dateString = L10n.Smartlist.yesterday
                } else if todayYear == year && todayWeekOfYear == weekOfYear {
                    dateString = lastMessageDate.dayOfWeek()
                } else {
                    dateString = self.dateFormatter.string(from: lastMessageDate)
                }
                self.lastMessageReceivedDate.accept(dateString)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
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

    var unreadMessages = BehaviorRelay<String>(value: "")

    var lastMessage = BehaviorRelay<String>(value: "")
    var lastMessageReceivedDate = BehaviorRelay<String>(value: "")

    var hideNewMessagesLabel = BehaviorRelay<Bool>(value: true)

    var hideDate: Bool { self.conversation.value.messages.isEmpty }

    func sendMessage(withContent content: String, contactURI: String? = nil, parentId: String = "") {
        let conversation = self.conversation.value
        if !conversation.isSwarm() {
            /// send not swarm message
            guard let participantJamiId = conversation.getParticipants().first?.jamiId,
                  let account = self.accountService.currentAccount else { return }
            /// if in call send sip msg
            if let call = self.callService.call(participantHash: participantJamiId, accountID: conversation.accountId) {
                self.callService.sendTextMessage(callID: call.callId, message: content, accountId: account)
                return
            }
            self.conversationsService
                .sendNonSwarmMessage(withContent: content,
                                     from: account,
                                     jamiId: participantJamiId)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.debug("Message sent")
                })
                .disposed(by: self.disposeBag)
            return
        }
        if conversation.id.isEmpty {
            return
        }
        /// send swarm message
        self.conversationsService.sendSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: content, parentId: parentId)
    }

    func setMessagesAsRead() {
        guard let account = self.accountService.currentAccount,
              let ringId = AccountModelHelper(withAccount: account).ringId else { return }
        self.conversationsService
            .setMessagesAsRead(forConversation: self.conversation.value,
                               accountId: account.id,
                               accountURI: ringId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func setMessageAsRead(daemonId: String, messageId: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.conversationsService
                .setMessageAsRead(conversation: self.conversation.value,
                                  messageId: messageId,
                                  daemonId: daemonId)
        }
    }

    func startCall() {
        guard let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return }
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: jamiId, userName: self.displayName.value ?? self.userName.value))
    }

    func loadMoreMessages(messageId: String) {
        self.conversationsService
            .loadConversationMessages(conversationId: self.conversation.value.id,
                                      accountId: self.conversation.value.accountId,
                                      from: messageId)
    }

    func startAudioCall() {
        guard let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return }
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: jamiId, userName: self.displayName.value ?? self.userName.value))
    }

    func showContactInfo() {
        if self.showInvitation.value {
            return
        }
        self.closeAllPlayers()
        let isSwarmConversation = conversation.value.type != .nonSwarm && conversation.value.type != .sip
        if isSwarmConversation {
            if let swarmInfo = self.swarmInfo {
                self.stateSubject.onNext(ConversationState.presentSwarmInfo(swarmInfo: swarmInfo))
            }
        } else {
            self.stateSubject.onNext(ConversationState.contactDetail(conversationViewModel: self.conversation.value))
        }
    }

    func recordVideoFile() {
        closeAllPlayers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation.value, audioOnly: false))
        }
    }

    func recordAudioFile() {
        closeAllPlayers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation.value, audioOnly: true))
        }
    }

    func haveCurrentCall() -> Bool {
        if !self.conversation.value.isDialog() {
            return false
        }
        guard let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return false }
        return self.callService.call(participantHash: jamiId, accountID: self.conversation.value.accountId) != nil
    }

    lazy var showCallButton: Observable<Bool> = {
        return self.callService
            .currentCallsEvents
            .share()
            .asObservable()
            .filter({ [weak self] (call) -> Bool in
                guard let self = self else { return false }
                if !self.conversation.value.isDialog() {
                    return false
                }
                guard let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return false }
                return call.paricipantHash() == jamiId
                    && call.accountId == self.conversation.value.accountId
            })
            .map({ [weak self]  call in
                guard let self = self else { return false }
                let show = self.shouldShowCallButton(call: call)
                self.currentCallId.accept(show ? call.callId : "")
                return show
            })
    }()

    let currentCallId = BehaviorRelay<String>(value: "")

    func callIsValid(call: CallModel) -> Bool {
        return call.stateValue == CallState.hold.rawValue ||
            call.stateValue == CallState.unhold.rawValue ||
            call.stateValue == CallState.current.rawValue ||
            call.stateValue == CallState.ringing.rawValue ||
            call.stateValue == CallState.connecting.rawValue
    }

    func shouldShowCallButton(call: CallModel) -> Bool {
        // From iOS 15 picture in picture is supported and it will take care of presenting the video call.
        if #available(iOS 15.0, *) {
            if call.isAudioOnly {
                return true
            }
            return call.stateValue == CallState.ringing.rawValue || call.stateValue == CallState.connecting.rawValue
        }
        return callIsValid(call: call)
    }

    func openCall() {
        guard let call = self.callService
                .call(participantHash: self.conversation.value.getParticipants().first?.jamiId ?? "",
                      accountID: self.conversation.value.accountId) else { return }

        self.stateSubject.onNext(ConversationState.navigateToCall(call: call))
    }

    deinit {
        self.closeAllPlayers()
    }

    func setIsComposingMsg(isComposing: Bool) {
        //        if composingMessage == isComposing {
        //            return
        //        }
        //        composingMessage = isComposing
        //        guard let account = self.accountService.currentAccount else { return }
        //        conversationsService
        //            .setIsComposingMsg(to: self.conversation.value.participantUri,
        //                               from: account.id,
        //                               isComposing: isComposing)
    }

    func addComposingIndicatorMsg() {
        //        if peerComposingMessage {
        //            return
        //        }
        //        peerComposingMessage = true
        //        var messagesValue = self.messages.value
        //        let msgModel = MessageModel(withId: "",
        //                                    receivedDate: Date(),
        //                                    content: "       ",
        //                                    authorURI: self.conversation.value.participantUri,
        //                                    incoming: true)
        //        let composingIndicator = MessageViewModel(withInjectionBag: self.injectionBag, withMessage: msgModel, isLastDisplayed: false)
        //        composingIndicator.isComposingIndicator = true
        //        messagesValue.append(composingIndicator)
        //        self.messages.accept(messagesValue)
    }

    var composingMessage: Bool = false
    // var peerComposingMessage: Bool = false

    func removeComposingIndicatorMsg() {
        //        if !peerComposingMessage {
        //            return
        //        }
        //        peerComposingMessage = false
        //        let messagesValue = self.messages.value
        //        let conversationsMsg = messagesValue.filter { (messageModel) -> Bool in
        //            !messageModel.isComposingIndicator
        //        }
        //        self.messages.accept(conversationsMsg)
    }

    var myContactsLocation = BehaviorSubject<CLLocationCoordinate2D?>(value: nil)
    let shouldDismiss = BehaviorRelay<Bool>(value: false)

    func openFullScreenPreview(parentView: UIViewController, viewModel: PlayerViewModel?, image: UIImage?, initialFrame: CGRect, delegate: PreviewViewControllerDelegate) {
        self.stateSubject.onNext(ConversationState.openFullScreenPreview(parentView: parentView, viewModel: viewModel, image: image, initialFrame: initialFrame, delegate: delegate))
    }

    var conversationCreated = BehaviorRelay(value: true)

    func openInvitationView(parentView: UIViewController) {
        let name = self.displayName.value?.isEmpty ?? true ? self.userName.value : self.displayName.value ?? ""
        let handler: ((String) -> Void) = { [weak self] conversationId in
            guard let self = self else { return }
            guard let conversation = self.conversationsService.getConversationForId(conversationId: conversationId, accountId: self.conversation.value.accountId),
                  !conversationId.isEmpty else {
                self.shouldDismiss.accept(true)
                return
            }
            self.request = nil
            self.conversation.accept(conversation)
            self.conversationCreated.accept(true)
            if self.showInvitation.value {
                self.showInvitation.accept(false)
            }
        }
        if let request = self.request {
            // show incoming request
            self.stateSubject.onNext(ConversationState.openIncomingInvitationView(displayName: name, request: request, parentView: parentView, invitationHandeledCB: handler))
        } else if self.conversation.value.id.isEmpty {
            // send invitation for search result
            let alias = (self.conversation.value.type == .jams ? self.displayName.value : "") ?? ""
            self.stateSubject.onNext(ConversationState
                                        .openOutgoingInvitationView(displayName: name, alias: alias, avatar: self.profileImageData.value,
                                                                    contactJamiId: self.conversation.value.hash,
                                                                    accountId: self.conversation.value.accountId,
                                                                    parentView: parentView,
                                                                    invitationHandeledCB: handler))
        }
    }
}

// MARK: Conversation didSet functions
extension ConversationViewModel {

    private func subscribeProfileServiceMyPhoto() {
        guard let account = self.accountService.currentAccount else { return }
        self.profileService
            .getAccountProfile(accountId: account.id)
            .subscribe(onNext: { [weak self] profile in
                guard let self = self else { return }
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    self.myOwnProfileImageData = data
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribePresenceServiceContactPresence() {
        if !self.conversation.value.isDialog() {
            return
        }
        // subscribe to presence updates for the conversation's associated contact
        if let jamiId = self.conversation.value.getParticipants().first?.jamiId, let contactPresence = self.presenceService.getSubscriptionsForContact(contactId: jamiId) {
            self.contactPresence = contactPresence
        } else {
            self.contactPresence.accept(false)
            self.presenceService
                .sharedResponseStream
                .filter({ [weak self] serviceEvent in
                    guard let uri: String = serviceEvent.getEventInput(ServiceEventInput.uri),
                          let accountID: String = serviceEvent.getEventInput(ServiceEventInput.accountId) else { return false }
                    return uri == self?.conversation.value.getParticipants().first?.jamiId && accountID == self?.conversation.value.accountId
                })
                .subscribe(onNext: { [weak self] _ in
                    self?.subscribePresence()
                })
                .disposed(by: self.disposeBag)
            self.presenceService.subscribeBuddy(withAccountId: self.conversation.value.accountId, withUri: self.conversation.value.getParticipants().first!.jamiId, withFlag: true)
        }
    }

    private func subscribeUnreadMessages() {
        self.conversation.value.numberOfUnreadMessages
            .subscribe { [weak self] unreadMessages in
                guard let self = self else { return }
                self.hideNewMessagesLabel.accept(unreadMessages == 0)
                self.unreadMessages.accept(String(unreadMessages.description))
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func subscribePresence() {
        guard let jamiId = self.conversation.value.getParticipants().first?.jamiId, self.conversation.value.isDialog() else { return }
        if let contactPresence = self.presenceService
            .getSubscriptionsForContact(contactId: jamiId) {
            self.contactPresence = contactPresence
        } else {
            self.contactPresence.accept(false)
        }
    }

    private func subscribeUserServiceLookupStatus() {
        let contact = self.contactsService.contact(withHash: self.conversation.value.getParticipants().first?.jamiId ?? "")

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
                    contact?.userName = name
                } else if let address = lookupNameResponse.address {
                    self?.userName.accept(address)
                }
            })
            .disposed(by: disposeBag)
    }

    private func subscribeConversationServiceTypingIndicator() {
        self.typingIndicator
            .subscribe(onNext: { [weak self] (typing) in
                if typing {
                    self?.addComposingIndicatorMsg()
                } else {
                    self?.removeComposingIndicatorMsg()
                }
            })
            .disposed(by: self.disposeBag)
    }
}

// MARK: Location sharing
extension ConversationViewModel {

    func isAlreadySharingLocation() -> Bool {
        guard let account = self.accountService.currentAccount,
              let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return true }
        return self.locationSharingService.isAlreadySharingMyLocation(accountId: account.id,
                                                                      contactUri: jamiId)
    }

    func startSendingLocation(duration: TimeInterval? = nil) {
        guard let account = self.accountService.currentAccount,
              let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return }
        self.locationSharingService.startSharingLocation(from: account.id,
                                                         to: jamiId,
                                                         duration: duration)
    }

    func stopSendingLocation() {
        guard let account = self.accountService.currentAccount,
              let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return }
        self.locationSharingService.stopSharingLocation(accountId: account.id,
                                                        contactUri: jamiId)
    }

    func model() -> ConversationModel {
        return self.conversation.value
    }
}

// MARK: share message
extension ConversationViewModel {

    private func changeConversationIfNeeded(items: [ConferencableItem]) {
        let contactsURIs = items.map { item -> String? in
            item.contacts.first?.hash
        }
        .compactMap { $0 }
        guard let participant = self.conversation.value.getParticipants().first?.jamiId else { return }
        if contactsURIs.contains(participant) { return }
        guard let selectedItemURI = contactsURIs.first else { return }
        self.stateSubject.onNext(ConversationState.replaceCurrentWithConversationFor(participantUri: selectedItemURI))
    }

    private func shareMessage(message: MessageContentVM, with contact: Contact, fileURL: URL?, fileName: String) {
        if message.type != .fileTransfer {
            self.sendMessage(withContent: message.content, contactURI: contact.uri)
            return
        }
        if let url = fileURL {
            if let jamiId = self.conversation.value.getParticipants().first?.jamiId, contact.hash == jamiId {
                // if contact.hash == self.conversation.value.getParticipants().first!.jamiId {
                self.sendFile(filePath: url.path, displayName: fileName, contactHash: contact.hash)
            } else if let data = FileManager.default.contents(atPath: url.path),
                      let convId = self.conversationsService.getConversationForParticipant(jamiId: contact.hash, accontId: contact.accountID)?.id {
                self.sendAndSaveFile(displayName: fileName, imageData: data, conversationId: convId, accountId: contact.accountID)
            }
            return
        }
    }

    private func shareMessage(message: MessageContentVM, with selectedContacts: [ConferencableItem]) {
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
        self.changeConversationIfNeeded(items: selectedContacts)
    }

    func slectContactsToShareMessage(message: MessageContentVM) {
        guard message.message.type == .text || message.message.type == .fileTransfer else { return }
        self.stateSubject.onNext(ConversationState.showContactPicker(callID: "", contactSelectedCB: {[weak self] (selectedItems) in
            self?.shareMessage(message: message, with: selectedItems)
        }))
    }
}

// MARK: file transfer
extension ConversationViewModel {

    func sendFile(filePath: String, displayName: String, localIdentifier: String? = nil, contactHash: String? = nil) {
        self.dataTransferService.sendFile(conversation: self.conversation.value, filePath: filePath, displayName: displayName, localIdentifier: localIdentifier)
    }

    func sendAndSaveFile(displayName: String, imageData: Data, conversationId: String? = nil, accountId: String? = nil) {
        if let conversationId = conversationId,
           let accountId = accountId,
           let conversation = self.conversationsService.getConversationForId(conversationId: conversationId, accountId: accountId) {
            self.dataTransferService.sendAndSaveFile(displayName: displayName, conversation: conversation, imageData: imageData)
        } else {
            self.dataTransferService.sendAndSaveFile(displayName: displayName, conversation: self.conversation.value, imageData: imageData)
        }
    }
}

extension ConversationViewModel: Equatable {
    static func == (lhs: ConversationViewModel, rhs: ConversationViewModel) -> Bool {
        lhs.conversation.value == rhs.conversation.value
    }
}
