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

    var visibleRows = [String]()

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
                        self.lastId = self.visibleRows.last ?? ""
                        print("*****loading")
                        // self.loading = false
                        // self.scrollEnabled = false
                    }
                    self.messagesCount = models.count
                } else {
                    if self.loading {
                        print("*****loading")
                        self.lastId = self.visibleRows.last ?? ""
                        self.messagesCount = models.count
                        // self.scrollEnabled = false
                        //                        self.visibleRows.forEach { row in
                        //                            self.lastId = row
                        //                        }
                        //                        self.messagesCount = models.count
                    }
                }
                self.loading = false
                self.messagesModels = models
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)
    }

    init() {

    }

    private func computeSequencing() {
        var lastMessageTime: Date?
        for (index, messageViewModel) in self.messagesModels.enumerated() {
            // time labels
            let currentMessageTime = messageViewModel.receivedDate
            if index == 0 || messageViewModel.bubblePosition() == .generated || messageViewModel.isTransfer {
                // always show first message's time
                messageViewModel.shouldShowTimeString = true
            } else {
                // only show time for new messages if beyond an arbitrary time frame from the previously shown time
                let timeDifference = currentMessageTime.timeIntervalSinceReferenceDate - lastMessageTime!.timeIntervalSinceReferenceDate
                if Int(timeDifference) < messageGroupingInterval || messageViewModel.isComposingIndicator {
                    messageViewModel.shouldShowTimeString = false
                } else {
                    messageViewModel.shouldShowTimeString = true
                }
            }
            lastMessageTime = currentMessageTime
            // sequencing
            print("&&&&&&&&set sequensing: \(messageViewModel.sequencing)")
            messageViewModel.sequencing = getMessageSequencing(forIndex: index)
        }
    }

    private let messageGroupingInterval = 10 * 60 // 10 minutes

    private func getMessageSequencing(forIndex index: Int) -> MessageSequencing {
        let messageItem = self.messagesModels[index]
        let msgOwner = messageItem.bubblePosition()
        if self.messagesModels.count == 1 || index == 0 {
            if self.messagesModels.count == index + 1 {
                return MessageSequencing.singleMessage
            }
            let nextMessageItem = index + 1 <= self.messagesModels.count
                ? self.messagesModels[index + 1] : nil
            if nextMessageItem != nil {
                return msgOwner != nextMessageItem?.bubblePosition()
                    ? MessageSequencing.singleMessage : MessageSequencing.firstOfSequence
            }
        } else if self.messagesModels.count == index + 1 {
            let lastMessageItem = index - 1 >= 0 && index - 1 < self.messagesModels.count
                ? self.messagesModels[index - 1] : nil
            if lastMessageItem != nil {
                return msgOwner != lastMessageItem?.bubblePosition()
                    ? MessageSequencing.singleMessage : MessageSequencing.lastOfSequence
            }
        }
        let lastMessageItem = index - 1 >= 0 && index - 1 < self.messagesModels.count
            ? self.messagesModels[index - 1] : nil
        let nextMessageItem = index + 1 <= self.messagesModels.count
            ? self.messagesModels[index + 1] : nil
        var sequencing = MessageSequencing.singleMessage
        if (lastMessageItem != nil) && (nextMessageItem != nil) {
            if msgOwner != lastMessageItem?.bubblePosition() && msgOwner == nextMessageItem?.bubblePosition() {
                sequencing = MessageSequencing.firstOfSequence
            } else if msgOwner != nextMessageItem?.bubblePosition() && msgOwner == lastMessageItem?.bubblePosition() {
                sequencing = MessageSequencing.lastOfSequence
            } else if msgOwner == nextMessageItem?.bubblePosition() && msgOwner == lastMessageItem?.bubblePosition() {
                sequencing = MessageSequencing.middleOfSequence
            }
        }
        return sequencing
    }

    func messagesAddedToScreen(messageId: String) {
        self.visibleRows.insert(messageId, at: 0)
        if self.messagesModels.first?.id == messageId {
            self.loadMore()
        }
    }
    func messagesremovedFromScreen(messageId: String) {
        self.visibleRows.remove(at: self.visibleRows.firstIndex(of: messageId) ?? self.visibleRows.count)
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
