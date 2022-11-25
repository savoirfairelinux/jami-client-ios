/*
 *  Copyright (C) 2017-2022 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

import Foundation
import RxSwift

enum MessageInfo: State {
    case updateAvatar(jamiId: String)
    case updateRead(messageId: String)
    case updateDisplayname(jamiId: String)
}

class MessagesListVM: ObservableObject {

    private let contextStateSubject = PublishSubject<State>()
    lazy var contextMenuState: Observable<State> = {
        return self.contextStateSubject.asObservable()
    }()

    let disposeBag = DisposeBag()

    @Published var messagesModels = [MessageContainerModel]()
    @Published var needScroll = false
    var lastMessageOnScreen = ""
    var visibleRows: Set = [""]

    var conversation: ConversationModel

    var accountService: AccountsService
    var profileService: ProfilesService
    var dataTransferService: DataTransferService
    var conversationService: ConversationsService
    var contactsService: ContactsService
    var nameService: NameService

    let infoQueue = DispatchQueue(label: "com.participantDetailsAccess", qos: .background, attributes: .concurrent)
    var avatars = [String: UIImage]()
    var names = [String: String]()

    // last read
    var lastReadMessageForParticipant = [String: String]() // dictionary of participant id and last read message Id
    var lastRead = [String: [String: UIImage]]() // dictionary of message id and array of participants for whom the message is last read

    var transferHelper: TransferHelper

    init (injectionBag: InjectionBag, conversation: ConversationModel, transferHelper: TransferHelper) {
        self.conversation = conversation
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.dataTransferService = injectionBag.dataTransferService
        self.conversationService = injectionBag.conversationsService
        self.contactsService = injectionBag.contactsService
        self.nameService = injectionBag.nameService
        self.transferHelper = transferHelper
        for message in conversation.messages {
            _ = insert(message: message)
        }
        self.computeSequencing()
        self.updateLastDisplayed()
        self.lastMessageOnScreen = self.messagesModels.last?.message.id ?? ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.loading = false
            if self.messagesModels.count < 40 {
                self.loadMore()
            } else {
                self.needScroll = true
            }
        }
        conversation.newMessages.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] messages in
                guard let self = self else { return }
                var insertionCount = 0
                for newMessage in messages where self.insert(message: newMessage) == true {
                    insertionCount += 1
                }
                if insertionCount == 0 {
                    return
                }
                self.computeSequencing()
                if self.shouldScroll() {
                    if !self.loading {
                        self.lastMessageOnScreen = self.messagesModels.last?.message.id ?? ""
                    }
                    self.needScroll = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.loading = false
                }
            } onError: { _ in

            }
            .disposed(by: self.disposeBag)
        self.subscribeMessagesStatus()
    }

    private func insert(message: MessageModel) -> Bool {
        if self.messagesModels.contains(where: { messageModel in
            messageModel.message.id == message.id
        }) { return false}
        let container = MessageContainerModel(message: message, contextMenuState: self.contextStateSubject)
        self.subscribeMessage(container: container)
        if let index = self.messagesModels.firstIndex(where: { message in
            message.message.parentId == message.id
        }) {
            if index > 1 {
                self.messagesModels.insert(container, at: index - 1)
            } else {
                self.messagesModels.insert(container, at: 0)
            }
        } else if let parentIndex = self.messagesModels.firstIndex(where: { messageModel in
            messageModel.message.id == message.parentId
        }) {
            if parentIndex > self.messagesModels.count - 1 {
                self.messagesModels.insert(container, at: parentIndex + 1)
            } else {
                self.messagesModels.append(container)
            }
        } else {
            self.messagesModels.insert(container, at: 0)
            conversation.unorderedInteractions.append(message.id)
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

    // swiftlint:disable cyclomatic_complexity
    private func subscribeMessage(container: MessageContainerModel) {
        if container.message.type == .fileTransfer {
            self.conversationService
                .sharedResponseStream
                .filter({ [weak container] (transferEvent) in
                    guard let container = container,
                          let transferId: String = transferEvent.getEventInput(ServiceEventInput.transferId) else { return false }
                    return  transferEvent.eventType == ServiceEventType.dataTransferMessageUpdated &&
                        container.message.daemonId == transferId
                })
                .subscribe(onNext: { [weak container] transferEvent in
                    guard let container = container,
                          let transferStatus: DataTransferStatus = transferEvent.getEventInput(ServiceEventInput.state) else {
                        return
                    }
                    container.message.transferStatus = transferStatus
                    container.messageContent.setTransferStatus(transferStatus: transferStatus)
                })
                .disposed(by: container.disposeBag)
        }
        container.messageInfoState.subscribe { [weak self, weak container] state in
            guard let self = self, let container = container, let state = state as? MessageInfo else { return }
            switch state {
            case .updateAvatar(let jamiId):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let avatar = self.avatars[jamiId] {
                        container.updateAvatar(image: avatar)
                    } else {
                        self.getInformationForContact(id: jamiId, message: container)
                    }
                }
            case .updateRead(let messageId):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let lastReadAvatars = self.lastRead[messageId] {
                        let values: [UIImage] = lastReadAvatars.map { value in
                            return value.value
                        }
                        let newValue = values.isEmpty ? nil : values
                        container.updateRead(avatars: newValue)
                    } else {
                        self.updateLastRead(messageId: messageId, messageModel: container)
                    }
                }
            case .updateDisplayname(let jamiId):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let name = self.names[jamiId] {
                        container.updateUsername(name: name)
                    } else {
                        self.getInformationForContact(id: jamiId, message: container)
                    }
                }
            }

        } onError: { _ in
        }
        .disposed(by: container.disposeBag)
        container.messageTransferState.subscribe { [weak self] state in
            guard let self = self, let state = state as? TransferState else { return }
            switch state {
            case .accept(let viewModel):
                _ = self.transferHelper.acceptTransfer(conversation: self.conversation, message: viewModel.message)
            case .cancel(let viewModel):
                _ = self.transferHelper.cancelTransfer(conversation: self.conversation, message: viewModel.message)
            case .getProgress(let viewModel):
                if let progress = self.transferHelper.getTransferProgress(conversation: self.conversation, message: viewModel.message) {
                    viewModel.fileProgress = CGFloat(progress)
                }
            case .getSize(let viewModel):
                if let size = self.transferHelper.getTransferSize(conversation: self.conversation, message: viewModel.message) {
                    viewModel.fileSize = size
                }
            case .getImage(let viewModel):
                if viewModel.image != nil { return }
                viewModel.image = self.transferHelper.getTransferedImage(maxSize: 450, conversation: self.conversation, message: viewModel.message)
            case .getURL(let viewModel):
                if viewModel.url != nil { return }
                viewModel.url = self.transferHelper.getFileURL(conversation: self.conversation, message: viewModel.message)
            case .getPlayer(let viewModel):
                if viewModel.player != nil { return }
                viewModel.player = self.transferHelper.getPlayer(conversation: self.conversation, message: viewModel.message)
            }
        } onError: { _ in
        }
        .disposed(by: container.disposeBag)
    }

    // MARK: last read message

    private func subscribeMessagesStatus() {
        self.conversationService
            .sharedResponseStream
            .filter({ messageUpdateEvent in
                return messageUpdateEvent.eventType == ServiceEventType.messageStateChanged
            })
            .subscribe(onNext: { [weak self] messageUpdateEvent in
                if let status: MessageStatus = messageUpdateEvent.getEventInput(.messageStatus) {
                    if status == .displayed, let jamiId: String = messageUpdateEvent.getEventInput(.uri),
                       let messageId: String = messageUpdateEvent.getEventInput(.messageId),
                       let localParticipant = self?.conversation.getLocalParticipants(),
                       localParticipant.jamiId != jamiId {
                        var currentid: String?
                        if let current = self?.lastReadMessageForParticipant[jamiId] {
                            currentid = current
                        }
                        self?.lastReadMessageForParticipant[jamiId] = messageId
                        if let model = self?.messagesModels.filter({ message in
                            message.id == messageId
                        }).first, !model.message.incoming {
                            self?.updateLastRead(messageId: messageId, messageModel: model)
                        }
                        if let currentid = currentid, let message1 = self?.messagesModels.filter({ message2 in
                            message2.id == currentid
                        }).first, !message1.message.incoming {
                            self?.updateLastRead(messageId: message1.id, messageModel: message1)
                        }
                    }
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func updateLastDisplayed() {
        for participant in self.conversation.getParticipants() {
            lastReadMessageForParticipant[participant.jamiId] = participant.lastDisplayed
        }
    }

    // MARK: view actions

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

    // MARK: loading

    func scrollIfNeed() {
        if shouldScroll() {
            self.needScroll = true
        }
    }

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
        return visibleRows.contains(previousMessage.message.id)
    }

    var loading = true

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
        if let messageId = self.messagesModels.first?.id {
            self.conversationService
                .loadConversationMessages(conversationId: self.conversation.id,
                                          accountId: self.conversation.accountId,
                                          from: messageId)
            self.loading = true
        }
    }

    // MARK: sequencing

    private func computeSequencing() {
        var lastMessageTime: Date?
        for (index, model) in self.messagesModels.enumerated() {
            let currentMessageTime = model.message.receivedDate
            if index == 0 || model.message.type != .text {
                // always show first message's time
                model.shouldShowTimeString = true
            } else {
                // only show time for new messages if beyond an arbitrary time frame from the previously shown time
                let timeDifference = currentMessageTime.timeIntervalSinceReferenceDate - lastMessageTime!.timeIntervalSinceReferenceDate
                model.shouldShowTimeString = Int(timeDifference) < messageGroupingInterval ? false : true
            }
            lastMessageTime = currentMessageTime
        }
        for (index, model) in self.messagesModels.enumerated() {
            model.sequencing = getMessageSequencing(forIndex: index)
            if model.sequencing == .firstOfSequence || model.sequencing == .singleMessage {
                model.shouldDisplayName = true
            } else {
                model.shouldDisplayName = false
            }
        }
    }

    private let messageGroupingInterval = 10 * 60 // 10 minutes

    // swiftlint:disable cyclomatic_complexity
    private func getMessageSequencing(forIndex index: Int) -> MessageSequencing {
        let messageItem = self.messagesModels[index]
        let msgOwner = messageItem.message.incoming
        if self.messagesModels.count == 1 || index == 0 {
            if self.messagesModels.count == index + 1 {
                return MessageSequencing.singleMessage
            }
            let nextMessageItem = index + 1 <= self.messagesModels.count
                ? self.messagesModels[index + 1] : nil
            if nextMessageItem != nil {
                return msgOwner != nextMessageItem?.message.incoming
                    ? MessageSequencing.singleMessage : MessageSequencing.firstOfSequence
            }
        } else if self.messagesModels.count == index + 1 {
            let lastMessageItem = index - 1 >= 0 && index - 1 < self.messagesModels.count
                ? self.messagesModels[index - 1] : nil
            if lastMessageItem != nil {
                return msgOwner != lastMessageItem?.message.incoming
                    ? MessageSequencing.singleMessage : MessageSequencing.lastOfSequence
            }
        }
        let lastMessageItem = index - 1 >= 0 && index - 1 < self.messagesModels.count
            ? self.messagesModels[index - 1] : nil
        let nextMessageItem = index + 1 <= self.messagesModels.count
            ? self.messagesModels[index + 1] : nil
        var sequencing = MessageSequencing.singleMessage
        if (lastMessageItem != nil) && (nextMessageItem != nil) {
            if msgOwner != lastMessageItem?.message.incoming && msgOwner == nextMessageItem?.message.incoming {
                sequencing = MessageSequencing.firstOfSequence
            } else if msgOwner != nextMessageItem?.message.incoming && msgOwner == lastMessageItem?.message.incoming {
                sequencing = MessageSequencing.lastOfSequence
            } else if msgOwner == nextMessageItem?.message.incoming && msgOwner == lastMessageItem?.message.incoming {
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

    private func updateName(name: String, id: String, message: MessageContainerModel) {
        DispatchQueue.main.async { [weak self, weak message] in
            guard let self = self, let message = message else { return }
            self.names[id] = name
            message.updateUsername(name: name)
        }
    }

    private func updateAvatar(image: UIImage, id: String, message: MessageContainerModel) {
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

    private func nameLookup(id: String, message: MessageContainerModel) {
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
                } else {
                    self.updateName(name: id, id: id, message: message)
                }
                if let username = self.names[id] {
                    let image = UIImage.createContactAvatar(username: username, size: CGSize(width: 30, height: 30))
                    self.updateAvatar(image: image, id: id, message: message)
                }
            })
            .disposed(by: message.disposeBag)
        self.nameService.lookupAddress(withAccount: self.conversation.accountId, nameserver: "", address: id)
    }

    private func getInformationForContact(id: String, message: MessageContainerModel) {
        guard let account = self.accountService.getAccount(fromAccountId: self.conversation.accountId) else { return }
        if self.contactsService.contact(withHash: id) == nil {
            self.updateName(name: id, id: id, message: message)
            self.nameLookup(id: id, message: message)
            return
        }
        let schema: URIType = account.type == .sip ? .sip : .ring
        guard let contactURI = JamiURI(schema: schema, infoHach: id).uriString else { return }
        self.profileService
            .getProfile(uri: contactURI,
                        createIfNotexists: false,
                        accountId: account.id)
            .subscribe(onNext: { [weak self, weak message] profile in
                guard let self = self, let message = message else { return }
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?,
                   let image = UIImage(data: data) {
                    self.updateAvatar(image: image, id: id, message: message)
                } else if let username = self.names[id], self.avatars[id] == nil {
                    let image = UIImage.createContactAvatar(username: username, size: CGSize(width: 30, height: 30))
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

    private func updateLastRead(messageId: String, messageModel: MessageContainerModel) {
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
        DispatchQueue.main.async { [weak messageModel] in
            messageModel?.updateRead(avatars: newValue)
        }
    }
}
