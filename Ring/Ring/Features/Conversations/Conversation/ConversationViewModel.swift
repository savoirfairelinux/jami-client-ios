/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
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
                .map({ [unowned self] conversations in
                    return conversations.filter({ conv in
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
                            conversation.messages.map({ [unowned self] message in
                                return MessageViewModel(withInjectionBag: self.injectionBag, withMessage: message)
                            })
                        })
                })
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { messageViewModel in
                    self.messages.value = messageViewModel
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
                .subscribe(onNext: { [unowned self] profile in
                    self.displayName.value = profile.alias
                    if let photo = profile.photo,
                        let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                        self.profileImageData.value = data
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
                .subscribe(onNext: { [unowned self] _ in
                    self.inviteButtonIsAvailable.onNext(false)
                }).disposed(by: self.disposeBag)

            // subscribe to presence updates for the conversation's associated contact
            if let contactPresence = self.presenceService
                .contactPresence[self.conversation.value.hash] {
                self.contactPresence = contactPresence
            } else {
                self.log.warning("Contact presence unknown for: \(contactUri)")
                self.contactPresence.value = false
            }
//            self.presenceService
//                .sharedResponseStream
//                .filter({ presenceUpdateEvent in
//                    return presenceUpdateEvent.eventType == ServiceEventType.presenceUpdated
//                        && presenceUpdateEvent.getEventInput(.uri) == contact?.hash
//                })
//                .subscribe(onNext: { [unowned self] presenceUpdateEvent in
//                    if let uri: String = presenceUpdateEvent.getEventInput(.uri) {
//                        self.contactPresence.value = self.presenceService.contactPresence[uri]!
//                    }
//                })
//                .disposed(by: disposeBag)

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
                    }).subscribe(onNext: { [unowned self] lookupNameResponse in
                        if let name = lookupNameResponse.name, !name.isEmpty {
                            self.userName.value = name
                            contact?.userName = name
                        } else if let address = lookupNameResponse.address {
                            self.userName.value = address
                        }
                    }).disposed(by: disposeBag)

                self.nameService.lookupAddress(withAccount: "", nameserver: "", address: self.conversation.value.hash)
            }
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
        if let call = self.callService.call(participantURI: self.conversation.value.hash, accountID: self.conversation.value.accountId) {
            self.callService.sendTextMessage(callID: call.callId, message: content, accountId: account)
            return
            }


        self.conversationsService
            .sendMessage(withContent: content,
                         from: account,
                         recipientUri: self.conversation.value.participantUri)
            .subscribe(onCompleted: { [unowned self] in
                self.log.debug("Message sent")
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
            .subscribe(onCompleted: { [unowned self] in
                self.log.debug("Messages set as read")
            }).disposed(by: disposeBag)
    }

    fileprivate var unreadMessagesCount: Int {
        let unreadMessages =  self.conversation.value.messages
            .filter({ message in
                return message.status != .read &&
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
            .subscribe(onCompleted: { [unowned self] in
                self.log.info("contact request sent")
                }, onError: { [unowned self] (error) in
                    self.log.info(error)
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
            let discardCompleted = self.contactsService.discard(contactRequest: contactRequest,
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
        let discardCompleted = self.contactsService.discard(contactRequest: item.contactRequest,
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
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: self.conversation.value.hash, userName: self.displayName.value ?? self.userName.value))
    }

    func startAudioCall() {
        if self.conversation.value.messages.isEmpty {
            self.sendContactRequest()
        }
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: self.conversation.value.hash, userName: self.displayName.value ?? self.userName.value))
    }

    func showContactInfo() {
        self.stateSubject.onNext(ConversationState.contactDetail(conversationViewModel: self.conversation.value))
    }

    func recordVideoFile() {
        self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation.value, audioOnly: false))
    }

    func recordAudioFile() {
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

//    lazy var callButtonTitle: Observable<String> = { [unowned self] in
//    return self.callService
//        .currentCall
//        .share()
//        .asObservable()
//        .filter({ (call) -> Bool in
//            call.participantUri == self.conversation.value.participantUri
//        })
//        .map({ call in
//            let callIsValid = self.callIsValid(call: call)
//            let title =  callIsValid ?
//                call.stateValue == CallState.incoming.rawValue ?
//                    L10n.Alerts.incomingCallAllertTitle + "\(call.displayName)" :
//                    L10n.Calls.currentCallWith + "\(call.displayName)" : ""
//            return title
//        })
//    }()
//
//    lazy var showCallButton: Observable<Bool> = { [unowned self] in
//           return self.callService
//               .currentCall
//               .share()
//               .asObservable()
//            .filter({ (call) -> Bool in
//                call.participantUri == self.conversation.value.participantUri
//            })
//               .map({ call in
//                   let callIsValid = self.callIsValid(call: call)
//                   self.currentCallId.value = callIsValid ? call.callId : ""
//                   return callIsValid
//               })
//           }()
//
//       let currentCallId = Variable<String>("")
//
//       func callIsValid (call: CallModel) -> Bool {
//           return call.stateValue == CallState.hold.rawValue ||
//               call.stateValue == CallState.unhold.rawValue ||
//               call.stateValue == CallState.incoming.rawValue ||
//               call.stateValue == CallState.connecting.rawValue ||
//               call.stateValue == CallState.ringing.rawValue ||
//               call.stateValue == CallState.current.rawValue
//       }
       func openCall() {
           guard let call = self.callService
            .call(participantURI: self.conversation.value.hash, accountID:  self.conversation.value.accountId) else {
                   return
           }

           self.stateSubject.onNext(ConversationState.navigateToCall(call: call))
       }
}
