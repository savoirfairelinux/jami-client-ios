//
//  MessagesListModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

class MessagesListModel: ObservableObject {

    @Published var messagesModels = [MessageViewModel]()
    @Published var lastId = ""
    @Published var messagesCount = 0
    @Published var scrollEnabled = true
    let disposeBag = DisposeBag()
    var conversationModel: ConversationViewModel?

    var visibleRows: Set<String> = []

    init (messages: Observable<[MessageModel]>, bag: InjectionBag, convId: String, accountId: String, conversation: ConversationViewModel) {
        self.conversationModel = conversation
        messages
            .observe(on: MainScheduler.instance)
            .subscribe { messages in
                var models = [MessageViewModel]()
                for message in messages {
                    models.append(MessageViewModel(withInjectionBag: bag, withMessage: message, isLastDisplayed: false, convId: convId, accountId: accountId))
                }
                if self.shouldScroll() {
                    if !self.loading {
                        print("*****not loading")
                        self.lastId = models.last?.id ?? ""
                    } else {
                        print("*****loading")
                        self.loading = false
                        // self.scrollEnabled = false
                    }
                    self.messagesCount = models.count
                } else {
                    if self.loading {
                        print("*****loading")
                        self.loading = false
                        // self.scrollEnabled = false
                        //                        self.visibleRows.forEach { row in
                        //                            self.lastId = row
                        //                        }
                        //                        self.messagesCount = models.count
                    }
                }
                self.messagesModels = models
                //                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                //                    self.scrollEnabled = true
                //                }
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)
    }

    init() {

    }

    func messagesAddedToScreen(messageId: String) {
        self.visibleRows.insert(messageId)
        if self.messagesModels.first?.id == messageId {
            self.loadMore()
        }
    }
    func messagesremovedFromScreen(messageId: String) {
        self.visibleRows.remove(messageId)
    }

    func shouldScroll() -> Bool {
        if visibleRows.isEmpty { return true }
        return visibleRows.contains(lastId)
    }

    var loading = false

    var number = 0

    func loadMore() {
        if loading {
            return
        }
        if let conversation = self.conversationModel {
            if conversation.loadMoreMessages() {
                number += 1
                if number > 2 {
                    self.scrollEnabled = false
                }
                print("*****load more messages")
                loading = true
            }
        }

    }
}
