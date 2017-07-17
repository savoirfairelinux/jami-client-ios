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

public class ConversationViewModel {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    let conversation: ConversationModel
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

    let messages: Observable<[MessageViewModel]>

    //Services
    private let conversationsService: ConversationsService
    private let accountService: AccountsService
    private let nameService: NameService

    init(withInjectionBag injectionBag: InjectionBag,
         withConversation conversation: ConversationModel) {
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService

        self.conversation = conversation

        dateFormatter.dateStyle = .medium
        hourFormatter.dateFormat = "HH:mm"

        //Create observable from sorted conversations and flatMap them to view models
        self.messages = self.conversationsService.conversations.map({ conversations in
            return conversations.filter({ conv in
                if  let recipient1 = conv.recipient,
                    let recipient2 = conversation.recipient,
                    recipient1.ringId == recipient2.ringId {
                    return true
                }
                return false
            }).flatMap({ conversation in
                conversation.messages.map({ [unowned injectionBag] message in
                    return MessageViewModel(withInjectionBag: injectionBag, withMessage: message)
                })
            })
        }).observeOn(MainScheduler.instance)
    }

    lazy var userName: Variable<String> = {
        if let userName = self.conversation.recipient?.userName {
            return Variable(userName)
        } else {
            let tmp: Variable<String> = ContactHelper.lookupUserName(forRingId: self.conversation.recipient!.ringId,
                                                nameService: self.nameService,
                                                disposeBag: self.disposeBag)

            tmp.asObservable().subscribe(onNext: { [unowned self] userNameFound in

                do {
                    try self.realm.write {
                        self.conversation.recipient?.userName = userNameFound
                    }
                } catch let error {
                    self.log.error("Realm persistence with error: \(error)")
                }

            }).disposed(by: self.disposeBag)

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
            return L10n.Smartlist.yesterday.smartString
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
                         to: self.conversation.recipient!)
            .subscribe(onCompleted: {
                let accountHelper = AccountModelHelper(withAccount: self.accountService.currentAccount!)
                self.saveMessage(withContent: content, byAuthor: accountHelper.ringId!, toConversationWith: (self.conversation.recipient?.ringId)!)
            }).disposed(by: disposeBag)
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
}
