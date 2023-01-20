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
import RxRelay

enum MessageInfo: State {
    case updateAvatar(jamiId: String)
    case updateRead(messageId: String)
    case updateDisplayname(jamiId: String)
}

// swiftlint:disable type_body_length
class MessagesListVM: ObservableObject {

    // view properties
    @Published var messagesModels = [MessageContainerModel]()
    @Published var scrollToId: String?
    @Published var swarmColor = UIColor.defaultSwarmColor {
        didSet {
            self.messagesModels.forEach { message in
                message.swarmColorUpdated(color: swarmColor)
            }
        }
    }
    @Published var atTheBottom = true {
        didSet {
            lastMessageBeforeScroll = atTheBottom ? nil : self.messagesModels.first?.message.id
            if atTheBottom {
                numberOfNewMessages = 0
            }
        }
    }
    @Published var numberOfNewMessages: Int = 0

    var accountService: AccountsService
    var profileService: ProfilesService
    var dataTransferService: DataTransferService
    var conversationService: ConversationsService
    var contactsService: ContactsService
    var nameService: NameService
    var transferHelper: TransferHelper

    // state
    private let contextStateSubject = PublishSubject<State>()
    lazy var contextMenuState: Observable<State> = {
        return self.contextStateSubject.asObservable()
    }()

    var hideNavigationBar = BehaviorRelay(value: false)
    let disposeBag = DisposeBag()
    var messagesDisposeBag = DisposeBag()

    var lastMessageBeforeScroll: String?

    var loading = true // to avoid a new loading while previous one still executing
    var avatars = ConcurentDictionary(name: "com.AvatarsAccesDictionary", dictionary: [String: UIImage]())
    var names = ConcurentDictionary(name: "com.NamesAccesDictionary", dictionary: [String: UIImage]())
    // last read
    // dictionary of participant id and last read message Id
    var lastReadMessageForParticipant = ConcurentDictionary(name: "com.ReadMessageForParticipantAccesDictionary",
                                                            dictionary: [String: String]())
    // dictionary of message id and array of participants for whom the message is last read
    var lastRead = ConcurentDictionary(name: "com.lastReadAccesDictionary",
                                       dictionary: [String: [String: UIImage]]())

    var conversation: ConversationModel {
        didSet {
            messagesDisposeBag = DisposeBag()
            conversation.newMessages.share()
                .startWith(conversation.messages)
                .observe(on: MainScheduler.instance)
                .subscribe { [weak self] messages in
                    guard let self = self else { return }
                    var insertionCount = 0
                    for newMessage in messages where self.insert(newMessage: newMessage) == true {
                        insertionCount += 1
                    }
                    if insertionCount == 0 {
                        return
                    }
                    // load more messages if conversation just opened for first time
                    if self.messagesModels.count < 40 && !self.allLoaded() {
                        if let messageId = self.messagesModels.last?.id {
                            self.conversationService
                                .loadConversationMessages(conversationId: self.conversation.id,
                                                          accountId: self.conversation.accountId,
                                                          from: messageId)
                            return
                        }
                    }
                    self.computeSequencing()
                    self.updateNumberOfNewMessages()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.loading = false
                    }
                } onError: { _ in

                }
                .disposed(by: self.messagesDisposeBag)
            self.updateLastDisplayed()
        }
    }

    init (injectionBag: InjectionBag, conversation: ConversationModel, transferHelper: TransferHelper) {
        defer {
            self.conversation = conversation
            self.subscribeMessagesStatus()
            self.subscribeSwarmPreferences()
            self.updateColorPreference()
        }
        self.conversation = ConversationModel()
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.dataTransferService = injectionBag.dataTransferService
        self.conversationService = injectionBag.conversationsService
        self.contactsService = injectionBag.contactsService
        self.nameService = injectionBag.nameService
        self.transferHelper = transferHelper
    }

    private func insert(newMessage: MessageModel) -> Bool {
        if self.messagesModels.contains(where: { messageModel in
            messageModel.message.id == newMessage.id
        }) { return false }
        let container = MessageContainerModel(message: newMessage, contextMenuState: self.contextStateSubject)
        self.subscribeMessage(container: container)
        // first try to find child
        if let index = self.messagesModels.firstIndex(where: { message in
            message.message.parentId == newMessage.id
        }) {
            if index < self.messagesModels.count - 1 {
                self.messagesModels.insert(container, at: index + 1)
            } else {
                self.messagesModels.append(container)
            }
            // try to find parent
        } else if let parentIndex = self.messagesModels.firstIndex(where: { messageModel in
            messageModel.message.id == newMessage.parentId
        }) {
            if parentIndex > 0 {
                self.messagesModels.insert(container, at: parentIndex - 1)
            } else {
                self.messagesModels.insert(container, at: 0)
            }
        } else {
            if let last = self.messagesModels.last, last.message.parentId.isEmpty {
                self.messagesModels.insert(container, at: 0)
            } else {
                self.messagesModels.append(container)
            }
            conversation.unorderedInteractions.append(newMessage.id)
        }
        /// if a new message is a parent for previously added message change messages order
        if conversation.unorderedInteractions.contains(where: { parentId in
            parentId == newMessage.parentId
        }) {
            moveInteraction(interactionId: newMessage.id, after: newMessage.parentId)
            if let ind = conversation.unorderedInteractions.firstIndex(of: newMessage.parentId) {
                conversation.unorderedInteractions.remove(at: ind)
            }
        }
        container.swarmColorUpdated(color: self.swarmColor)
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
            if index == parentIndex - 1 {
                // alredy on the right place
                return
            }

            let interactionToMove = messagesModels[index]
            let moveToIndex = parentIndex > 0 ? parentIndex - 1 : 0
            if index > 0 {
                // if interaction we are going to move is parent for next interaction we should move next interaction as well
                let childInteraction = messagesModels[index - 1]
                let moveChildInteraction = interactionToMove.id == childInteraction.message.parentId
                messagesModels.insert(messagesModels.remove(at: index), at: moveToIndex)
                if !moveChildInteraction {
                    return
                }
                moveInteraction(interactionId: childInteraction.id, after: interactionToMove.id)
            } else {
                // message we are going to move is last in the first, we do not need to check child interactions
                messagesModels.insert(messagesModels.remove(at: index), at: moveToIndex)
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
                if let avatar = self.avatars.get(key: jamiId) as? UIImage {
                    container.updateAvatar(image: avatar)
                } else {
                    self.getInformationForContact(id: jamiId, message: container)
                }
            case .updateRead(let messageId):
                if let lastReadAvatars = self.lastRead.get(key: messageId) as? [String: UIImage] {
                    let values: [UIImage] = lastReadAvatars.map { value in
                        return value.value
                    }
                    let newValue = values.isEmpty ? nil : values
                    container.updateRead(avatars: newValue)
                } else {
                    self.updateLastRead(messageId: messageId, messageModel: container)
                }
            case .updateDisplayname(let jamiId):
                if let name = self.names.get(key: jamiId) as? String {
                    container.updateUsername(name: name)
                } else {
                    self.getInformationForContact(id: jamiId, message: container)
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
                    viewModel.updateProgress(progress: CGFloat(progress))
                }
            case .getSize(let viewModel):
                if let size = self.transferHelper.getTransferSize(conversation: self.conversation, message: viewModel.message) {
                    viewModel.updateFileSize(size: size)
                }
            case .getURL(let viewModel):
                if viewModel.url != nil { return }
                let url = self.transferHelper.getFileURL(conversation: self.conversation, message: viewModel.message)
                viewModel.updateFileURL(url: url)
            case .getPlayer(let viewModel):
                if viewModel.player != nil { return }
                viewModel.updatePlayer(player: self.transferHelper.getPlayer(conversation: self.conversation, message: viewModel.message))
            }
        } onError: { _ in
        }
        .disposed(by: container.disposeBag)
    }

    private func subscribeSwarmPreferences() {
        self.conversationService
            .sharedResponseStream
            .filter({ [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.conversationPreferencesUpdated &&
                    event.getEventInput(ServiceEventInput.accountId) == self?.conversation.accountId &&
                    event.getEventInput(ServiceEventInput.conversationId) == self?.conversation.id
            })
            .subscribe(onNext: { [weak self] _ in
                self?.updateColorPreference()
            })
            .disposed(by: self.disposeBag)
    }

    private func updateColorPreference() {
        guard let color = UIColor(hexString: self.conversation.preferences.color) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.swarmColor = color
        }
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
                        if let current = self?.lastReadMessageForParticipant.get(key: jamiId) as? String {
                            currentid = current
                        }
                        self?.lastReadMessageForParticipant.set(value: messageId, for: jamiId)
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
            self.lastReadMessageForParticipant.set(value: participant.lastDisplayed, for: participant.jamiId)
        }
    }

    private func allLoaded() -> Bool {
        guard let firstMessage = self.messagesModels.last else { return false }
        return firstMessage.message.parentId.isEmpty
    }

    func loadMore() {
        if self.loading || self.allLoaded() {
            return
        }
        if let messageId = self.messagesModels.last?.id {
            self.conversationService
                .loadConversationMessages(conversationId: self.conversation.id,
                                          accountId: self.conversation.accountId,
                                          from: messageId)
            self.loading = true
        }
    }

    func scrollToTheBottom() {
        self.scrollToId = self.messagesModels.first?.message.id
    }

    private func updateNumberOfNewMessages() {
        guard let lastSeenMessage = self.lastMessageBeforeScroll else { return }
        if let index = self.messagesModels.firstIndex(where: { messageModel in
            messageModel.id == lastSeenMessage
        }) {
            numberOfNewMessages = index
        }
    }

    // MARK: sequencing

    private func computeSequencing() {
        var lastMessageTime: Date?
        for (index, model) in self.messagesModels.enumerated().reversed() {
            let currentMessageTime = model.message.receivedDate
            if index == self.messagesModels.count - 1 {
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
            let shouldDisplayName = (model.sequencing == .firstOfSequence || model.sequencing == .singleMessage) && model.message.incoming
            model.shouldDisplayName = shouldDisplayName
        }
    }

    private let messageGroupingInterval = 10 * 60 // 10 minutes

    private func isBreakingSequence(message: MessageModel, secondMessage: MessageModel) -> Bool {
        return message.uri != secondMessage.uri
            || message.type == .contact || message.type == .initial || message.authorId != secondMessage.authorId
    }

    private func getMessageSequencing(forIndex index: Int) -> MessageSequencing {
        let messageItem = self.messagesModels[index]
        if self.messagesModels.count == 1 || index == self.messagesModels.count - 1 {
            return .singleMessage
        }
        let previousMessageItem = index + 1 < self.messagesModels.count ? self.messagesModels[index + 1] : nil
        let nextMessageItem = index - 1 >= 0 ? self.messagesModels[index - 1] : nil

        if nextMessageItem == nil {
            if let previousMessageItem = previousMessageItem {
                messageItem.followEmogiMessage = previousMessageItem.message.content.isSingleEmoji
                let isNewSequence = messageItem.shouldShowTimeString || self.isBreakingSequence(message: previousMessageItem.message, secondMessage: messageItem.message)
                return isNewSequence ? .singleMessage : .lastOfSequence
            } else {
                return .singleMessage
            }
        }
        if previousMessageItem == nil {
            return .singleMessage
        }
        if let next = nextMessageItem, let previous = previousMessageItem {
            let isNewSequence = messageItem.shouldShowTimeString || self.isBreakingSequence(message: previous.message, secondMessage: messageItem.message)
            let changingSequenceAfter = next.shouldShowTimeString || self.isBreakingSequence(message: next.message, secondMessage: messageItem.message)
            messageItem.followingByEmogiMessage = next.message.content.isSingleEmoji
            messageItem.followEmogiMessage = previous.message.content.isSingleEmoji
            if isNewSequence && changingSequenceAfter {
                return .singleMessage
            }
            if !isNewSequence && changingSequenceAfter {
                return .lastOfSequence
            }
            if isNewSequence && !changingSequenceAfter {
                return .firstOfSequence
            }
            if !isNewSequence && !changingSequenceAfter {
                return .middleOfSequence
            }
        }
        return .singleMessage
    }

    // MARK: participant information

    private func updateName(name: String, id: String, message: MessageContainerModel) {
        self.names.set(value: name, for: id)
        message.updateUsername(name: name)
    }

    private func updateAvatar(image: UIImage, id: String, message: MessageContainerModel) {
        self.avatars.set(value: image, for: id)
        message.updateAvatar(image: image)
        if var lastReadAvatars = self.lastRead.get(key: message.id) as? [String: UIImage] {
            if var _ = lastReadAvatars[id] {
                lastReadAvatars[id] = image
                self.lastRead.set(value: lastReadAvatars, for: message.id)
                let values: [UIImage] = lastReadAvatars.map { value in
                    return value.value
                }
                let newValue = values.isEmpty ? nil : values
                message.updateRead(avatars: newValue)
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
                if let username = self.names.get(key: id) as? String,
                   (self.avatars.get(key: id) as? UIImage) == nil {
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
                } else if let username = self.names.get(key: id) as? String, (self.avatars.get(key: id) as? UIImage) == nil {
                    let image = UIImage.createContactAvatar(username: username, size: CGSize(width: 30, height: 30))
                    self.updateAvatar(image: image, id: id, message: message)
                }
                if let name = profile.alias, !name.isEmpty {
                    self.updateName(name: name, id: id, message: message)
                } else if (self.names.get(key: id) as? String) == nil {
                    self.nameLookup(id: id, message: message)
                }
            })
            .disposed(by: message.disposeBag)
    }

    private func updateLastRead(messageId: String, messageModel: MessageContainerModel) {
        guard let participants = self.lastReadMessageForParticipant.filter({ participant in
            if let id = participant.value as? String {
                return id == messageId
            }
            return false
        }) as? [String: String] else { return }
        var images = [String: UIImage]()
        lastRead.set(value: images, for: messageId)
        for participant in participants {
            if let avatar = self.avatars.get(key: participant.key) as? UIImage {
                images[participant.key] = avatar
            } else {
                images[participant.key] = UIImage()
                self.getInformationForContact(id: participant.key, message: messageModel)
            }
        }
        lastRead.set(value: images, for: messageId)
        let values: [UIImage] = images.map { value in
            return value.value
        }
        let newValue = values.isEmpty ? nil : values
        messageModel.updateRead(avatars: newValue)
    }
}
