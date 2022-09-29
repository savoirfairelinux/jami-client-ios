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
    @Published var messagesCount = 0
    var lastMessageOnScreen = ""
    var visibleRows: Set = [""]

    let disposeBag = DisposeBag()
    var conversationModel: ConversationViewModel?

    var accountId: String!
    var accountService: AccountsService!
    var profileService: ProfilesService!
    var nameService: NameService!

    var avatars = [String: UIImage]()
    var names = [String: String]()

    // last read
    var lastReadMessageForParticipant = [String: String]() // dictionary of participant id and last read message Id
    var lastRead = [String: [String: UIImage]]() // dictionary of message id and array of participants for whom the message is last read

    var presentPlayerCB: ((_ player: PlayerViewModel) -> Void)?

    init() {}
    init (bag: InjectionBag, convId: String, accountId: String, conversation: ConversationViewModel, presentPlayerCB: @escaping ((_ player: PlayerViewModel) -> Void)) {
        self.loading = true
        self.presentPlayerCB = presentPlayerCB
        self.conversationModel = conversation
        self.accountService = bag.accountService
        self.profileService = bag.profileService
        self.nameService = bag.nameService
        self.accountId = accountId
        for message in conversation.conversation.value.messages {
            insert(message: message, bag: bag, convId: convId)
        }

        self.computeSequencing()
        self.updateLastDisplayed()
        self.lastMessageOnScreen = self.messagesModels.last?.messageId ?? ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.messagesCount = self.messagesModels.count
            self.loading = false
            if self.messagesCount < 5 {
                self.loadMore()
            }
        }
        conversation.conversation.value.newMessages.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] messages in
                guard let self = self else { return }
                var insertionCount = 0
                for newMessage in messages {
                    if self.insert(message: newMessage, bag: bag, convId: convId) {
                        insertionCount += 1
                    }
                }
                if insertionCount == 0 {
                    return
                }
                self.computeSequencing()
                if self.shouldScroll() {
                    if !self.loading {
                        self.lastMessageOnScreen = self.messagesModels.last?.messageId ?? ""
                    }
                    self.messagesCount = self.messagesModels.count
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.loading = false
                }
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)
        bag.conversationsService
            .sharedResponseStream
            .filter({ messageUpdateEvent in
                return messageUpdateEvent.eventType == ServiceEventType.messageStateChanged
            })
            .subscribe(onNext: { [weak self] messageUpdateEvent in
                if let status: MessageStatus = messageUpdateEvent.getEventInput(.messageStatus) {
                    if status == .displayed, let jamiId: String = messageUpdateEvent.getEventInput(.uri),
                       let messageId: String = messageUpdateEvent.getEventInput(.messageId),
                       let localParticipant = self?.conversationModel?.conversation.value.getLocalParticipants(),
                       localParticipant.jamiId != jamiId {
                        var currentid: String?
                        if let current = self?.lastReadMessageForParticipant[jamiId] {
                            currentid = current
                        }
                        self?.lastReadMessageForParticipant[jamiId] = messageId
                        if let model = self?.messagesModels.filter({ message in
                            message.id == messageId
                        }).first, !model.message.incoming {
                            print("@@@@@@@@@@@@updating last read participant \(jamiId)")
                            self?.updateLastRead(messageId: messageId, messageModel: model)
                        }
                        if let currentid = currentid, let message1 = self?.messagesModels.filter({ message2 in
                            message2.id == currentid
                        }).first, !message1.message.incoming {
                            print("@@@@@@@@@@@@updating last read participant \(jamiId)")
                            self?.updateLastRead(messageId: message1.id, messageModel: message1)
                        }
                    }
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func insert(message: MessageModel, bag: InjectionBag, convId: String) -> Bool {
        if self.messagesModels.contains(where: { messageModel in
            messageModel.message.id == message.id
        }) { return false}
        let model = MessageViewModel(withInjectionBag: bag, withMessage: message, isLastDisplayed: false, convId: convId, accountId: accountId)
        model.getAvatar = { [weak self, weak model] jamiId in
            guard let self = self, let model = model else { return }
            if let avatar = self.avatars[jamiId] {
                model.updateAvatar(image: avatar)
            } else {
                self.getInformationForContact(id: jamiId, message: model)
            }
        }
        model.getName = { [weak self, weak model] jamiId in
            guard let self = self, let model = model else { return }
            if let name = self.names[jamiId] {
                model.updateUsername(name: name)
            } else {
                self.getInformationForContact(id: jamiId, message: model)
            }
        }
        model.getlastRead = { [weak self, weak model] messageId in
            guard let self = self, let model = model else { return }
            if let lastReadAvatars = self.lastRead[messageId] {
                let values: [UIImage] = lastReadAvatars.map { value in
                    return value.value
                }
                let newValue = values.isEmpty ? nil : values
                model.updateRead(avatars: newValue)
            } else {
                self.updateLastRead(messageId: messageId, messageModel: model)
            }
        }
        model.player = model.getPlayer(conversationViewModel: self.conversationModel!)
        if let index = self.messagesModels.firstIndex(where: { message in
            message.message.parentId == message.id
        }) {
            if index > 1 {
                self.messagesModels.insert(model, at: index - 1)
            } else {
                self.messagesModels.insert(model, at: 0)
            }
        } else if let parentIndex = self.messagesModels.firstIndex(where: { messageModel in
            messageModel.message.id == message.parentId
        }) {
            if parentIndex > self.messagesModels.count - 1 {
                self.messagesModels.insert(model, at: parentIndex + 1)
            } else {
                self.messagesModels.append(model)
            }
        } else {
            self.messagesModels.insert(model, at: 0)
            conversationModel?.conversation.value.unorderedInteractions.append(message.id)
        }
        return true

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

    func updateLastDisplayed() {
        for participant in self.conversationModel!.conversation.value.getParticipants() {
            lastReadMessageForParticipant[participant.jamiId] = participant.lastDisplayed
        }
    }

    func messagesAddedToScreen(messageId: String) {
        self.visibleRows.insert(messageId)
        if self.messagesModels.first?.id == messageId {
            self.loadMore()
        }
    }
    func messagesremovedFromScreen(messageId: String) {
        if let index = visibleRows.firstIndex(of: messageId) {
            visibleRows.remove(at: index)
        }
    }

    func messageTaped(message: MessageViewModel) {
        if message.message.type == .fileTransfer, let player = message.player, let playerCb = self.presentPlayerCB {
            playerCb(player)
        }
    }

    // MARK: loading

    private func shouldScroll() -> Bool {

        /*
         scroll should be performed in two cases:
         1. when loadin more messages
         2. when a new message received while previous last message for conversation
         was visible on the screen
         */

        if visibleRows.isEmpty || self.loading { return true }

        // check if previous message was visible on screen
        if self.messagesModels.count < 3 {
            return true
        }
        let previousMessage = self.messagesModels[self.messagesModels.count - 2]
        return visibleRows.contains(previousMessage.messageId)
    }

    var loading = false

    private func sortVisibleRows() -> [String] {
        var temporary = [String: Int]()
        for row in visibleRows {
            if row == "" {
                continue
            }
            let index = messagesModels.firstIndex { message in
                message.id == row
            }!
            temporary[row] = index
        }
        let sorted = temporary.sorted { firstRow, secondRow in
            firstRow.value < secondRow.value
        }
        .map { element in
            return element.key
        }
        return sorted
    }

    private func allLoaded() -> Bool {
        guard let firstMessage = self.messagesModels.first else { return false }
        return firstMessage.message.parentId.isEmpty
    }

    private func updateLastVisibleRow() {
        let sortedRows = sortVisibleRows()
        if sortedRows.count > 2 {
            self.lastMessageOnScreen = sortedRows[sortedRows.count - 2]
        } else  if sortedRows.count > 1 {
            self.lastMessageOnScreen = sortedRows[sortedRows.count - 1]
        } else if let lastRow = sortedRows.last {
            self.lastMessageOnScreen = lastRow
        }
    }

    private func loadMore() {
        if self.loading || self.allLoaded() {
            return
        }
        self.updateLastVisibleRow()
        if let conversation = self.conversationModel, let messgId = self.messagesModels.first?.id {
            conversation.loadMoreMessages(messageId: messgId)
            self.loading = true
        }
    }

    // MARK: sequencing

    private func computeSequencing() {
        var lastMessageTime: Date?
        for (index, messageViewModel) in self.messagesModels.enumerated() {
            let currentMessageTime = messageViewModel.receivedDate
            if index == 0 || messageViewModel.bubblePosition() == .generated || messageViewModel.isTransfer {
                // always show first message's time
                messageViewModel.shouldShowTimeString = true
            } else {
                // only show time for new messages if beyond an arbitrary time frame from the previously shown time
                let timeDifference = currentMessageTime.timeIntervalSinceReferenceDate - lastMessageTime!.timeIntervalSinceReferenceDate
                messageViewModel.shouldShowTimeString = Int(timeDifference) < messageGroupingInterval ? false : true
            }
            lastMessageTime = currentMessageTime
        }
        for (index, messageViewModel) in self.messagesModels.enumerated() {
            messageViewModel.sequencing = getMessageSequencing(forIndex: index)
            if messageViewModel.sequencing == .firstOfSequence || messageViewModel.sequencing == .singleMessage {
                messageViewModel.shouldDisplayName = true
            } else {
                messageViewModel.shouldDisplayName = false
            }
        }
    }

    private let messageGroupingInterval = 10 * 60 // 10 minutes

    // swiftlint:disable cyclomatic_complexity
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

    // MARK: participant information

    private func updateName(name: String, id: String, message: MessageViewModel) {
        self.names[id] = name
        message.stackViewModel.username = name
    }

    private func updateAvatar(image: UIImage, id: String, message: MessageViewModel) {
        DispatchQueue.main.async { [weak self, weak message] in
            guard let self = self, let message = message else { return }
            self.avatars[id] = image
            message.updateAvatar(image: image)
            if var lastReadAvatars = self.lastRead[message.id] {
                if var _ = lastReadAvatars[id] {
                    lastReadAvatars[id] = image
                    self.lastRead[message.id] = lastReadAvatars
                    let values: [UIImage] = lastReadAvatars.map { value in
                        return value.value
                    }
                    let newValue = values.isEmpty ? nil : values
                    message.updateRead(avatars: newValue)

                }
            }
        }
    }

    private func nameLookup(id: String, message: MessageViewModel) {
        self.nameService.usernameLookupStatus
            .filter({ lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == id
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self, weak message] lookupNameResponse in
                guard let self = self, let message = message else { return }
                // if we have a registered name then we should update the value for it
                if let name = lookupNameResponse.name, !name.isEmpty {
                    self.updateName(name: name, id: id, message: message)
                } else if self.names[id] == nil {
                    self.updateName(name: id, id: id, message: message)
                }
                if let username = self.names[id] {
                    let image = UIImage.createContactAvatar(username: username)
                    self.updateAvatar(image: image, id: id, message: message)
                }
            })
            .disposed(by: message.disposeBag)
        self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: id)

    }

    private func getInformationForContact(id: String, message: MessageViewModel) {
        guard let account = self.accountService.getAccount(fromAccountId: accountId)   else { return }
        let schema: URIType = account.type == .sip ? .sip : .ring
        guard let contactURI = JamiURI(schema: schema, infoHach: id).uriString else { return }
        self.profileService
            .getProfile(uri: contactURI,
                        createIfNotexists: false,
                        accountId: accountId)
            .subscribe(onNext: { [weak self, weak message] profile in
                guard let self = self, let message = message else { return }
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?,
                   let image = UIImage(data: data) {
                    self.updateAvatar(image: image, id: id, message: message)
                } else if let username = self.names[id], self.avatars[id] == nil {
                    let image = UIImage.createContactAvatar(username: username)
                    self.updateAvatar(image: image, id: id, message: message)
                }
                if let name = profile.alias, !name.isEmpty {
                    self.updateName(name: name, id: id, message: message)
                } else if self.names[id] == nil {
                    self.nameLookup(id: id, message: message)
                }
            })
            .disposed(by: message.disposeBag)
    }

    private func updateLastRead(messageId: String, messageModel: MessageViewModel) {
        let participants = self.lastReadMessageForParticipant.filter { participant in
            return participant.value == messageId
        }
        var images = [String: UIImage]()
        lastRead[messageId] = images
        for participant in participants {
            if let avatar = avatars[participant.key] {
                images[participant.key] = avatar
            } else {
                images[participant.key] = UIImage()
                self.getInformationForContact(id: participant.key, message: messageModel)
            }
        }
        lastRead[messageId] = images
        let values: [UIImage] = images.map { value in
            return value.value
        }
        let newValue = values.isEmpty ? nil : values
        DispatchQueue.main.async { [weak self, weak messageModel] in
            messageModel?.updateRead(avatars: newValue)
        }
    }
}
