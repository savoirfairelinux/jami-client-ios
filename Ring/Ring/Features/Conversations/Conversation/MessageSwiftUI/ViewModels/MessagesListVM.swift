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
import SwiftyBeaver

enum MessageInfo: State {
    case updateAvatar(jamiId: String, message: AvatarImageObserver)
    case updateRead(messageId: String, message: MessageReadObserver)
    case updateDisplayname(jamiId: String, message: NameObserver)
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
// swiftlint:disable file_length
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
    @Published var isTemporary: Bool = false
    @Published var name: String = "" {
        didSet {
            updateSyncMessageIfNeeded()
        }
    }
    @Published var isSyncing: Bool = false
    @Published var isBlocked: Bool = false
    @Published var syncMessage = ""
    private let log = SwiftyBeaver.self
    var contactAvatar: UIImage = UIImage()
    var currentAccountAvatar: UIImage = UIImage()
    var myContactsLocation: CLLocationCoordinate2D?
    var myCoordinate: CLLocationCoordinate2D?
    // jams
    var jamsAvatarData: Data?
    var jamsName: String = ""

    var accountService: AccountsService
    var profileService: ProfilesService
    var dataTransferService: DataTransferService
    var locationSharingService: LocationSharingService
    var conversationService: ConversationsService
    var contactsService: ContactsService
    var nameService: NameService
    var requestsService: RequestsService
    var presenceService: PresenceService
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

    var lastMessage = BehaviorRelay<String>(value: "")
    var lastMessageDate = BehaviorRelay<String>(value: "")
    var lastMessageDisposeBag = DisposeBag()

    var hideNavigationBar = BehaviorRelay(value: false)
    var conversationDisposeBag = DisposeBag()
    let disposeBag = DisposeBag()

    var lastMessageBeforeScroll: String?

    var loading = true // to avoid a new loading while previous one still executing
    var avatars = ConcurentDictionary(name: "com.AvatarsAccesDictionary", dictionary: [String: BehaviorRelay<UIImage?>]())
    var names = ConcurentDictionary(name: "com.NamesAccesDictionary", dictionary: [String: String]())
    // last read
    // dictionary of participant id and last read message Id
    var lastReadMessageForParticipant = ConcurentDictionary(name: "com.ReadMessageForParticipantAccesDictionary",
                                                            dictionary: [String: String]())
    // dictionary of message id and array of participants for whom the message is last read
    var lastRead = ConcurentDictionary(name: "com.lastReadAccesDictionary",
                                       dictionary: [String: BehaviorRelay<[String: UIImage]?>]())
    private let subscriptionQueue = DispatchQueue(label: "com.myapp.subscriptionQueue", qos: .userInitiated)
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
    var conversation: ConversationModel! {
        didSet {
            subscriptionQueue.async { [weak self] in
                guard let self = self else { return }
                self.invalidateAndSetupConversationSubscriptions()
            }
            self.updateColorPreference()
            self.updateLastDisplayed()
        }
    }

    func invalidateAndSetupConversationSubscriptions() {
        self.conversationDisposeBag = DisposeBag()
        self.subscribeForNewMessages()
        self.subscribeMessageUpdates()
        self.subscribeReactions()
    }

    init (injectionBag: InjectionBag, transferHelper: TransferHelper) {
        self.requestsService = injectionBag.requestsService
        self.conversation = ConversationModel()
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.dataTransferService = injectionBag.dataTransferService
        self.conversationService = injectionBag.conversationsService
        self.contactsService = injectionBag.contactsService
        self.nameService = injectionBag.nameService
        self.presenceService = injectionBag.presenceService
        self.transferHelper = transferHelper
        self.locationSharingService = injectionBag.locationSharingService
        self.messagePanel = MessagePanelVM(messagePanelState: self.messagePanelStateSubject)
        self.contextMenuModel.currentJamiAccountId = self.accountService.currentAccount?.jamiId
        self.subscribeLocationEvents()
        self.subscribeSwarmPreferences()
        self.subscribeUserAvatarForLocationSharing()
        self.subscribeReplyTarget()
        self.subscribeMessagesActions()
        self.subscribeContextMenu()
    }

    func subscribeScreenTapped(screenTapped: Observable<Bool>) {
        screenTapped
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                self.screenTapped = event
            })
            .disposed(by: self.disposeBag)
    }

    func unblock() {
        guard let account = accountService.currentAccount,
              conversation.isDialog(),
              let jamiId = conversation.getParticipants().first?.jamiId,
              let contact = contactsService.contact(withHash: jamiId) else {
            return
        }

        contactsService.unbanContact(contact: contact, account: account)
        presenceService.subscribeBuddy(withAccountId: account.id,
                                       withJamiId: contact.hash,
                                       withFlag: true)
    }

    func subscribeBestName(bestName: Observable<String>) {
        self.messagePanel.subscribeBestName(bestName: bestName)
    }

    func updateSyncMessageIfNeeded() {
        if name.isEmpty { return }
        self.syncMessage = L10n.Conversation.synchronizationMessage(name)
    }

    func sendRequest() {
        guard let conversation = self.conversation,
              let jamiId = conversation.getParticipants().first?.jamiId else { return }
        var avatar: String?
        if let avatarData = self.jamsAvatarData {
            avatar = String(data: avatarData, encoding: .utf8)
        }
        self.requestsService
            .sendContactRequest(to: jamiId,
                                withAccountId: conversation.accountId,
                                avatar: avatar,
                                alias: jamsName)
            .subscribe(onCompleted: { [weak self, weak conversation] in
                guard let self = self,
                      let conversation = conversation else { return }
                if conversation.isDialog() {
                    self.presenceService.subscribeBuddy(withAccountId: conversation.accountId,
                                                        withJamiId: jamiId,
                                                        withFlag: true)
                }
                DispatchQueue.main.async {[weak self] in
                    guard let self = self else { return }
                    self.isTemporary = false
                }
            }, onError: { [weak self] (_) in
                self?.log.error("Error sending contact request")
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
                // The view has a max size 50. Create a larger image for better resolution.
                if let photo = profile.photo,
                   let image = photo.createImage(size: 100) {
                    self.currentAccountAvatar = image
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
            .disposed(by: self.conversationDisposeBag)
    }

    func subscribeContextMenu() {
        self.contextMenuModel.sendEmojiUpdate
            .subscribe(onNext: { [weak self] event in
                if let self = self, !event.isEmpty {
                    switch event["action"] {
                    case ReactionCommand.apply.toString():
                        if let dat = event["data"], let mId = event["parentMessageId"] {
                            self.conversationService.sendEmojiReactionMessage(conversationId: self.conversation.id, accountId: self.conversation.accountId, message: dat, parentId: mId)
                        } else {
                            self.log.error("[MessagesListVM] Invalid data provided while attempting to add a reaction a message.")
                        }
                    case ReactionCommand.revoke.toString():
                        if let rId = event["reactionId"] {
                            self.conversationService.editSwarmMessage(conversationId: self.conversation.id, accountId: self.conversation.accountId, message: "", parentId: rId)
                        } else {
                            self.log.error("[MessagesListVM] Invalid message ID provided while attempting to revoke a reaction from a message.")
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
            .disposed(by: self.conversationDisposeBag)
    }

    func subscribeForNewMessages() {
        conversation.newMessages.share()
            .startWith(LoadedMessages(messages: conversation.messages, fromHistory: true))
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] messages in
                guard let self = self else { return }
                if self.conversation.messages.isEmpty {
                    self.messagesModels = [MessageContainerModel]()
                    return
                }
                let insertionCount: Int = self.insert(messages: messages.messages,
                                                      fromHistory: messages.fromHistory)
                if insertionCount == 0 {
                    return
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
            .disposed(by: self.conversationDisposeBag)
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

    private func insert(messages: [MessageModel], fromHistory: Bool) -> Int {
        guard let localJamiId = self.accountService.getAccount(fromAccountId: self.conversation.accountId)?.jamiId else {
            return 0
        }

        // Filter out messages that already exist in messagesModels to avoid duplicates
        let newMessages = messages.filter { newMessage in
            !self.messagesModels.contains(where: { messageModel in
                messageModel.message.id == newMessage.id
            })
        }

        let newContainers = newMessages.map { newMessage -> MessageContainerModel in

            let isHistory = newMessage.isReply()
            let container = MessageContainerModel(
                message: newMessage,
                contextMenuState: self.contextStateSubject,
                isHistory: isHistory,
                localJamiId: localJamiId,
                preferencesColor: self.conversation.preferences.getColor()
            )

            self.subscribeMessage(container: container)
            self.updateLastRead(message: container)
            self.updateLastDelivered(message: container)

            if newMessage.isReply() {
                self.receiveReply(newMessage: container, fromHistory: fromHistory)
            }

            return container
        }

        if fromHistory {
            self.messagesModels.append(contentsOf: newContainers)
        } else {
            self.messagesModels.insert(contentsOf: newContainers, at: 0)
        }

        updateLastMessageIfNeeded(fromHistory: fromHistory,
                                  newContainers: newContainers)

        return newContainers.count
    }

    private func updateLastMessageIfNeeded(fromHistory: Bool, newContainers: [MessageContainerModel]) {
        /*
         Update the last message details if necessary. We do not need to update
         the last message if we are loading older messages, unless it is the
         initial loading of the conversation.

         Since `newContainers` was just added, we should check if `messagesModels`
         contains messages other than those in `newContainers`.
         If so, simply return.
         */
        guard !(self.messagesModels.count > newContainers.count && fromHistory) else {
            return
        }

        /*
         Order is reversed when loading history.
         When we receive a new message, it only contains one message.
         */
        guard let lastMessageContainer = newContainers.first else { return }

        // Reset the subscription for the last message.
        lastMessageDisposeBag = DisposeBag()

        let lastMessage = lastMessageContainer.message
        self.lastMessageDate.accept(lastMessage.receivedDate.conversationTimestamp())

        if lastMessage.type != .contact {
            self.lastMessage.accept(lastMessage.content)
        } else {
            // For contact messages, update when the display name is available.
            lastMessageContainer.contactViewModel.observableContent
                .startWith(lastMessageContainer.contactViewModel.observableContent.value)
                .subscribe { [weak self] content in
                    self?.lastMessage.accept(content)
                }
                .disposed(by: lastMessageDisposeBag)
        }
    }

    func getLastReadIndices() -> [Int]? {
        var lastReadIndices: [Int]?

        let lastReadMessages = self.lastReadMessageForParticipant.values().compactMap({ $0 as? String }).filter({ !$0.isEmpty })
        lastReadIndices = lastReadMessages.compactMap { messageId in
            self.messagesModels.firstIndex { $0.id == messageId }
        }
        return lastReadIndices
    }

    private func areDeliveredIndexesSmallerThanRead(deliveredMessageIndex: Int, lastReadIndices: [Int]?) -> Bool {
        guard let lastReadIndices = lastReadIndices else { return true }
        return lastReadIndices.allSatisfy { deliveredMessageIndex < $0 }
    }

    func updateLastDelivered(message: MessageContainerModel) {
        guard message.message.isDelivered() else { return }
        /*
         Update 'lastDelivered' with this message if no previous 'lastDelivered' exists,
         or if this message precedes the current 'lastDelivered' in the messages list.
         */

        // get indices of last read messages
        let lastReadIndices = getLastReadIndices()

        guard let index = self.messagesModels.firstIndex(where: { $0.id == message.id }) else { return }

        guard let lastDelivered = self.lastDelivered,
              let lastDeliveredIndex = self.messagesModels.firstIndex(where: { $0.id == lastDelivered.id }) else {
            if areDeliveredIndexesSmallerThanRead(deliveredMessageIndex: index, lastReadIndices: lastReadIndices) {
                self.lastDelivered = message
            }
            return
        }

        let newDeliveredIndex = min(index, lastDeliveredIndex)

        // if read message is latest than delivered, remove indicator for read from previous delivered
        if !areDeliveredIndexesSmallerThanRead(deliveredMessageIndex: newDeliveredIndex, lastReadIndices: lastReadIndices) {
            self.lastDelivered = nil
        } else if index < lastDeliveredIndex {
            // otherwise update last delivered message
            self.lastDelivered = message
        }
    }

    func cleanMessages() {
        self.messagesModels = [MessageContainerModel]()
    }

    func updateBlockedStatus(blocked: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isBlocked = blocked
        }
    }

    private func getMessageIndex(messageId: String) -> Int? {
        return self.messagesModels.firstIndex(where: { $0.id == messageId })
    }

    private func updateLastRead(message: MessageContainerModel, participantId: String) {
        guard !message.message.incoming, message.message.status == .displayed,
              let newIndex = self.getMessageIndex(messageId: message.id) else { return }
        /*
         If there is no current last read message for the participant, set this
         message as the last read. Otherwise, check if the new message appears
         later in the messages list than the previous last displayed message
         and update it accordingly.
         */

        guard let currentLastReadMessageId = self.lastReadMessageForParticipant.get(key: participantId) as? String,
              let currentIndex = self.getMessageIndex(messageId: currentLastReadMessageId) else {
            self.lastReadMessageForParticipant.set(value: message.id, for: participantId)
            self.updateSubscriptionLastRead(messageId: message.id)
            self.removeDeliveredStatusIfNeed()
            return
        }

        if newIndex < currentIndex {
            self.lastReadMessageForParticipant.set(value: message.id, for: participantId)
            // remove last read indicator from previous last read message
            self.updateSubscriptionLastRead(messageId: currentLastReadMessageId)
            // add last read indicator to new last read message
            self.updateSubscriptionLastRead(messageId: message.id)
        }

        self.removeDeliveredStatusIfNeed()
    }

    private func removeDeliveredStatusIfNeed() {
        // check if delivered status should be removed
        guard let lastDelivered = self.lastDelivered,
              let lastDeliveredIndex = self.getMessageIndex(messageId: lastDelivered.id)  else { return }
        let lastReadIndices = getLastReadIndices()
        if !self.areDeliveredIndexesSmallerThanRead(deliveredMessageIndex: lastDeliveredIndex, lastReadIndices: lastReadIndices) {
            self.lastDelivered = nil
        }
    }

    private func updateLastRead(message: MessageContainerModel) {
        for status in message.message.statusForParticipant {
            updateLastRead(message: message, participantId: status.key)
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
            case .updateAvatar(let jamiId, let message):
                self.getAvatar(jamiId: jamiId, message: message, messageId: container.id)
            case .updateRead(let messageId, let message):
                self.getLastRead(message: message, messageId: messageId)
            case .updateDisplayname(let jamiId, let message):
                self.getName(jamiId: jamiId, message: message, messageId: container.id)
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
        container.listenerForInfoStateAdded()
    }
    // swiftlint:enable cyclomatic_complexity

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
         otherwise, load conversation until the required message.
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
        if let name = self.names.get(key: jamiId) as? BehaviorRelay<String> {
            self.messagePanel.updateUsername(name: name.value, jamiId: jamiId)
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
            } else if let last = lastMessageTime {
                // only show time for new messages if beyond an arbitrary time frame from the previously shown time
                let timeDifference = currentMessageTime.timeIntervalSinceReferenceDate - last.timeIntervalSinceReferenceDate
                model.shouldShowTimeString = Int(timeDifference) < messageGroupingInterval ? false : true
            } else {
                model.shouldShowTimeString = false
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

    private func updateName(name: String, jamiId: String) {
        if let nameObservable = self.names.get(key: jamiId) as? BehaviorRelay<String> {
            nameObservable.accept(name)
        }
    }

    private func updateAvatar(image: UIImage, jamiId: String) {
        // Update the avatar observable if it exists
        if let avatarObservable = avatars.get(key: jamiId) as? BehaviorRelay<UIImage?> {
            avatarObservable.accept(image)
        }

        // Update the last read avatars if applicable
        guard let lastReadMessageId = lastReadMessageForParticipant.get(key: jamiId) as? String,
              let lastReadAvatars = lastRead.get(key: lastReadMessageId) as? BehaviorRelay<[String: UIImage]> else {
            return
        }
        var value = lastReadAvatars.value
        value[jamiId] = image
        lastReadAvatars.accept(value)
    }

    private func nameLookup(id: String) {
        self.nameService.usernameLookupStatus
            .filter({ lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == id
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self] lookupNameResponse in
                guard let self = self else { return }
                // Update name
                if let name = lookupNameResponse.name, !name.isEmpty {
                    self.updateName(name: name, jamiId: id)
                } else {
                    self.updateName(name: id, jamiId: id)
                }
                // Create an avatar if it has not been set yet.
                self.setAvatarIfNeededFor(jamiId: id, withDefault: true)
            })
            .disposed(by: self.disposeBag)
        self.nameService.lookupAddress(withAccount: self.conversation.accountId, nameserver: "", address: id)
    }

    private func getInformationForContact(id: String) {
        DispatchQueue.global(qos: .background).async {[weak self] in
            guard let self = self else { return }
            guard let account = self.accountService.getAccount(fromAccountId: self.conversation.accountId) else { return }
            if self.contactsService.contact(withHash: id) == nil {
                self.updateName(name: id, jamiId: id)
                self.nameLookup(id: id)
                return
            }
            let schema: URIType = account.type == .sip ? .sip : .ring
            guard let contactURI = JamiURI(schema: schema, infoHash: id).uriString else { return }
            self.profileService
                .getProfile(uri: contactURI,
                            createIfNotexists: false,
                            accountId: account.id)
                .subscribe(onNext: { [weak self] profile in
                    guard let self = self else { return }
                    // Set name
                    if let profileName = profile.alias, !profileName.isEmpty {
                        self.updateName(name: profileName, jamiId: id)
                    }
                    // Set avatar
                    // The view has a max size 50. Create a larger image for better resolution.
                    if let photo = profile.photo,
                       let image = photo.createImage(size: 100) {
                        self.updateAvatar(image: image, jamiId: id)
                    } else {
                        self.setAvatarIfNeededFor(jamiId: id, withDefault: false)
                    }
                    // Perform a name lookup if the profile does not have a name
                    let name = (self.names.get(key: id) as? BehaviorRelay<String>)?.value
                    if name?.isEmpty ?? true {
                        self.nameLookup(id: id)
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    private func setAvatarIfNeededFor(jamiId: String, withDefault: Bool) {
        // Attempt to retrieve the observable avatar and proceed only if it's nil (no image set yet).
        guard let observableAvatar = self.avatars.get(key: jamiId) as? BehaviorRelay<UIImage?>,
              observableAvatar.value == nil else { return }

        // Retrieve the name associated with the jamiId, defaulting to an empty string if not found.
        let name = (self.names.get(key: jamiId) as? BehaviorRelay<String>)?.value ?? ""

        // If the name is empty and a default avatar is not requested, exit early.
        if name.isEmpty && !withDefault { return }

        let avatarImage = UIImage.createContactAvatar(username: name, size: CGSize(width: 30, height: 30))
        self.updateAvatar(image: avatarImage, jamiId: jamiId)
    }

    private func getAvatar(jamiId: String, message: AvatarImageObserver, messageId: String) {
        // check if we already have the avatar for a contact
        if let avatar = self.avatars.get(key: jamiId) as? BehaviorRelay<UIImage?> {
            message.subscribeToAvatarObservable(avatar)
            // check if we need avatar for local account
        } else if let accountJamiId = self.accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId, accountJamiId == jamiId {
            message.subscribeToAvatarObservable(BehaviorRelay(value: self.currentAccountAvatar))
        } else {
            // create entrance for participant and start contact fetching
            let imageObservable = BehaviorRelay<UIImage?>(value: nil)
            self.avatars.set(value: imageObservable, for: jamiId)
            if let avatar = self.avatars.get(key: jamiId) as? BehaviorRelay<UIImage?> {
                message.subscribeToAvatarObservable(avatar)
            }
            self.getInformationForContact(id: jamiId)
        }
    }

    private func getName(jamiId: String, message: NameObserver, messageId: String) {
        if let name = self.names.get(key: jamiId) as? BehaviorRelay<String> {
            message.subscribeToNameObservable(name)
        } else if let accountJamiId = self.accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId, accountJamiId == jamiId {
            message.subscribeToNameObservable(BehaviorRelay(value: L10n.Account.me))
        } else {
            let nameObservable = BehaviorRelay(value: "")
            self.names.set(value: nameObservable, for: jamiId)
            message.subscribeToNameObservable(nameObservable)
            self.getInformationForContact(id: jamiId)
        }
    }

    private func getLastRead(message: MessageReadObserver, messageId: String) {
        if let lastReadAvatars = self.lastRead.get(key: messageId) as? BehaviorRelay<[String: UIImage]> {
            message.subscribeToReadObservable(lastReadAvatars)
        } else {
            let observableValue = BehaviorRelay(value: [String: UIImage]())
            self.lastRead.set(value: observableValue, for: messageId)
            message.subscribeToReadObservable(observableValue)
            self.updateSubscriptionLastRead(messageId: messageId)
        }
    }

    private func updateSubscriptionLastRead(messageId: String) {
        // get avatar images for last read
        var images = [String: UIImage]()

        guard let participants = self.lastReadMessageForParticipant.filter({ participant in
            if let id = participant.value as? String {
                return id == messageId
            }
            return false
        }) as? [String: String], !participants.isEmpty else {
            if let lastReadAvatars = self.lastRead.get(key: messageId) as? BehaviorRelay<[String: UIImage]> {
                lastReadAvatars.accept(images)
            }
            return
        }

        if self.lastRead.get(key: messageId) as? BehaviorRelay<[String: UIImage]> == nil {
            let observableValue = BehaviorRelay(value: [String: UIImage]())
            self.lastRead.set(value: observableValue, for: messageId)
        }
        guard let lastReadAvatars = self.lastRead.get(key: messageId) as? BehaviorRelay<[String: UIImage]> else { return }
        for participant in participants {
            if let avatar = self.avatars.get(key: participant.key) as? UIImage {
                images[participant.key] = avatar
            } else {
                images[participant.key] = UIImage()
                let imageObservable = BehaviorRelay<UIImage?>(value: nil)
                self.avatars.set(value: imageObservable, for: participant.key)
                self.getInformationForContact(id: participant.key)
            }
        }
        lastReadAvatars.accept(images)
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
// swiftlint:enable type_body_length
