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

    var messagesModels = [MessageViewModel]()
    @Published var lastId = ""
    @Published var messagesCount = 0
    @Published var scrollEnabled = true
    let disposeBag = DisposeBag()
    var conversationModel: ConversationViewModel?

    var visibleRows = [String]()

    init (bag: InjectionBag, convId: String, accountId: String, conversation: ConversationViewModel) {
        self.conversationModel = conversation
        var models = [MessageViewModel]()
        for message in conversation.conversation.value.messages {
            models.append(MessageViewModel(withInjectionBag: bag, withMessage: message, isLastDisplayed: false, convId: convId, accountId: accountId))
            conversation.conversation.value.unorderedInteractions.append(message.id)
        }
        print("*******initial ammount os messges: \(models.count)")
        messagesModels = models
        self.lastId = self.messagesModels.last?.id ?? ""
        print("******* content will update message count: \(models.count)")
        self.messagesCount = self.messagesModels.count
        conversation.conversation.value.newMessages.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe { messages1 in
                self.scrollEnabled = false
                // var models = [MessageViewModel]()
                print("*******new messages received \(messages1.count)")
                messages1.forEach { newMessage in
                    if newMessage.type == .merge { return }
                    /// filter out existing messages
                    if self.messagesModels.contains(where: { message in
                        message.message.id == newMessage.id
                    }) { return }
                    let newModel = MessageViewModel(withInjectionBag: bag, withMessage: newMessage, isLastDisplayed: false, convId: convId, accountId: accountId)
                    /// find child mesage
                    if let index = self.messagesModels.firstIndex(where: { message in
                        message.message.parentId == newMessage.id
                    }) {
                        if index > 1 {
                            self.messagesModels.insert(newModel, at: index - 1)
                        } else {
                            self.messagesModels.insert(newModel, at: 0)
                        }
                    } else if let parentIndex = self.messagesModels.firstIndex(where: { message in
                        message.message.id == newMessage.parentId
                    }) {
                        if parentIndex > self.messagesModels.count - 1 {
                            self.messagesModels.insert(newModel, at: parentIndex + 1)
                        } else {
                            self.messagesModels.append(newModel)
                        }
                    } else {
                        /// no child or parent found. Just add interaction to begining for loaded and to the end for new
                        //                                    if fromLoaded {
                        self.messagesModels.insert(newModel, at: 0)
                        //                                    } else {
                        // self.messagesModels.append(newModel)
                        // }
                        /// save message without parent to dictionary, so if we receive parent later we could move message
                        conversation.conversation.value.unorderedInteractions.append(newMessage.id)
                    }
                    /// if a new message is a parent for previously added message change messages order
                    if conversation.conversation.value.unorderedInteractions.contains(where: { parentId in
                        parentId == newMessage.parentId
                    }) {
                        self.moveInteraction(interactionId: newMessage.id, after: newMessage.parentId)
                        if let ind = conversation.conversation.value.unorderedInteractions.firstIndex(of: newMessage.parentId) {
                            conversation.conversation.value.unorderedInteractions.remove(at: ind)
                        }
                    }
                }
                // self.loading = false
                //                if self.shouldScroll() {
                //                    //                    if !self.loading {
                //                    //                        let fvgr = self.messagesModels.last?.id ?? ""
                //                    //                        print("*******should scroll will but not loaing scroll to \(fvgr)")
                //                    //                        self.lastId = self.messagesModels.last?.id ?? ""
                //                    //                    } else {
                //                    //                        let fvgr = self.visibleRows.last ?? ""
                //                    //                        print("*******self.loading and should scroll will scroll to \(fvgr)")
                //                    //                        self.lastId = self.visibleRows.last ?? ""
                //                    //                    }
                //                    self.messagesCount = self.messagesModels.count
                //                }
                //                else {
                //                    if self.loading {
                //                        let fvgr = self.visibleRows.last ?? ""
                //                        print("*******self.loading will scroll to \(fvgr)")
                //                        self.lastId = self.visibleRows.last ?? ""
                //                        self.messagesCount = self.messagesModels.count
                //
                //                    }
                //                }
                print("*******new messages proceed")
                self.loading = false
                // DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.scrollEnabled = true
                // if self.shouldScroll() {
                self.lastId = self.messagesModels.last?.id ?? ""
                print("*******will scroll to \(self.lastId)")
                //                    if !self.loading {
                //                        let fvgr = self.messagesModels.last?.id ?? ""
                //                        print("*******should scroll will but not loaing scroll to \(fvgr)")
                //                        self.lastId = self.messagesModels.last?.id ?? ""
                //                    } else {
                //                        let fvgr = self.visibleRows.last ?? ""
                //                        print("*******self.loading and should scroll will scroll to \(fvgr)")
                //                        self.lastId = self.visibleRows.last ?? ""
                //                    }
                //                self.messagesCount = self.messagesModels.count
                print("******* content will update message count: \(self.messagesModels.count)")
                self.messagesCount = self.messagesModels.count
                // }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    self.loadMore()
                }
                // self.messagesModels.append(contentsOf: models)
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)
    }

    /**
     move child interaction when found parent interaction
     */
    private func moveInteraction(interactionId: String, after parentId: String) {
        if let index = messagesModels.firstIndex(where: { messge in
            messge.id == interactionId
        }), let parentIndex = messagesModels.firstIndex(where: { messge in
            messge.id == parentId
        }) {
            if index == parentIndex + 1 {
                /// alredy on right place
                return
            }
            if parentIndex < messagesModels.count - 1 {
                let interactionToMove = messagesModels[index]
                if index < messagesModels.count - 1 {
                    /// if interaction we are going to move is parent for next interaction we should move next interaction as well
                    let nextInteraction = messagesModels[index + 1]
                    let moveNextInteraction = interactionToMove.id == nextInteraction.message.parentId
                    messagesModels.insert(messagesModels.remove(at: index), at: parentIndex + 1)
                    if !moveNextInteraction {
                        return
                    }
                    moveInteraction(interactionId: nextInteraction.id, after: interactionToMove.id)
                } else {
                    /// message we are going to move is last in the list, we do not need to check child interactions
                    messagesModels.insert(messagesModels.remove(at: index), at: parentIndex + 1)
                }
            } else if parentIndex == messagesModels.count - 1 {
                let interactionToMove = messagesModels[index]
                let nextInteraction = messagesModels[index + 1]
                let moveNextInteraction = interactionToMove.id == nextInteraction.message.parentId
                messagesModels.append(messagesModels.remove(at: index))
                if !moveNextInteraction {
                    return
                }
                moveInteraction(interactionId: nextInteraction.id, after: interactionToMove.id)
            }
        }
    }

    init (messages: Observable<[MessageModel]>, bag: InjectionBag, convId: String, accountId: String, conversation: ConversationViewModel) {
        self.conversationModel = conversation
        var models = [MessageViewModel]()
        for message in conversation.conversation.value.messages {
            models.append(MessageViewModel(withInjectionBag: bag, withMessage: message, isLastDisplayed: false, convId: convId, accountId: accountId))
        }
        messagesModels = models
        conversation.conversation.value.newMessages
            .observe(on: MainScheduler.instance)
            .subscribe { messages in
                var models = [MessageViewModel]()
                for message in messages {
                    models.append(MessageViewModel(withInjectionBag: bag, withMessage: message, isLastDisplayed: false, convId: convId, accountId: accountId))
                }
                self.messagesModels.append(contentsOf: models)
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)
        //        messages
        //            .observe(on: MainScheduler.instance)
        //            .startWith(conversation.conversation.value.messages.value)
        //            .subscribe { messages in
        //                var models = [MessageViewModel]()
        //                // print("*****update all messages")
        //                for message in messages {
        //                    models.append(MessageViewModel(withInjectionBag: bag, withMessage: message, isLastDisplayed: false, convId: convId, accountId: accountId))
        //                }
        //                if self.shouldScroll() {
        //                    if !self.loading {
        //                        self.lastId = models.last?.id ?? ""
        //                    } else {
        //                        self.lastId = self.visibleRows.last ?? ""
        //                        // self.loading = false
        //                        // self.scrollEnabled = false
        //                    }
        //                    self.messagesCount = models.count
        //                } else {
        //                    if self.loading {
        //                        self.lastId = self.visibleRows.last ?? ""
        //                        self.messagesCount = models.count
        //                        // self.scrollEnabled = false
        //                        //                        self.visibleRows.forEach { row in
        //                        //                            self.lastId = row
        //                        //                        }
        //                        //                        self.messagesCount = models.count
        //                    }
        //                }
        //                print("*******set loading to false")
        //                self.loading = false
        //                self.messagesModels = models
        //                self.computeSequencing()
        //            } onError: { _ in
        //
        //            }
        //            .disposed(by: self.disposeBag)
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
        if messageItem.shouldShowTimeString {
            if index == messagesModels.count - 1 {
                sequencing = .singleMessage
            } else if sequencing != .singleMessage && sequencing != .lastOfSequence {
                sequencing = .firstOfSequence
            } else {
                sequencing = .singleMessage
            }
        }

        if index + 1 < messagesModels.count && messagesModels[index + 1].shouldShowTimeString {
            switch sequencing {
            case .firstOfSequence: sequencing = .singleMessage
            case .middleOfSequence: sequencing = .lastOfSequence
            default: break
            }
        }
        return sequencing
    }

    func messagesAddedToScreen(messageId: String) {
        self.visibleRows.insert(messageId, at: 0)
        print("******messger added to screen \(messageId)")
        //        if self.messagesModels.first?.id == messageId {
        //            print("*******first message load more")
        //            self.loadMore()
        //        }
    }
    func messagesremovedFromScreen(messageId: String) {
        print("******messger removed from to screen \(messageId)")
        self.visibleRows.remove(at: self.visibleRows.firstIndex(of: messageId) ?? self.visibleRows.count)
    }

    var tableSize: CGFloat = 0

    func updateSize(tableSize1: CGFloat) {
        let screen = UIScreen.main.bounds.height
        if screen > tableSize {
            tableSize = 0
        } else {
            self.tableSize = tableSize1 - screen
        }
    }

    func shouldScroll() -> Bool {
        if visibleRows.isEmpty { return true }
        return visibleRows.contains(lastId)
    }

    var loading = false

    var number = 0

    func allLoaded() -> Bool {
        guard let firstMessage = self.messagesModels.first else { return false }
        return firstMessage.message.parentId.isEmpty
    }

    func loadMore() {
        if loading || allLoaded() {
            return
        }
        number += 1
        if number > 4 {
            return}
        // if self.conversationModel?.conversation.value.allMessagesLoaded() { return }
        if let conversation = self.conversationModel {
            let messgId = self.messagesModels.first?.id ?? ""
            if conversation.loadMoreMessages(messageId: messgId) {
                //                number += 1
                //                if number > 2 {
                //                    self.scrollEnabled = false
                //                }
                print("*******start loading more messages from \(messgId)")
                loading = true
            }
        }

    }
}
