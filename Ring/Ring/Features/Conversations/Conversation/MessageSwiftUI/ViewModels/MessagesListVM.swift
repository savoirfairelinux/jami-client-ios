/*
 *  Copyright (C) 2017-2022 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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
import RxCocoa
import SwiftUI

enum MessageInfo: State {
    case updateAvatar(jamiId: String)
    case updateRead(messageId: String)
    case updateDisplayname(jamiId: String)
}

enum MessagePanelState: State {
    case sendMessage(content: String, parentId: String)
    case editMessage(content: String, messageId: String)
    case sendPhoto
    case openGalery
    case shareLocation
    case recordAudio
    case recordVido
    case sendFile

    func toString() -> String {
        switch self {
        case .sendMessage:
            return "send message"
        case .editMessage:
            return "edit message"
        case .openGalery:
            return L10n.Alerts.uploadPhoto
        case .shareLocation:
            return L10n.Alerts.locationSharing
        case .recordAudio:
            return L10n.Alerts.recordAudioMessage
        case .recordVido:
            return L10n.Alerts.recordVideoMessage
        case .sendFile:
            return L10n.Alerts.uploadFile
        case .sendPhoto:
            return "send photo"
        }
    }

    func imageName() -> String {
        switch self {
        case .openGalery:
            return "photo"
        case .shareLocation:
            return "location"
        case .recordAudio:
            return "mic"
        case .recordVido:
            return "camera"
        case .sendFile:
            return "doc"
        default:
            return ""
        }

    }
}

// swiftlint:disable type_body_length
class MessagesListVM: ObservableObject {

    // view properties
    var contextMenuModel = ContextMenuVM()
    @Published var messagesModels = [MessageContainerModel]()
    @Published var scrollToId: String?
    @Published var scrollToReplyTarget: String? // message id of a reply target that we should scroll
    var temporaryReplyTarget: String? // used to keep a message id of a reply target that we should scroll if this message not loaded yet. ScrollToReplyTarget should be updated after messages loaded
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
                withAnimation { [weak self] in
                    guard let self = self else { return }
                    self.numberOfNewMessages = 0
                }
            }
        }
    }
    @Published var numberOfNewMessages: Int = 0
    @Published var screenTapped: Bool = false
    @Published var shouldShowMap: Bool = false
    @Published var coordinates = [LocationSharingAnnotation]()
    @Published var locationSharingiewModel: LocationSharingViewModel = LocationSharingViewModel()
    var contactAvatar: UIImage = UIImage()
    var currentAccountAvatar: UIImage = UIImage()
    var myContactsLocation: CLLocationCoordinate2D?
    var myCoordinate: CLLocationCoordinate2D?

    var accountService: AccountsService
    var profileService: ProfilesService
    var dataTransferService: DataTransferService
    var locationSharingService: LocationSharingService
    var conversationService: ConversationsService
    var contactsService: ContactsService
    var nameService: NameService
    var transferHelper: TransferHelper
    var messagePanel: MessagePanelVM

    // state
    private let contextStateSubject = PublishSubject<State>()
    lazy var contextMenuState: Observable<State> = {
        return self.contextStateSubject.share()
    }()

    private let messagePanelStateSubject = PublishSubject<State>()
    lazy var messagePanelState: Observable<State> = {
        return self.messagePanelStateSubject.asObservable()
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
    var lastDelivered: MessageContainerModel? {
        didSet {
            if let previous = oldValue {
                // remove sent mark from previous last delivered message
                previous.displayLastSent(state: false)
            }

            if let new = lastDelivered {
                // display sent mark for last delivered message
                new.displayLastSent(state: true)
            }
        }
    }
    var conversation: ConversationModel {
        didSet {
            messagesDisposeBag = DisposeBag()
            conversation.newMessages.share()
                .startWith(LoadedMessages(messages: conversation.messages, fromHistory: true))
                .observe(on: MainScheduler.instance)
                .subscribe { [weak self] messages in
                    guard let self = self else { return }
                    if self.conversation.messages.isEmpty {
                        self.messagesModels = [MessageContainerModel]()
                        return
                    }
                    var insertionCount = 0
                    for newMessage in messages.messages where self.insert(newMessage: newMessage, fromHistory: messages.fromHistory) == true {
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
                        guard let self = self else {return }
                        self.loading = false
                        // check if we have reply target to scroll to.
                        if let tempTarget = self.temporaryReplyTarget,
                           self.getMessage(messageId: tempTarget) != nil {
                            self.scrollToReplyTarget = tempTarget
                            self.temporaryReplyTarget = nil
                        }
                    }
                } onError: { _ in

                }
                .disposed(by: self.messagesDisposeBag)
            self.updateLastDisplayed()
        }
    }

    init (injectionBag: InjectionBag, conversation: ConversationModel, transferHelper: TransferHelper, bestName: Observable<String>, screenTapped: Observable<Bool>) {
        defer {
            self.conversation = conversation
            self.subscribeSwarmPreferences()
            self.updateColorPreference()
            self.subscribeUserAvatarForLocationSharing()
            self.subscribeReplyTarget()
            self.subscribeReactions()
            self.subscribeMessageUpdates()
            self.subscribeMessagesActions()
        }
        self.conversation = ConversationModel()
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.dataTransferService = injectionBag.dataTransferService
        self.conversationService = injectionBag.conversationsService
        self.contactsService = injectionBag.contactsService
        self.nameService = injectionBag.nameService
        self.transferHelper = transferHelper
        self.locationSharingService = injectionBag.locationSharingService
        self.messagePanel = MessagePanelVM(messagePanelState: self.messagePanelStateSubject, bestName: bestName)
        self.subscribeLocationEvents()
        screenTapped
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                self.screenTapped = event
            })
            .disposed(by: self.disposeBag)
    }

    func receiveReply(newMessage: MessageContainerModel, fromHistory: Bool) {
        let replyId = newMessage.message.reply
        if let replyContentTarget = self.getReplyContentTarget(for: replyId) {
            newMessage.replyTarget.target = replyContentTarget
        } else if let message = self.conversation.getMessage(messageId: replyId) {
            newMessage.setReplyTarget(message: message)
        } else {
            self.loadReplyTarget(newMessage: newMessage)
        }
    }

    private func getReplyContentTarget(for replyId: String) -> MessageContentVM? {
        if let replyContent = self.getMessage(messageId: replyId) {
            return replyContent.messageContent
        }
        return nil
    }

    func loadReplyTarget(newMessage: MessageContainerModel) {
        let replyId = newMessage.message.reply
        let result = self.conversationService.loadTargetReply(conversationId: self.conversation.id, accountId: self.conversation.accountId, target: replyId)
        if case .messageFound(let message) = result {
            newMessage.setReplyTarget(message: message)
        }
    }

    func getMessage(messageId: String) -> MessageContainerModel? {
        return self.messagesModels.filter({ messageModel in
            messageModel.message.id == messageId
        }).first
    }

    func targetReplyReceived(target: MessageModel) {
        self.messagesModels.forEach { [weak self, weak target] messageModel in
            guard let self = self, let target = target else { return }
            self.updateTargetReplyIfNeed(target: target, container: messageModel)
        }
    }

    private func updateTargetReplyIfNeed(target: MessageModel,
                                         container: MessageContainerModel) {
        guard container.replyTarget.target == nil,
              container.message.isReply(),
              container.message.reply == target.id else { return }
        container.setReplyTarget(message: target)
    }

    func subscribeLocationEvents() {
        self.locationSharingService
            .peerUriAndLocationReceived
            .subscribe(onNext: { [weak self] tuple in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let coordinates = tuple.1 {
                        self.myContactsLocation = coordinates
                    } else {
                        self.myContactsLocation = nil
                    }
                    self.updateCoordinatesList()
                }
            })
            .disposed(by: self.disposeBag)

        self.locationSharingService.currentLocation
            .subscribe(onNext: { [weak self] myCurrentLocation in
                guard let self = self else { return }
                if let myCurrentLocation = myCurrentLocation {
                    self.myCoordinate = myCurrentLocation.coordinate
                } else {
                    self.myCoordinate = nil
                }
                self.updateCoordinatesList()
            })
            .disposed(by: self.disposeBag)
    }

    func subscribeUserAvatarForLocationSharing() {
        profileService.getAccountProfile(accountId: self.conversation.accountId)
            .subscribe(onNext: { [weak self] profile in
                guard let self = self else { return }
                let account = self.accountService.getAccount(fromAccountId: self.conversation.accountId)
                let defaultAvatar = UIImage.defaultJamiAvatarFor(profileName: profile.alias, account: account, size: 16)
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo,
                                     options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    self.currentAccountAvatar = UIImage(data: data) ?? defaultAvatar
                } else {
                    self.currentAccountAvatar = defaultAvatar
                }
                self.updateCoordinatesList()
            })
            .disposed(by: self.disposeBag)
    }

    func subscribeReplyTarget() {
        self.conversationService.replyTargets
            .subscribe(onNext: { [weak self] targets in
                guard let self = self else { return }
                for target in targets {
                    self.targetReplyReceived(target: target)
                }
            })
            .disposed(by: self.disposeBag)
    }

    func subscribeReactions() {
        self.conversation.reactionsUpdated
            .subscribe(onNext: { [weak self] messageId in
                guard let self = self else { return }
                self.reactionsUpdated(messageId: messageId)
            })
            .disposed(by: self.disposeBag)
        contextMenuModel.currentJamiAccountId = self.accountService.currentAccount?.jamiId
        // setup subscription for emoji picker
        self.contextMenuModel.sendEmojiUpdate
            .subscribe(onNext: { [weak self] event in
                if let self = self, !event.isEmpty {
                    switch event["action"] {
                    case ReactionCommand.apply.toString():
                        if let dat = event["data"], let mId = event["messageId"] {
                            self.conversationService.sendEmojiReactionMessage(conversationId: self.conversation.id, accountId: self.conversation.accountId, message: dat, parentId: mId)
                        }
                    case ReactionCommand.revoke.toString():
                        if let rId = event["reactionId"] {
                            self.conversationService.editSwarmMessage(conversationId: self.conversation.id, accountId: self.conversation.accountId, message: "", parentId: rId)
                        }
                    default: break
                    }
                }
            })
            .disposed(by: self.disposeBag)
    }

    func subscribeMessageUpdates() {
        self.conversation.messageUpdated
            .subscribe(onNext: { [weak self] messageId in
                guard let self = self else { return }
                self.messageUpdated(messageId: messageId)
            })
            .disposed(by: self.disposeBag)
    }

    func messageUpdated(messageId: String) {
        guard let message = self.getMessage(messageId: messageId) else { return }
        self.updateLastRead(message: message)
        self.updateLastDelivered(message: message)
        message.messageUpdated()
        self.computeSequencing()
    }

    func reactionsUpdated(messageId: String) {
        guard let message = self.getMessage(messageId: messageId) else { return }
        message.reactionsUpdated()
    }

    func scrolledToTargetReply() {
        guard let messageId = self.scrollToReplyTarget else { return }
        let message = self.getMessage(messageId: messageId)
        self.scrollToReplyTarget = nil
        if let message = message {
            message.startTargetReplyAnimation()
        }
    }

    private func updateCoordinatesList() {
        var coordinates = [LocationSharingAnnotation]()
        if let myContactsLocation = self.myContactsLocation {
            coordinates.append(LocationSharingAnnotation(coordinate: myContactsLocation, avatar: self.contactAvatar))
        }
        if let myLocation = self.myCoordinate {
            coordinates.append(LocationSharingAnnotation(coordinate: myLocation, avatar: self.currentAccountAvatar))
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.coordinates = coordinates
            self.shouldShowMap = self.isAlreadySharingLocation() && !coordinates.isEmpty
        }
    }

    private func insert(newMessage: MessageModel, fromHistory: Bool) -> Bool {
        guard let localJamiId = self.accountService.getAccount(fromAccountId: self.conversation.accountId)?.jamiId else {
            return false
        }
        if self.messagesModels.contains(where: { messageModel in
            messageModel.message.id == newMessage.id
        }) { return false }
        let isHistory = newMessage.isReply()
        let container = MessageContainerModel(message: newMessage, contextMenuState: self.contextStateSubject, isHistory: isHistory, localJamiId: localJamiId, preferencesColor: self.conversation.preferences.getColor())
        self.subscribeMessage(container: container)
        if fromHistory {
            self.messagesModels.append(container)
        } else {
            self.messagesModels.insert(container, at: 0)
        }
        self.updateLastRead(message: container)
        self.updateLastDelivered(message: container)
        if newMessage.isReply() {
            self.receiveReply(newMessage: container, fromHistory: fromHistory)
        }
        return true
    }

    func updateLastDelivered(message: MessageContainerModel) {
        guard message.message.isDelivered() else { return }
        /*
         Update 'lastDelivered' with this message if no previous 'lastDelivered' exists,
         or if this message precedes the current 'lastDelivered' in the messages list.
         */
        if let lastDelivered = self.lastDelivered {
            guard let index = self.messagesModels.firstIndex(where: { $0.id == message.id}),
                  let lastDelivered = self.lastDelivered,
                  let lastDeliveredIndex = self.messagesModels.firstIndex(where: { $0.id == lastDelivered.id }),
                  index < lastDeliveredIndex else { return }
            self.lastDelivered = message
        } else {
            self.lastDelivered = message
        }
    }

    private func updateLastRead(message: MessageContainerModel, participantId: String) {
        guard !message.message.incoming, message.message.status == .displayed else { return }
        /*
         If there is no current last read message for the participant, set this
         message as the last read. Otherwise, check if the new message appears
         later in the messages list than the previous last displayed message
         and update it accordingly.
         */
        if self.lastReadMessageForParticipant.get(key: participantId) == nil {
            setLastRead(message: message, participantId: participantId)
        } else if let currentLastReadMessageId = self.lastReadMessageForParticipant.get(key: participantId) as? String,
                  let currentIndex = self.messagesModels.firstIndex(where: { $0.id == currentLastReadMessageId }),
                  let newIndex = self.messagesModels.firstIndex(where: { $0.id == message.id }), newIndex < currentIndex,
                  let currentRead = self.getMessage(messageId: currentLastReadMessageId) {
            self.setLastRead(message: message, participantId: participantId)
            self.updateLastReadAvatars(messageId: currentLastReadMessageId, messageModel: currentRead)
        }
    }

    private func updateLastRead(message: MessageContainerModel) {
        for status in message.message.statusForParticipant {
            updateLastRead(message: message, participantId: status.key)
        }
    }

    private func setLastRead(message: MessageContainerModel, participantId: String) {
        self.lastReadMessageForParticipant.set(value: message.id, for: participantId)
        self.updateLastReadAvatars(messageId: message.id, messageModel: message)
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
                self.getAvatar(jamiId: jamiId, message: container)
            case .updateRead(let messageId):
                if let lastReadAvatars = self.lastRead.get(key: messageId) as? [String: UIImage] {
                    let values: [UIImage] = lastReadAvatars.map { value in
                        return value.value
                    }
                    let newValue = values.isEmpty ? nil : values
                    container.updateRead(avatars: newValue)
                } else {
                    self.updateLastReadAvatars(messageId: messageId, messageModel: container)
                }
            case .updateDisplayname(let jamiId):
                if let name = self.names.get(key: jamiId) as? String {
                    container.updateUsername(name: name, jamiId: jamiId)
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

    private func subscribeMessagesActions() {
        self.contextMenuState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ContextMenu else { return }
                switch state {
                case .reply(message: let message):
                    self.configureReply(message: message)
                case .delete(message: let message):
                    self.deleteMessage(message: message)
                case .edit(message: let message):
                    self.configureEdit(message: message)
                case .scrollToReplyTarget(messageId: let messageId):
                    self.scrollToTargetReply(messageId: messageId)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func updateColorPreference() {
        guard let color = UIColor(hexString: self.conversation.preferences.color) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.swarmColor = color
        }
    }

    func configureReply(message: MessageContentVM) {
        self.messagePanel.configureReplyTo(message: message)
        self.updateUsernameForReply(message: message)
    }

    func scrollToTargetReply(messageId: String) {
        /*
         If the required message is already loaded, simply scroll to it;
         otherwise,load conversation until the required message.
         */
        if self.getMessage(messageId: messageId) != nil {
            self.scrollToReplyTarget = messageId
        } else if let from = self.messagesModels.last?.id {
            self.temporaryReplyTarget = messageId
            self.conversationService.loadMessagesUntil(messageId: messageId, conversationId: self.conversation.id, accountId: self.conversation.accountId, from: from)
            self.loading = true
        }
    }

    func configureEdit(message: MessageContentVM) {
        self.messagePanel.configureEdit(message: message)
    }

    func deleteMessage(message: MessageContentVM) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak message] in
            guard let self = self, let message = message else { return }
            guard let container = self.getMessage(messageId: message.message.id) else { return }
            if container.message.type == .text {
                self.conversationService.editSwarmMessage(conversationId: self.conversation.id, accountId: self.conversation.accountId, message: "", parentId: message.message.id)
            }
        }
    }

    func updateUsernameForReply(message: MessageContentVM) {
        guard let localJamiId = self.accountService.getAccount(fromAccountId: self.conversation.accountId)?.jamiId else {
            return
        }
        let jamiId = message.message.authorId
        if localJamiId == jamiId || jamiId.isEmpty {
            self.messagePanel.updateUsername(name: L10n.Conversation.yourself, jamiId: jamiId)
            return
        }
        if let name = self.names.get(key: jamiId) as? String {
            self.messagePanel.updateUsername(name: name, jamiId: jamiId)
        } else if let container = self.getMessage(messageId: jamiId) {
            self.getInformationForContact(id: jamiId, message: container)
        }
    }

    // MARK: last read message

    private func updateLastDisplayed() {
        for participant in self.conversation.getParticipants() {
            self.lastReadMessageForParticipant.set(value: participant.lastDisplayed, for: participant.jamiId)
        }
    }

    private func allLoaded() -> Bool {
        guard let firstMessage = self.messagesModels.last else { return false }
        return firstMessage.message.parentId.isEmpty && firstMessage.message.parents.isEmpty
    }

    func loadMore() {
        if self.loading || allLoaded() {
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
            withAnimation { [weak self] in
                guard let self = self else { return }
                self.numberOfNewMessages = index
            }
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
            model.shouldDisplayContactInfo = shouldDisplayContactInfo(message: model) && shouldDisplayContactInfoForConversation()
            model.shouldDisplayContactInfoForConversation = shouldDisplayContactInfoForConversation()
        }
    }

    private let messageGroupingInterval = 10 * 60 // 10 minutes

    private func isBreakingSequence(message: MessageModel, secondMessage: MessageModel) -> Bool {
        let differentUri = message.uri != secondMessage.uri
        let messageTypeCheck = message.type == .contact || message.type == .initial
        let differentAuthor = message.authorId != secondMessage.authorId
        let isReplyCheck = message.isReply() || secondMessage.isReply()
        let hasReactions = !message.reactions.isEmpty || !secondMessage.reactions.isEmpty

        return differentUri || messageTypeCheck || differentAuthor ||
            isReplyCheck || hasReactions
    }

    private func shouldDisplayContactInfo(message: MessageContainerModel) -> Bool {
        return (message.sequencing == .firstOfSequence || message.sequencing == .singleMessage) && message.message.incoming && !message.message.isReply()
    }

    private func shouldDisplayContactInfoForConversation() -> Bool {
        // do not show names for one to one conversation
        return self.conversation.getParticipants().count > 1
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
        message.updateUsername(name: name, jamiId: id)
        self.messagePanel.updateUsername(name: name, jamiId: id)
    }

    private func updateAvatar(image: UIImage, id: String, message: MessageContainerModel) {
        self.avatars.set(value: image, for: id)
        self.updateContacLocationSharingImage()
        message.updateAvatar(image: image, jamiId: id)
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
            .disposed(by: disposeBag)
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
        guard let contactURI = JamiURI(schema: schema, infoHash: id).uriString else { return }
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

    private func getAvatar(jamiId: String, message: MessageContainerModel) {
        // check if we already have the avatar for a contact
        if let avatar = self.avatars.get(key: jamiId) as? UIImage {
            message.updateAvatar(image: avatar, jamiId: jamiId)
            // check if we need avatar for local account
        } else if let accountJamiId = self.accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId, accountJamiId == jamiId {
            message.updateAvatar(image: self.currentAccountAvatar, jamiId: jamiId)
        } else {
            self.getInformationForContact(id: jamiId, message: message)
        }
    }

    private func updateLastReadAvatars(messageId: String, messageModel: MessageContainerModel) {
        guard let participants = self.lastReadMessageForParticipant.filter({ participant in
            if let id = participant.value as? String {
                return id == messageId
            }
            return false
        }) as? [String: String] else { return }
        var images = [String: UIImage]()
        lastRead.set(value: images, for: messageId)
        var contacts = [String]()
        for participant in participants {
            if let avatar = self.avatars.get(key: participant.key) as? UIImage {
                images[participant.key] = avatar
            } else {
                images[participant.key] = UIImage()
                contacts.append(participant.key)
            }
        }
        lastRead.set(value: images, for: messageId)
        let values: [UIImage] = images.map { value in
            return value.value
        }
        let newValue = values.isEmpty ? nil : values
        messageModel.updateRead(avatars: newValue)
        for contact in contacts {
            self.getInformationForContact(id: contact, message: messageModel)
        }
    }
}

// MARK: Location sharing
extension MessagesListVM {

    func updateContacLocationSharingImage() {
        if let jamiId = self.conversation.getParticipants().first?.jamiId {
            if let avatar = self.avatars.get(key: jamiId) as? UIImage {
                DispatchQueue.main.async { [weak self] in
                    self?.contactAvatar = avatar
                    self?.updateCoordinatesList()
                }
            }
        }
    }

    func isAlreadySharingLocation() -> Bool {
        return peerIsAlreadySharingLocation() || self.isAlreadySharingMyLocation()
    }

    func peerIsAlreadySharingLocation() -> Bool {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return true }
        let accountId = self.conversation.accountId
        return self.locationSharingService
            .isAlreadySharing(accountId: accountId,
                              contactUri: jamiId)
    }

    func isAlreadySharingMyLocation() -> Bool {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return true }
        let accountId = self.conversation.accountId
        return self.locationSharingService.isAlreadySharingMyLocation(accountId: accountId, contactUri: jamiId)
    }

    func startSendingLocation(duration: TimeInterval) {
        guard let account = self.accountService.currentAccount,
              let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
        self.locationSharingService.startSharingLocation(from: account.id,
                                                         to: jamiId,
                                                         duration: duration)
    }

    func stopSendingLocation() {
        guard let account = self.accountService.currentAccount,
              let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
        self.locationSharingService.stopSharingLocation(accountId: account.id,
                                                        contactUri: jamiId)
    }

    func getMyLocationSharingRemainedTime() -> Int {
        guard let account = self.accountService.currentAccount,
              let jamiId = self.conversation.getParticipants().first?.jamiId else { return 0}
        return self.locationSharingService.getMyLocationSharingRemainedTime(accountId: account.id, contactUri: jamiId)
    }

    func getMyLocationSharingRemainedTimeText() -> String {
        let remainingTime = getMyLocationSharingRemainedTime()
        let hours = remainingTime / 60
        let minutes = remainingTime % 60

        let hourString = hours == 1 ? "hour" : "hours"
        let minuteString = minutes == 1 ? "minute" : "minutes"

        if hours == 0 {
            if minutes == 0 {
                return "0 minutes"
            } else {
                return "\(minutes) \(minuteString)"
            }
        } else {
            if minutes == 0 {
                return "\(hours) \(hourString)"
            } else {
                return "\(hours) \(hourString), \(minutes) \(minuteString)"
            }
        }
    }
}
