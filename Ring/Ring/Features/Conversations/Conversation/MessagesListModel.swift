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

    var avatars = [String: UIImage]()
    var names = [String: String]()

    var visibleRows = [String]()
    var accountId: String!
    var accountService: AccountsService!
    var profileService: ProfilesService!
    var nameService: NameService!

    // last read
    var lastReadMessageForParticipant = [String: String]() // dictionary of participant id and last read message Id
    var lastRead = [String: [String: UIImage]]() // dictionary of message id and array of participants for whom the message is last read

    var presentPlayerCB: ((_ player: PlayerViewModel) -> Void)?

    init() {

    }

    init (bag: InjectionBag, convId: String, accountId: String, conversation: ConversationViewModel, presentPlayerCB: @escaping ((_ player: PlayerViewModel) -> Void)) {
        self.presentPlayerCB = presentPlayerCB
        self.conversationModel = conversation
        self.accountService = bag.accountService
        self.profileService = bag.profileService
        self.nameService = bag.nameService
        self.accountId = accountId
        self.updateLastDisplayed()
        conversation.conversation.value.messages.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] messages in
                guard let self = self else { return }
                var models = [MessageViewModel]()
                for message in messages {
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
                        if let lastReadAvatars = self.lastRead[message.id] {
                            let values: [UIImage] = lastReadAvatars.values.map { image in
                                return image
                            }
                            model.updateRead(avatars: values)
                        } else {
                            self.updateLastRead(messageId: messageId, messageModel: model)
                        }
                    }
                    models.append(model)
                    model.player = model.getPlayer(conversationViewModel: self.conversationModel!)
                }
                if self.shouldScroll() {
                    if !self.loading {
                        self.lastId = models.last?.id ?? ""
                    } else {
                        self.lastId = self.visibleRows.last ?? ""
                    }
                    self.messagesCount = models.count
                } else {
                    if self.loading {
                        self.lastId = self.visibleRows.last ?? ""
                        self.messagesCount = models.count
                    }
                }
                self.loading = false
                self.messagesModels = models
                self.computeSequencing()
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)
    }

    func updateLastDisplayed() {
        for participant in self.conversationModel!.conversation.value.getParticipants() {
            lastReadMessageForParticipant[participant.jamiId] = participant.lastDisplayed
        }
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

    func messageTaped(message: MessageViewModel) {
        if message.message.type == .fileTransfer, let player = message.player, let playerCb = self.presentPlayerCB {
            playerCb(player)
        }
    }

    func shouldScroll() -> Bool {
        if visibleRows.isEmpty { return true }
        return visibleRows.contains(lastId)
    }

    var loading = false

    func loadMore() {
        if loading {
            return
        }
        if let conversation = self.conversationModel {
            if conversation.loadMoreMessages() {
                loading = true
            }
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
        self.avatars[id] = image
        message.updateAvatar(image: image)
        if var lastReadAvatars = self.lastRead[message.id] {
            lastReadAvatars[id] = image
            let values: [UIImage] = lastReadAvatars.values.map { image in
                return image
            }
            message.updateRead(avatars: values)
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
                if let username = self.names[id], self.avatars[id] == nil {
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
                self.getInformationForContact(id: participant.key, message: messageModel)
            }

        }
        lastRead[messageId] = images
        let values: [UIImage] = images.values.map { image in
            return image
        }
        messageModel.updateRead(avatars: values)
    }
}
