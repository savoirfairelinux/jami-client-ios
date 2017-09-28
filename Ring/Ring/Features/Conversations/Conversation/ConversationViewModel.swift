/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import RealmSwift
import SwiftyBeaver

class ConversationViewModel: ViewModel {

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
    private let injectionBag: InjectionBag

    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.contactsService = injectionBag.contactsService
        self.presenceService = injectionBag.presenceService

        dateFormatter.dateStyle = .medium
        hourFormatter.dateFormat = "HH:mm"
    }

    var conversation: ConversationModel! {
        didSet {
            //Create observable from sorted conversations and flatMap them to view models
            self.messages = self.conversationsService.conversations.map({ [unowned self] conversations in
                return conversations.filter({ conv in
                    let recipient1 = conv.recipientRingId
                    let recipient2 = self.conversation.recipientRingId
                    if recipient1 == recipient2 {
                        return true
                    }
                    return false
                }).flatMap({ conversation in
                    conversation.messages.map({ [unowned self] message in
                        return MessageViewModel(withInjectionBag: self.injectionBag, withMessage: message)
                    })
                })
            }).observeOn(MainScheduler.instance)

            let contact = self.contactsService.contact(withRingId: self.conversation.recipientRingId)

	    if let contact = contact {
                self.inviteButtonIsAvailable.onNext(!contact.confirmed)
            }
            self.contactsService.contactStatus.subscribe(onNext: { contact in
                self.inviteButtonIsAvailable.onNext(!contact.confirmed)
            }).disposed(by: self.disposeBag)

            // subscribe to presence updates for the conversation's associated contact
            self.presenceService
                .sharedResponseStream
                .filter({ presenceUpdateEvent in
                    return presenceUpdateEvent.eventType == ServiceEventType.presenceUpdated
                        && presenceUpdateEvent.getEventInput(.uri) == contact?.ringId
                })
                .subscribe(onNext: { [unowned self] presenceUpdateEvent in
                    if let uri: String = presenceUpdateEvent.getEventInput(.uri) {
                        self.contactPresence.onNext(self.presenceService.contactPresence[uri]!)
                    }
                })
                .disposed(by: disposeBag)

            if let contactUserName = contact?.userName {
                self.userName.onNext(contactUserName)
            } else {

                let recipientRingId = self.conversation.recipientRingId

                // Return an observer for the username lookup
                self.nameService.usernameLookupStatus
                    .filter({ lookupNameResponse in
                        return lookupNameResponse.address != nil &&
                            lookupNameResponse.address == recipientRingId
                    }).subscribe(onNext: { [unowned self] lookupNameResponse in
                        if let name = lookupNameResponse.name, !name.isEmpty {
                            self.userName.onNext(name)
                            contact?.userName = name
                        } else if let address = lookupNameResponse.address {
                            self.userName.onNext(address)
                        }
                    }).disposed(by: disposeBag)

                self.nameService.lookupAddress(withAccount: "", nameserver: "", address: self.conversation.recipientRingId)
            }
        }
    }

    private lazy var realm: Realm = {
        guard let realm = try? Realm() else {
            fatalError("Enable to instantiate Realm")
        }

        return realm
    }()

    //Displays the entire date ( for messages received before the current week )
    private let dateFormatter = DateFormatter()

    //Displays the hour of the message reception ( for messages received today )
    private let hourFormatter = DateFormatter()

    private let disposeBag = DisposeBag()

    var messages: Observable<[MessageViewModel]>!

    var userName = BehaviorSubject(value: "")

    var inviteButtonIsAvailable = BehaviorSubject(value: true)

    var contactPresence = BehaviorSubject(value: false)

    var unreadMessages: String {
       return self.unreadMessagesCount.description
    }

    var hasUnreadMessages: Bool {
        return unreadMessagesCount > 0
    }

    var lastMessage: String {
        if let lastMessage = conversation.messages.last?.content {
            return lastMessage
        } else {
            return ""
        }
    }

    var lastMessageReceivedDate: String {

        guard let lastMessageDate = self.conversation.messages.last?.receivedDate else {
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
        return self.conversation.messages.isEmpty
    }

    func sendMessage(withContent content: String) {
        self.conversationsService
            .sendMessage(withContent: content,
                         from: accountService.currentAccount!,
                         to: self.conversation.recipientRingId)
            .subscribe(onCompleted: { [unowned self] in
                let accountHelper = AccountModelHelper(withAccount: self.accountService.currentAccount!)
                self.saveMessage(withContent: content, byAuthor: accountHelper.ringId!, toConversationWith: self.conversation.recipientRingId)
            }).disposed(by: self.disposeBag)
    }

    fileprivate func saveMessage(withContent content: String, byAuthor author: String, toConversationWith account: String) {
        self.conversationsService
            .saveMessage(withContent: content, byAuthor: author, toConversationWith: account, currentAccountId: (accountService.currentAccount?.id)!)
            .subscribe(onCompleted: { [unowned self] in
                self.log.debug("Message saved")
            })
            .disposed(by: disposeBag)
    }

    func setMessagesAsRead() {
        self.conversationsService
            .setMessagesAsRead(forConversation: self.conversation)
            .subscribe(onCompleted: { [unowned self] in
                self.log.debug("Message set as read")
            }).disposed(by: disposeBag)
    }

    fileprivate var unreadMessagesCount: Int {
        let accountHelper = AccountModelHelper(withAccount: self.accountService.currentAccount!)
        return self.conversation.messages.filter({ message in
            return message.status != .read && message.author != accountHelper.ringId!
        }).count
    }

    func sendContactRequest() {
        self.accountService.loadVCard(forAccounr: self.accountService.currentAccount!)
            .subscribe(onSuccess: { card in
                self.contactsService.sendContactRequest(toContactRingId: self.conversation.recipientRingId, vCard: card, withAccount: self.accountService.currentAccount!).subscribe(onCompleted: {
                    self.log.info("contact request sent")
                }).disposed(by: self.disposeBag)
            }).disposed(by: self.disposeBag)

    }
}
