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

// swiftlint:disable file_length
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
    private let dataTransferService: DataTransferService
    private let callService: CallsService
    private let locationSharingService: LocationSharingService

    let injectionBag: InjectionBag

    private let disposeBag = DisposeBag()

    private var players = [String: PlayerViewModel]()

    func getPlayer(messageID: String) -> PlayerViewModel? { return players[messageID] }
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
        self.conversation = BehaviorRelay<ConversationModel>(value: conversation)
    }

    convenience init(with injectionBag: InjectionBag, conversation: ConversationModel, user: JamiSearchViewModel.UserSearchModel) {
        self.init(with: injectionBag)
        self.userName.accept(user.username)
        self.displayName.accept(user.firstName + " " + user.lastName)
        self.profileImageData.accept(user.profilePicture)
        self.setConversation(conversation) // required to trigger the didSet
    }

    var request: RequestModel? {
        didSet {
            if request != nil {
                self.showInvitation.accept(true)
            }
        }
    }

    var conversation: BehaviorRelay<ConversationModel>! {
        didSet {
            // Used for location sharing feature
            let showInv = self.conversation.value.needsSyncing || self.request != nil || self.conversation.value.id.isEmpty
            self.showInvitation.accept(showInv)
            self.subscribeLocationServiceLocationReceived()
            self.subscribeProfileServiceMyPhoto()

            guard let account = self.accountService.getAccount(fromAccountId: self.conversation.value.accountId) else { return }
            if account.type == AccountType.sip {
                self.userName.accept(self.conversation.value.hash)
                self.isAccountSip = true
                self.showInvitation.accept(false)
                return
            }
            conversation.value.messages
                .subscribe { [weak self] messages in
                    guard let self = self else { return }
                    // update last message
                    guard let lastMessage = messages.last else { return }
                    self.lastMessage.accept(lastMessage.content)
                    // update last message date
                    let lastMessageDate = lastMessage.receivedDate
                    let dateToday = Date()
                    var dateString = ""

                    // Get components from today date
                    let todayWeekOfYear = Calendar.current.component(.weekOfYear, from: dateToday)
                    let todayDay = Calendar.current.component(.day, from: dateToday)
                    let todayMonth = Calendar.current.component(.month, from: dateToday)
                    let todayYear = Calendar.current.component(.year, from: dateToday)

                    // Get components from last message date
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
                    //
                    self.updateUnreadMessages()
                } onError: { _ in

                }
                .disposed(by: self.disposeBag)

            let filterParicipants = conversation.value.getParticipants()
            if conversation.value.isDialog() {
               if let contact = self.contactsService.contact(withHash: filterParicipants.first?.jamiId ?? "") {
                if let profile = self.contactsService.getProfile(uri: "ring:" + (filterParicipants.first?.jamiId ?? ""), accountId: self.conversation.value.accountId),
                   let alias = profile.alias, let photo = profile.photo {
                    self.displayName.accept(alias)
                    let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? // {
                    self.profileImageData.accept(data)
                }

                self.subscribePresenceServiceContactPresence()
                if let contactUserName = contact.userName {
                    self.userName.accept(contactUserName)
                } else if self.userName.value.isEmpty {
                    self.userName.accept(filterParicipants.first?.jamiId ?? "")

                    self.subscribeUserServiceLookupStatus()
                    self.nameService.lookupAddress(withAccount: self.conversation.value.accountId, nameserver: "", address: filterParicipants.first?.jamiId ?? "")
                }
               } else if self.userName.value.isEmpty {
                self.userName.accept(filterParicipants.first?.jamiId ?? "")

                self.subscribeUserServiceLookupStatus()
                self.nameService.lookupAddress(withAccount: self.conversation.value.accountId, nameserver: "", address: filterParicipants.first?.jamiId ?? "")
            }
            }
            // self.subscribeConversationServiceTypingIndicator()
        }
    }

    private func updateUnreadMessages() {
        let unreadMessages = self.conversation.value.messages.value.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
        self.hideNewMessagesLabel.accept(unreadMessages == 0)
        self.unreadMessages.accept(String(unreadMessages.description))
    }

    // Displays the entire date ( for messages received before the current week )
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    // Displays the hour of the message reception ( for messages received today )
    private lazy var hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var unreadMessagesCount: Int {
        let unreadMessages = self.conversation.value.messages.value.filter({ $0.status != .displayed && $0.type == .text && $0.incoming })
        return unreadMessages.count
    }

    var unreadMessages = BehaviorRelay<String>(value: "")//: String { self.unreadMessagesCount.description }

    var hasUnreadMessages: Bool { unreadMessagesCount > 0 }

    var lastMessage = BehaviorRelay<String>(value: "")// String { self.conversation.value.messages.value.last?.content ?? "" }
    var lastMessageReceivedDate = BehaviorRelay<String>(value: "")

    var hideNewMessagesLabel = BehaviorRelay<Bool>(value: true)//: Bool { self.unreadMessagesCount == 0 }

    var hideDate: Bool { self.conversation.value.messages.value.isEmpty }

    func sendMessage(withContent content: String, contactURI: String? = nil) {
        let conversation = self.conversation.value
        if conversation.type == .nonSwarm {
            // send not swarm message
            guard let participantJamiId = conversation.getParticipants().first?.jamiId,
                  let account = self.accountService.currentAccount else { return }
            // if in call send sip msg
            if let call = self.callService.call(participantHash: participantJamiId, accountID: conversation.accountId) {
                self.callService.sendTextMessage(callID: call.callId, message: content, accountId: account)
                return
            }
            // send non swarm message
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
        // send swarm message
        self.conversationsService.sendSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: content, parentId: "")
    }

    func setMessagesAsRead() {
        guard let account = self.accountService.currentAccount,
              let ringId = AccountModelHelper(withAccount: account).ringId else { return }

        self.conversationsService
            .setMessagesAsRead(forConversation: self.conversation.value,
                               accountId: account.id,
                               accountURI: ringId)
            .subscribe(onCompleted: { [weak self] in
                guard let self = self else { return }
                self.updateUnreadMessages()
                self.log.debug("Messages set as read")
            })
            .disposed(by: disposeBag)
    }

    func setMessageAsRead(daemonId: String, messageId: String) {
        self.conversationsService
            .setMessageAsRead(conversation: self.conversation.value,
                              messageId: messageId,
                              daemonId: daemonId)
        self.updateUnreadMessages()
    }

    func deleteMessage(messageId: String) {
//        guard let account = self.accountService.currentAccount else { return }
//        self.conversationsService
//            .deleteMessage(messagesId: messageId, accountId: account.id)
//            .subscribe(onCompleted: { [weak self] in
//                self?.log.debug("Messages was deleted")
//            })
//            .disposed(by: disposeBag)
//        let message = self.conversation.value.messages.value.filter { $0.messageId == messageId }.first
       // self.conversation.value.messages.value.remove(at: self.conversation.value.messages.value.indexO)
       // message?.removeFile(conversationID: self.conversation.value.conversationId, accountId: account.id)
//        var values = self.messages.value
//        values.removeAll(where: { $0.messageId == messageId })
//        self.messages.accept(values)
    }

    func startCall() {
        guard let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return }
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: jamiId, userName: self.displayName.value ?? self.userName.value))
    }

    func itemLoadedForIndexPath(indexPath: IndexPath) {
        if self.conversation.value.allMessagesLoaded() { return }
        if indexPath.row == 0 {
            self.conversationsService
                .loadConversationMessages(conversationId: self.conversation.value.id,
                                          accountId: self.conversation.value.accountId,
                                          from: self.conversation.value.messages.value.first?.messageId ?? "")
        }
    }

    func startAudioCall() {
        guard let jamiId = self.conversation.value.getParticipants().first?.jamiId else { return }
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: jamiId, userName: self.displayName.value ?? self.userName.value))
    }

    func showContactInfo() {
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.contactDetail(conversationViewModel: self.conversation.value))
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
                let callIsValid = self.callIsValid(call: call)
                self.currentCallId.accept(callIsValid ? call.callId : "")
                return callIsValid
            })
        }()

    let currentCallId = BehaviorRelay<String>(value: "")

    func callIsValid (call: CallModel) -> Bool {
        return call.stateValue == CallState.hold.rawValue ||
            call.stateValue == CallState.unhold.rawValue ||
            call.stateValue == CallState.current.rawValue
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

    func isLastDisplayed(messageId: String) -> Bool {
        return messageId == self.conversation.value.lastDisplayedMessage.id
    }

    var myLocation: Observable<CLLocation?> { return self.locationSharingService.currentLocation.asObservable() }

    var myContactsLocation = BehaviorSubject<CLLocationCoordinate2D?>(value: nil)
}

// MARK: Conversation didSet functions
extension ConversationViewModel {

    private func subscribeLocationServiceLocationReceived() {
//        self.locationSharingService
//            .peerUriAndLocationReceived
//            .subscribe(onNext: { [weak self] tuple in
//                guard let self = self, let peerUri = tuple.0, let conversation = self.conversation else { return }
//                let coordinates = tuple.1
//                if peerUri == conversation.value.participantUri {
//                    self.myContactsLocation.onNext(coordinates)
//                }
//            })
//           .disposed(by: self.disposeBag)
    }

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
        }
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
//        guard let account = self.accountService.currentAccount else { return true }
//        return self.locationSharingService.isAlreadySharing(accountId: account.id,
//                                                            contactUri: self.conversation.value.participantUri)
        return true
    }

    func startSendingLocation(duration: TimeInterval) {
//        if self.conversation.value.messages.isEmpty {
//               self.sendContactRequest()
//        }
//        let contact = self.contactsService.contact(withUri: self.conversation.value.participantUri)
//        if contact == nil {
//            self.sendContactRequest()
//        }
//
//        guard let account = self.accountService.currentAccount else { return }
//        self.locationSharingService.startSharingLocation(from: account.id,
//                                                         to: self.conversation.value.participantUri,
//                                                         duration: duration)
    }

    func stopSendingLocation() {
//        guard let account = self.accountService.currentAccount else { return }
//        self.locationSharingService.stopSharingLocation(accountId: account.id,
//                                                        contactUri: self.conversation.value.participantUri)
    }

    func openFullScreenPreview(parentView: UIViewController, viewModel: PlayerViewModel?, image: UIImage?, initialFrame: CGRect, delegate: PreviewViewControllerDelegate) {
        self.stateSubject.onNext(ConversationState.openFullScreenPreview(parentView: parentView, viewModel: viewModel, image: image, initialFrame: initialFrame, delegate: delegate))
    }

    func openInvitationView(parentView: UIViewController) {
        let name = self.displayName.value?.isEmpty ?? true ? self.userName.value : self.displayName.value ?? ""
        let handler: ((String) -> Void) = { conversationId in
            guard let conversation = self.conversationsService.getConversationForId(conversationId: conversationId, accountId: self.conversation.value.accountId) else { return }
            self.request = nil
            self.conversation.accept(conversation)
            self.showInvitation.accept(false)
        }
        if let request = self.request {
            // show incoming request
            self.stateSubject.onNext(ConversationState.openIncomingInvitationView(displayName: name, request: request, parentView: parentView, invitationHandeledCB: handler))
        } else if self.conversation.value.id.isEmpty {
            // send invitation for search result
            self.stateSubject.onNext(ConversationState
                            .openOutgoingInvitationView(displayName: name,
                                                        contactJamiId: self.conversation.value.hash,
                                                        accountId: self.conversation.value.accountId,
                                                        parentView: parentView,
                                                        invitationHandeledCB: handler))
        }
    }
}

// MARK: share message
extension ConversationViewModel {

    private func changeConversationIfNeeded(items: [ConferencableItem]) {
        let contactsURIs = items.map { item -> String? in
            item.contacts.first?.uri
        }
        .compactMap { $0 }
        if contactsURIs.contains(self.conversation.value.getParticipants().first!.jamiId) { return }
        guard let selectedItemURI = contactsURIs.first else { return }
        self.stateSubject.onNext(ConversationState.replaceCurrentWithConversationFor(participantUri: selectedItemURI))
    }

    private func shareMessage(message: MessageViewModel, with contact: Contact, fileURL: URL?, image: UIImage?, fileName: String) {
        if !message.isTransfer {
            self.sendMessage(withContent: message.content, contactURI: contact.uri)
            return
        }
        if let url = fileURL {
            if contact.hash == self.conversation.value.hash {
                self.sendFile(filePath: url.path, displayName: fileName, contactHash: contact.hash)
            } else if let data = FileManager.default.contents(atPath: url.path),
                      let convId = self.conversationsService.getConversationForParticipant(jamiId: contact.uri, accontId: self.conversation.value.accountId)?.id {
               // self.sendAndSaveFile(displayName: fileName, imageData: data, contactHash: contact.hash, conversation: convId)
            }
            return
        }
        guard let image = image else { return }
        let identifier = message.transferFileData.identifier
        if identifier != nil {
            self.sendImageFromPhotoLibraty(image: image, imageName: fileName, localIdentifier: identifier, contactHash: contact.hash)
            return
        }
        guard let data = image.jpegData(compressionQuality: 100),
              let convId = self.conversationsService.getConversationForParticipant(jamiId: contact.uri, accontId: self.conversation.value.accountId)?.id else { return }
        // self.sendAndSaveFile(displayName: fileName, imageData: data, contactHash: contact.hash, conversation: convId)
    }

    private func shareMessage(message: MessageViewModel, with selectedContacts: [ConferencableItem]) {
        let conversationId = self.conversation.value.id
        let accountId = self.conversation.value.accountId
        // to send file we need to have file url or image
        let url = message.transferedFile(conversationID: conversationId, accountId: accountId)
        let image = url == nil ? message.getTransferedImage(maxSize: 200, conversationID: conversationId, accountId: accountId) : nil
        var fileName = message.content
        if message.content.contains("\n") {
            guard let substring = message.content.split(separator: "\n").first else { return }
            fileName = String(substring)
        }
        selectedContacts.forEach { (item) in
            guard let contact = item.contacts.first else { return }
            self.shareMessage(message: message, with: contact, fileURL: url, image: image, fileName: fileName)
        }
        self.changeConversationIfNeeded(items: selectedContacts)
    }

    func resendMessage(message: MessageViewModel) {
        guard message.message.type == .text || message.message.type == .fileTransfer else { return }
        if message.message.type == .text {
            self.sendMessage(withContent: message.content)
            return
        }
        let conversationId = self.conversation.value.id
        let accountId = self.conversation.value.accountId
        var fileName = message.content
        if message.content.contains("\n") {
            guard let substring = message.content.split(separator: "\n").first else { return }
            fileName = String(substring)
        }
        if let url = message.transferedFile(conversationID: conversationId, accountId: accountId) {
            self.sendFile(filePath: url.path, displayName: fileName, contactHash: self.conversation.value.hash)
            return
        }
        if let image = message.getTransferedImage(maxSize: 200, conversationID: conversationId, accountId: accountId) {
            let identifier = message.transferFileData.identifier
            if identifier != nil {
                self.sendImageFromPhotoLibraty(image: image, imageName: fileName, localIdentifier: identifier, contactHash: self.conversation.value.hash)
                return
            }
            if let data = image.jpegData(compressionQuality: 100) {
//                self.sendAndSaveFile(displayName: fileName, imageData: data, contactHash: self.conversation.value.hash, conversation: self.conversation.value.id)
            }
        }
    }

    func slectContactsToShareMessage(message: MessageViewModel) {
        guard message.message.type == .text || message.message.type == .fileTransfer else { return }
        self.stateSubject.onNext(ConversationState.showContactPicker(callID: "", contactSelectedCB: {[weak self] (selectedItems) in
            self?.shareMessage(message: message, with: selectedItems)
        }))
    }
}

// MARK: file transfer
extension ConversationViewModel {

    func sendFile(filePath: String, displayName: String, localIdentifier: String? = nil, contactHash: String? = nil) {
        guard let accountId = accountService.currentAccount?.id else { return }
        var hash = self.conversation.value.hash
        if let contactHash = contactHash {
            hash = contactHash
        }
        self.dataTransferService.sendFile(filePath: filePath,
                                          displayName: displayName,
                                          accountId: accountId,
                                          peerInfoHash: hash,
                                          localIdentifier: localIdentifier)
    }

    func sendAndSaveFile(displayName: String, imageData: Data, contactHash: String? = nil, conversationId: String? = nil) {
        guard let accountId = accountService.currentAccount?.id else { return }
        var hash = self.conversation.value.hash
        if let contactHash = contactHash {
            hash = contactHash
        }
        self.dataTransferService.sendAndSaveFile(displayName: displayName,
                                                 accountId: accountId,
                                                 peerInfoHash: hash,
                                                 imageData: imageData,
                                                 conversationId: conversationId ?? self.conversation.value.id)
    }

    func sendImageFromPhotoLibraty(image: UIImage, imageName: String, localIdentifier: String?, contactHash: String? = nil) {
        var imageFileName = imageName
        let pathExtension = (imageFileName as NSString).pathExtension
        if pathExtension.caseInsensitiveCompare("heic") == .orderedSame ||
            pathExtension.caseInsensitiveCompare("heif") == .orderedSame ||
            pathExtension.caseInsensitiveCompare("jpg") == .orderedSame ||
            pathExtension.caseInsensitiveCompare("png") == .orderedSame {
            imageFileName = (imageFileName as NSString).deletingPathExtension + ".jpeg"
        }
        guard let localCachePath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(imageFileName) else {
            return
        }
        copyImageToCache(image: image, imagePath: localCachePath.path)
        self.sendFile(filePath: localCachePath.path,
                      displayName: imageFileName,
                      localIdentifier: localIdentifier,
                      contactHash: contactHash)
    }

    private func copyImageToCache(image: UIImage, imagePath: String) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        do {
            try imageData.write(to: URL(fileURLWithPath: imagePath), options: .atomic)
        } catch {
            self.log.error("couldn't copy image to cache")
        }
    }

    func acceptTransfer(transferId: UInt64, interactionID: String, messageContent: inout String) -> NSDataTransferError {
        guard let accountId = accountService.currentAccount?.id else { return .unknown }
        return self.dataTransferService.acceptTransfer(withId: transferId, interactionID: interactionID,
                                                       fileName: &messageContent, accountID: accountId,
                                                       conversationID: self.conversation.value.id)
    }

    func cancelTransfer(transferId: UInt64) -> NSDataTransferError {
        let err = self.dataTransferService.cancelTransfer(withId: transferId)
        if err != .success {
            guard let currentAccount = self.accountService.currentAccount else {
                return err
            }
            let peerInfoHash = ""// conversation.value.participantUri
            self.conversationsService.transferStatusChanged(DataTransferStatus.error, for: transferId, accountId: currentAccount.id, to: peerInfoHash)
        }
        return err
    }

    func getTransferProgress(transferId: UInt64) -> Float? {
        return self.dataTransferService.getTransferProgress(withId: transferId)
    }

    func isTransferImage(transferId: UInt64) -> Bool? {
        guard let account = self.accountService.currentAccount else { return nil }
        return self.dataTransferService.isTransferImage(withId: transferId,
                                                        accountID: account.id,
                                                        conversationID: self.conversation.value.id)
    }

    func getTransferSize(transferId: UInt64) -> Int64? {
        guard let info = self.dataTransferService.getTransferInfo(withId: transferId) else { return nil }
        return info.totalSize
    }
}
