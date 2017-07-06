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

class ConversationViewModel {

    let conversation: ConversationModel
    let realm = try! Realm()

    //Displays the entire date ( for messages received before the current week )
    private let dateFormatter = DateFormatter()

    //Displays the hour of the message reception ( for messages received today )
    private let hourFormatter = DateFormatter()

    private let disposeBag = DisposeBag()

    let messages :Observable<[MessageViewModel]>

    //Services
    private let conversationsService = AppDelegate.conversationsService
    private let accountService = AppDelegate.accountService
    private let contactsService = AppDelegate.contactsService

    init(withConversation conversation: ConversationModel) {
        self.conversation = conversation

        dateFormatter.dateStyle = .medium
        hourFormatter.dateFormat = "HH:mm"

        //Create observable from sorted conversations and flatMap them to view models
        self.messages = self.conversationsService.conversations.map({ conversations in
            return conversations.filter({ conv in
                return conv.isEqual(conversation)
            }).flatMap({ conversation in
                conversation.messages.map({ message in
                    return MessageViewModel(withMessage: message)
                })
            })
        }).observeOn(MainScheduler.instance)
    }

    lazy var userName: Variable<String> = {

        let contact = self.contactsService.contact(withRingId: self.conversation.recipientRingId,
                                                   account: self.accountService.currentAccount!)

        if let userName = contact?.userName {
            return Variable(userName)
        } else {
            let tmp :Variable<String> = ContactHelper.lookupUserName(forRingId: self.conversation.recipientRingId,
                                                nameService: AppDelegate.nameService,
                                                disposeBag: self.disposeBag)

            tmp.asObservable().subscribe(onNext: { userNameFound in

                //TODO: Fix string "" problem...

                contact?.userName = userNameFound
            }).addDisposableTo(self.disposeBag)

            return tmp
        }
    }()

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
            return NSLocalizedString("Yesterday", tableName: "Smartlist", comment: "")
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
        return self.conversation.messages.count == 0
    }

    func sendMessage(withContent content: String) {
        self.conversationsService
            .sendMessage(withContent: content,
                         from: accountService.currentAccount!,
                         to: self.conversation.recipientRingId)
            .subscribe(onCompleted: {
                let accountHelper = AccountModelHelper(withAccount: self.accountService.currentAccount!)
                self.saveMessage(withContent: content, byAuthor: accountHelper.ringId!, toConversationWith: self.conversation.recipientRingId)
            }).addDisposableTo(disposeBag)
    }

    fileprivate func saveMessage(withContent content: String, byAuthor author: String, toConversationWith account: String) {
        self.conversationsService
            .saveMessage(withContent: content, byAuthor: author, toConversationWith: account, currentAccountId: (accountService.currentAccount?.id)!)
            .subscribe(onCompleted: {
                print("Message saved")
            })
            .addDisposableTo(disposeBag)
    }

    func setMessagesAsRead() {
        self.conversationsService
            .setMessagesAsRead(forConversation: self.conversation)
            .subscribe(onCompleted: {
                print("Message set as read")
            }).addDisposableTo(disposeBag)
    }

    fileprivate var unreadMessagesCount: Int {
        let accountHelper = AccountModelHelper(withAccount: self.accountService.currentAccount!)
        return self.conversation.messages.filter({ message in
            return message.status != .read && message.author != accountHelper.ringId!
        }).count
    }
}
