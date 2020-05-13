/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import SwiftyBeaver

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class ConversationViewModel: Stateable, ViewModel {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    //Services
    private let conversationsService: ConversationsService
    private let accountService: AccountsService
    private let nameService: NameService
    private let contactsService: ContactsService
    private let presenceService: PresenceService
    private let profileService: ProfilesService
    private let dataTransferService: DataTransferService
    private let callService: CallsService

    private let injectionBag: InjectionBag

    private var players = [String: PlayerViewModel]()

    func getPlayer(messageID: String) -> PlayerViewModel? {
        return players[messageID]
    }

    func setPlayer(messageID: String, player: PlayerViewModel) {
        players[messageID] = player
    }

    func closeAllPlayers() {
        let queue = DispatchQueue.global(qos: .default)
        queue.sync {
            self.players.values.forEach { (player) in
                player.closePlayer()
            }
            self.players.removeAll()
        }
    }

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    lazy var typingIndicator: Observable<Bool> = {
        return self.conversationsService
            .sharedResponseStream
            .filter { [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.messageTypingIndicator &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.conversation.value.accountId &&
                    event.getEventInput(ServiceEventInput.peerUri) == self?.conversation.value.hash
        }.map { (event) -> Bool in
            if let status: Int = event.getEventInput(ServiceEventInput.state), status == 1 {
                return true
            }
            return false
        }
    }()

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

        dateFormatter.dateStyle = .medium
        hourFormatter.dateFormat = "HH:mm"
    }

    var conversation: Variable<ConversationModel>! {
        didSet {
            let contactUri = self.conversation.value.participantUri

            self.conversationsService
                .conversationsForCurrentAccount
                .map({ [weak self] conversations in
                    return conversations.filter({ conv -> Bool in
                        let recipient1 = conv.participantUri
                        let recipient2 = contactUri
                        if recipient1 == recipient2 {
                            return true
                        }
                        return false
                    }).map({ [weak self] conversation -> (ConversationModel) in
                        self?.conversation.value = conversation
                        return conversation
                    })
                        .flatMap({ conversation in
                            conversation.messages.map({ message -> MessageViewModel? in
                                if let injBag = self?.injectionBag {
                                    let lastDisplayed = self?.isLastDisplayed(messageId: message.messageId) ?? false
                                    return MessageViewModel(withInjectionBag: injBag, withMessage: message, isLastDisplayed: lastDisplayed)
                                }
                                return nil
                            })
                        }).filter { (message) -> Bool in
                            message != nil
                    }.map { (message) -> MessageViewModel in
                         return message!
                    }
                })
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] messageViewModels in
                    guard let self = self else {
                        return
                    }
                    var msg = messageViewModels
                    if self
                        .peerComposingMessage {
                        let msgModel = MessageModel(withId: "",
                                                    receivedDate: Date(),
                                                    content: "       ",
                                                    authorURI: self.conversation.value.participantUri,
                                                    incoming: true)
                        let composingIndicator = MessageViewModel(withInjectionBag: self.injectionBag, withMessage: msgModel, isLastDisplayed: false)
                        composingIndicator.isComposingIndicator = true
                        msg.append(composingIndicator)
                    }
                    self.messages.value = msg
                }).disposed(by: self.disposeBag)

            self.contactsService
                .getContactRequestVCard(forContactWithRingId: self.conversation.value.hash)
                .subscribe(onSuccess: { vCard in
                    guard let imageData = vCard.imageData else {
                        self.log.warning("vCard for ringId: \(contactUri) has no image")
                        return
                    }
                    self.profileImageData.value = imageData
                    self.displayName.value = VCardUtils.getName(from: vCard)
                })
                .disposed(by: self.disposeBag)

            self.profileService
                .getProfile(uri: contactUri,
                            createIfNotexists: false,
                            accountId: self.conversation.value.accountId)
                .subscribe(onNext: { [weak self] profile in
                    self?.displayName.value = profile.alias
                    if let photo = profile.photo,
                        let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                        self?.profileImageData.value = data
                    }
                }).disposed(by: disposeBag)

            if let account = self.accountService
                .getAccount(fromAccountId: self.conversation.value.accountId),
                account.type == AccountType.sip {
                    self.userName.value = self.conversation.value.hash
                    self.isAccountSip = true
                    return
            }
            // invite and block buttons
            let contact = self.contactsService.contact(withUri: contactUri)
            if contact != nil {
                self.inviteButtonIsAvailable.onNext(false)
            }

            self.contactsService.contactStatus.filter({ cont in
                return cont.uriString == contactUri
            })
                .subscribe(onNext: { [weak self] _ in
                    self?.inviteButtonIsAvailable.onNext(false)
                }).disposed(by: self.disposeBag)

            // subscribe to presence updates for the conversation's associated contact
            if let contactPresence = self.presenceService
                .contactPresence[self.conversation.value.hash] {
                self.contactPresence = contactPresence
            } else {
                self.log.warning("Contact presence unknown for: \(contactUri)")
                self.contactPresence.value = false
            }

            if let contactUserName = contact?.userName {
                self.userName.value = contactUserName
            } else {
                self.userName.value = self.conversation.value.hash
                // Return an observer for the username lookup
                self.nameService.usernameLookupStatus
                    .filter({ lookupNameResponse in
                        return lookupNameResponse.address != nil &&
                            (lookupNameResponse.address == contactUri ||
                        lookupNameResponse.address == self.conversation.value.hash)
                    }).subscribe(onNext: { [weak self] lookupNameResponse in
                        if let name = lookupNameResponse.name, !name.isEmpty {
                            self?.userName.value = name
                            contact?.userName = name
                        } else if let address = lookupNameResponse.address {
                            self?.userName.value = address
                        }
                    }).disposed(by: disposeBag)

                self.nameService.lookupAddress(withAccount: self.conversation.value.accountId, nameserver: "", address: self.conversation.value.hash)
            }
            self.typingIndicator
                .subscribe(onNext: { [weak self] (typing) in
                if typing {
                    self?.addComposingIndicatorMsg()
                } else {
                    self?.removeComposingIndicatorMsg()
                }
            }).disposed(by: self.disposeBag)
        }
    }

    //Displays the entire date ( for messages received before the current week )
    private let dateFormatter = DateFormatter()

    //Displays the hour of the message reception ( for messages received today )
    private let hourFormatter = DateFormatter()

    private let disposeBag = DisposeBag()

    var messages = Variable([MessageViewModel]())

    var displayName = Variable<String?>(nil)

    var userName = Variable<String>("")

    var isAccountSip: Bool = false

    lazy var bestName: Observable<String> = {
        return Observable
            .combineLatest(userName.asObservable(),
                           displayName.asObservable()) {(userName, displayname) in
                            guard let name = displayname,
                                !name.isEmpty else {
                                    return userName
                            }
                            return name
        }
    }()

    var profileImageData = Variable<Data?>(nil)

    var inviteButtonIsAvailable = BehaviorSubject(value: true)

    var contactPresence = Variable<Bool>(false)

    var unreadMessages: String {
       return self.unreadMessagesCount.description
    }

    var hasUnreadMessages: Bool {
        return unreadMessagesCount > 0
    }

    var lastMessage: String {
        let messages = self.messages.value
        if let lastMessage = messages.last?.content {
            return lastMessage
        } else {
            return ""
        }
    }

    var lastMessageReceivedDate: String {

        guard let lastMessageDate = self.conversation.value.messages.last?.receivedDate else {
            return ""
        }

        let dateToday = Date()

        //Get components from today date
        let todayWeekOfYear = Calendar.current.component(.weekOfYear, from: dateToday)
        let todayDay = Calendar.current.component(.day, from: dateToday)
        let todayMonth = Calendar.current.component(.month, from: dateToday)
        let todayYear = Calendar.current.component(.year, from: dateToday)

        //Get components from last message date
        let weekOfYear = Calendar.current.component(.weekOfYear, from: lastMessageDate)
        let day = Calendar.current.component(.day, from: lastMessageDate)
        let month = Calendar.current.component(.month, from: lastMessageDate)
        let year = Calendar.current.component(.year, from: lastMessageDate)

        if todayDay == day && todayMonth == month && todayYear == year {
            return hourFormatter.string(from: lastMessageDate)
        } else if day == todayDay - 1 {
            return L10n.Smartlist.yesterday
        } else if todayYear == year && todayWeekOfYear == weekOfYear {
            return lastMessageDate.dayOfWeek()
        } else {
            return dateFormatter.string(from: lastMessageDate)
        }
    }

    var hideNewMessagesLabel: Bool {
        return self.unreadMessagesCount == 0
    }

    var hideDate: Bool {
        return self.conversation.value.messages.isEmpty
    }

    func sendMessage(withContent content: String) {
        // send a contact request if this is the first message (implicitly not a contact)
        if self.conversation.value.messages.isEmpty {
            self.sendContactRequest()
        }

        guard let account = self.accountService.currentAccount else {return}
        //if in call send sip msg
        if let call = self.callService.call(participantHash: self.conversation.value.hash, accountID: self.conversation.value.accountId) {
            self.callService.sendTextMessage(callID: call.callId, message: content, accountId: account)
            return
        }
        self.conversationsService
            .sendMessage(withContent: content,
                         from: account,
                         recipientUri: self.conversation.value.participantUri)
            .subscribe(onCompleted: { [weak self] in
                self?.log.debug("Message sent")
            }).disposed(by: self.disposeBag)
    }

    func setMessagesAsRead() {
        guard let account = self.accountService.currentAccount else {
            return
        }
        guard let ringId = AccountModelHelper(withAccount: account).ringId  else {
            return
        }

        self.conversationsService
            .setMessagesAsRead(forConversation: self.conversation.value,
                               accountId: account.id,
                               accountURI: ringId)
            .subscribe(onCompleted: { [weak self] in
                self?.log.debug("Messages set as read")
            }).disposed(by: disposeBag)
    }

    func setMessageAsRead(daemonId: String, messageId: Int64) {
        guard let account = self.accountService.currentAccount else {
            return
        }
        guard let accountURI = AccountModelHelper(withAccount: account).ringId  else {
            return
        }
        self.conversationsService
            .setMessageAsRead(daemonId: daemonId,
                              messageID: messageId,
                              from: self.conversation.value.hash,
                              accountId: account.id,
                              accountURI: accountURI)
        self.conversation.value.messages.filter { (message) -> Bool in
            return message.daemonId == daemonId && message.messageId == messageId
            }.first?.status = .displayed
    }

    fileprivate var unreadMessagesCount: Int {
        let unreadMessages =  self.conversation.value.messages
            .filter({ message in
                return message.status != .displayed &&
                    !message.isTransfer && message.incoming
        })
        return unreadMessages.count
    }

    func sendContactRequest() {
        if let contact = self.contactsService
            .contact(withUri: self.conversation.value.participantUri),
            contact.banned {
            return
        }

        guard let currentAccount = self.accountService.currentAccount else {
            return
        }

        self.contactsService
            .sendContactRequest(toContactRingId: self.conversation.value.hash,
                                withAccount: currentAccount)
            .subscribe(onCompleted: { [weak self] in
                self?.log.info("contact request sent")
                }, onError: { [weak self] (error) in
                    self?.log.info(error)
            }).disposed(by: self.disposeBag)
    }

    func block() {
        let contactRingId = self.conversation.value.hash
        let accountId = self.conversation.value.accountId
        var blockComplete: Observable<Void>
        let removeCompleted = self.contactsService.removeContact(withUri: contactRingId,
                                                                 ban: true,
                                                                 withAccountId: accountId)
        if let contactRequest = self.contactsService.contactRequest(withRingId: contactRingId) {
            let discardCompleted = self.contactsService.discard(from: contactRequest.ringId,
                                                                withAccountId: accountId)
            blockComplete = Observable<Void>.zip(discardCompleted, removeCompleted) { _, _ in
                return
            }
        } else {
            blockComplete = removeCompleted
        }

        blockComplete.asObservable()
            .subscribe(onCompleted: { [weak self] in
                if let conversation = self?.conversation.value {
                    self?.conversationsService
                        .clearHistory(conversation: conversation,
                                      keepConversation: false)
                }
            }).disposed(by: self.disposeBag)
    }

    func ban(withItem item: ContactRequestItem) -> Observable<Void> {
        let accountId = item.contactRequest.accountId
        let discardCompleted = self.contactsService.discard(from: item.contactRequest.ringId,
                                                            withAccountId: accountId)
        let removeCompleted = self.contactsService.removeContact(withUri: item.contactRequest.ringId,
                                                                 ban: true,
                                                                 withAccountId: accountId)
        return Observable<Void>.zip(discardCompleted, removeCompleted) { _, _ in
            return
        }
    }

    func startCall() {
        if self.conversation.value.messages.isEmpty {
            self.sendContactRequest()
        }
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: self.conversation.value.hash, userName: self.displayName.value ?? self.userName.value))
    }

    func startAudioCall() {
        if self.conversation.value.messages.isEmpty {
            self.sendContactRequest()
        }
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: self.conversation.value.hash, userName: self.displayName.value ?? self.userName.value))
    }

    func showContactInfo() {
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.contactDetail(conversationViewModel: self.conversation.value))
    }

    func recordVideoFile() {
        closeAllPlayers()
        self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation.value, audioOnly: false))
    }

    func recordAudioFile() {
        closeAllPlayers()
        self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation.value, audioOnly: true))
    }

    func sendFile(filePath: String, displayName: String, localIdentifier: String? = nil) {
        guard let accountId = accountService.currentAccount?.id else {return}
        self.dataTransferService.sendFile(filePath: filePath,
                                          displayName: displayName,
                                          accountId: accountId,
                                          peerInfoHash: self.conversation.value.hash,
                                          localIdentifier: localIdentifier)
    }

    func sendAndSaveFile(displayName: String, imageData: Data) {
        guard let accountId = accountService.currentAccount?.id else {return}
        self.dataTransferService.sendAndSaveFile(displayName: displayName,
                                                 accountId: accountId,
                                                 peerInfoHash: self.conversation.value.hash,
                                                 imageData: imageData,
                                                 conversationId: self.conversation.value.conversationId)
    }

    func acceptTransfer(transferId: UInt64, interactionID: Int64, messageContent: inout String) -> NSDataTransferError {
        guard let accountId = accountService.currentAccount?.id else {return .unknown}
        return self.dataTransferService.acceptTransfer(withId: transferId, interactionID: interactionID,
                                                       fileName: &messageContent, accountID: accountId,
                                                       conversationID: self.conversation.value.conversationId)
    }

    func cancelTransfer(transferId: UInt64) -> NSDataTransferError {
        let err = self.dataTransferService.cancelTransfer(withId: transferId)
        if err != .success {
            guard let currentAccount = self.accountService.currentAccount else {
                return err
            }
            let peerInfoHash = conversation.value.participantUri
            self.conversationsService.transferStatusChanged(DataTransferStatus.error, for: transferId, accountId: currentAccount.id, to: peerInfoHash)
        }
        return err
    }

    func getTransferProgress(transferId: UInt64) -> Float? {
        return self.dataTransferService.getTransferProgress(withId: transferId)
    }

    func isTransferImage(transferId: UInt64) -> Bool? {
        guard let account = self.accountService.currentAccount else {return nil}
        return self.dataTransferService.isTransferImage(withId: transferId,
                                                        accountID: account.id,
                                                        conversationID: self.conversation.value.conversationId)
    }

    func getTransferSize(transferId: UInt64) -> Int64? {
        guard let info = self.dataTransferService.getTransferInfo(withId: transferId) else { return nil }
        return info.totalSize
    }

    func haveCurrentCall() -> Bool {
        return self.callService.call(participantHash: self.conversation.value.hash, accountID: self.conversation.value.accountId) != nil
    }

    lazy var showCallButton: Observable<Bool> = {
        return self.callService
            .currentCallsEvents
            .share()
            .asObservable()
            .filter({ (call) -> Bool in
                call.paricipantHash() == self.conversation.value.hash
                    && call.accountId == self.conversation.value.accountId
            })
            .map({ call in
                let callIsValid = self.callIsValid(call: call)
                self.currentCallId.value = callIsValid ? call.callId : ""
                return callIsValid
            })
        }()

    let currentCallId = Variable<String>("")

    func callIsValid (call: CallModel) -> Bool {
        return call.stateValue == CallState.hold.rawValue ||
            call.stateValue == CallState.unhold.rawValue ||
            call.stateValue == CallState.current.rawValue
    }

    func openCall() {
        guard let call = self.callService
            .call(participantHash: self.conversation.value.hash,
                  accountID: self.conversation.value.accountId) else { return }

        self.stateSubject.onNext(ConversationState.navigateToCall(call: call))
    }

    deinit {
        self.closeAllPlayers()
    }

    func setIsComposingMsg(isComposing: Bool) {
        if composingMessage == isComposing {
            return
        }
        composingMessage = isComposing
        guard let account = self.accountService.currentAccount else {return}
        conversationsService
            .setIsComposingMsg(to: self.conversation.value.participantUri,
                               from: account.id,
                               isComposing: isComposing)
    }

    func addComposingIndicatorMsg() {
        if peerComposingMessage {
            return
        }
        peerComposingMessage = true
        var messagesValue = self.messages.value
        let msgModel = MessageModel(withId: "",
                                    receivedDate: Date(),
                                    content: "       ",
                                    authorURI: self.conversation.value.participantUri,
                                    incoming: true)
        let composingIndicator = MessageViewModel(withInjectionBag: self.injectionBag, withMessage: msgModel, isLastDisplayed: false)
        composingIndicator.isComposingIndicator = true
        messagesValue.append(composingIndicator)
        self.messages.value = messagesValue
    }

    var composingMessage: Bool = false
    var peerComposingMessage: Bool = false

    func removeComposingIndicatorMsg() {
        if !peerComposingMessage {
            return
        }
        peerComposingMessage = false
        let messagesValue = self.messages.value
        let conversationsMsg = messagesValue.filter { (messageModel) -> Bool in
            !messageModel.isComposingIndicator
        }
        self.messages.value = conversationsMsg
    }

    func isLastDisplayed(messageId: Int64) -> Bool {
        return messageId == self.conversation.value.lastDisplayedMessage.id
    }
}
