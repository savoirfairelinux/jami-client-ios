/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import UIKit
import RxSwift
import RxCocoa
import SwiftyBeaver
import SwiftUI
import Combine

enum MessageSequencing {
    case singleMessage
    case firstOfSequence
    case lastOfSequence
    case middleOfSequence
    case unknown
}

class ConversationViewModel: Stateable, ObservableObject {

    @Published private(set) var name: String = ""
    @Published private(set) var navUserName: String = ""
    @Published private(set) var isBlocked: Bool = false
    @Published var navBarContentWidth: CGFloat = 0
    @Published private(set) var navBarAvatarProvider: AvatarProvider

    let row: ConversationRowVM
    private(set) var conversation: ConversationModel
    let swiftUIModel: MessagesListVM
    let peerSharing: PeerSharingTracker
    let shouldDismiss = BehaviorRelay<Bool>(value: false)

    var isAccountSip: Bool {
        row.isAccountSip
    }

    var lastMessageObservable: Observable<String> {
        return swiftUIModel.lastMessage.asObservable()
    }

    private let log = SwiftyBeaver.self

    private let conversationsService: ConversationsService
    private let accountService: AccountsService
    private let profileService: ProfilesService
    private let callService: CallService
    private let locationSharingService: LocationSharingService
    private let collaborationService: CollaborationService
    private let dataTransferService: DataTransferService

    private let disposeBag = DisposeBag()
    private var swarmInfoDisposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    init(with injectionBag: InjectionBag, row: ConversationRowVM) {
        self.conversationsService = injectionBag.conversationsService
        self.accountService = injectionBag.accountService
        self.profileService = injectionBag.profileService
        self.callService = injectionBag.callService
        self.locationSharingService = injectionBag.locationSharingService
        self.peerSharing = PeerSharingTracker(peerSharingService: injectionBag.peerSharingService)
        self.collaborationService = injectionBag.collaborationService
        self.dataTransferService = injectionBag.dataTransferService
        self.row = row
        self.conversation = row.conversation
        self.swiftUIModel = MessagesListVM(injectionBag: injectionBag,
                                           transferHelper: TransferHelper(injectionBag: injectionBag))
        self.navBarAvatarProvider = Self.makeNavBarAvatarProvider(row: row,
                                                                  swarmInfo: row.swarmInfo,
                                                                  profileService: injectionBag.profileService)

        swiftUIModel.actionHandler.forwardMessage = { [weak self] message, conversations in
            self?.shareMessage(message: message, with: conversations)
        }
        swiftUIModel.subscribeBestName(bestName: row.bestName)
        swiftUIModel.isTemporary = row.isTemporary
        swiftUIModel.temporaryPeerProfile = row.temporaryPeerProfile
        swiftUIModel.$isTemporary
            .dropFirst()
            .sink { [weak self, weak row] isTemporary in
                row?.isTemporary = isTemporary
                row?.temporaryPeerProfile = self?.swiftUIModel.temporaryPeerProfile
            }
            .store(in: &cancellables)

        bindRow()
        row.conversationChanges
            .compactMap { $0 }
            .distinctUntilChanged { $0 === $1 }
            .subscribe(onNext: { [weak self] conversation in
                self?.attach(to: conversation)
            })
            .disposed(by: disposeBag)
    }

    deinit {
        self.closeAllPlayers()
    }

    func closeAllPlayers() {
        self.swiftUIModel.transferHelper.closeAllPlayers()
    }

    private func bindRow() {
        row.bestName
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] bestName in
                let name = bestName.replacingOccurrences(of: "\0", with: "")
                guard !name.isEmpty else { return }
                self?.name = name
                self?.swiftUIModel.name = name
            })
            .disposed(by: disposeBag)

        row.userName
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] userName in
                self?.navUserName = userName
            })
            .disposed(by: disposeBag)

        row.$isBlocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blocked in
                self?.isBlocked = blocked
                self?.swiftUIModel.updateBlockedStatus(blocked: blocked)
            }
            .store(in: &cancellables)

        row.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSyncing in
                self?.swiftUIModel.isSyncing = isSyncing
            }
            .store(in: &cancellables)

        row.swarmInfoChanges
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] swarmInfo in
                self?.swarmInfoChanged(swarmInfo)
            })
            .disposed(by: disposeBag)
    }

    private func swarmInfoChanged(_ swarmInfo: SwarmInfoProtocol?) {
        swarmInfoDisposeBag = DisposeBag()
        navBarAvatarProvider = Self.makeNavBarAvatarProvider(row: row,
                                                             swarmInfo: swarmInfo,
                                                             profileService: profileService)
        swarmInfo?.conversationEnded
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isEnded in
                self?.swiftUIModel.isConversationEnded = isEnded
            })
            .disposed(by: swarmInfoDisposeBag)
    }

    private static func makeNavBarAvatarProvider(row: ConversationRowVM,
                                                 swarmInfo: SwarmInfoProtocol?,
                                                 profileService: ProfilesService) -> AvatarProvider {
        if let swarmInfo = swarmInfo {
            return AvatarProvider.from(swarmInfo: swarmInfo,
                                       profileService: profileService,
                                       size: .conversation30)
        }
        return AvatarProvider(profileService: profileService,
                              size: Constants.AvatarSize.conversation30,
                              avatar: row.profileImageData.asObservable(),
                              displayName: row.bestName,
                              isGroup: !row.conversation.isCoredialog())
    }

    private func attach(to conversation: ConversationModel) {
        self.conversation = conversation
        swiftUIModel.conversation = conversation
        guard !row.isAccountSip else { return }
        peerSharing.track(conversation, isBlocked: row.isConversationForBlockedContact())
    }

    func editMessage(content: String, messageId: String) {
        self.conversationsService.editSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: content, parentId: messageId)
    }

    func setIsComposingMsg(isComposing: Bool) {
        conversationsService.setIsComposingMsg(
            to: conversation.getConversationURI(),
            from: conversation.accountId,
            isComposing: isComposing
        )
    }

    func joinActiveCall(call: ActiveCall, withVideo: Bool) {
        let callURI = call.constructURI()
        if withVideo {
            stateSubject.onNext(ConversationState.startCall(contactRingId: callURI, userName: ""))
        } else {
            stateSubject.onNext(ConversationState.startAudioCall(contactRingId: callURI, userName: ""))
        }
    }

    func startCall() {
        guard let uri = callService.outgoingCallURI(for: conversation) else { return }
        let name = getContactNameForCall()
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: uri, userName: name))
    }

    func startAudioCall() {
        guard let uri = callService.outgoingCallURI(for: conversation) else { return }
        let name = getContactNameForCall()
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: uri, userName: name))
    }

    private func getContactNameForCall() -> String {
        guard self.conversation.isDialog() else { return "" }

        if let displayName = row.displayName.value, !displayName.isEmpty {
            return displayName
        }
        return row.userName.value
    }

    func sendMessage(withContent content: String, parentId: String = "", contactURI: String? = nil, conversationModel: ConversationModel? = nil) {
        let conversation = conversationModel ?? self.conversation
        if !conversation.isSwarm() {
            /// send not swarm message
            guard let participantJamiId = conversation.getParticipants().first?.jamiId,
                  let account = self.accountService.getAccount(fromAccountId: conversation.accountId) else { return }
            // if in call send sip msg
            if let call = self.callService.call(participantId: participantJamiId, accountId: conversation.accountId) {
                self.callService.sendInCallMessage(callId: call, message: content, accountId: account)
                self.conversationsService.saveOutgoingNonSwarmMessage(withId: "", content: content, status: .unknown,
                                                                      from: account, jamiId: participantJamiId)
                return
            }
            self.conversationsService
                .sendNonSwarmMessage(withContent: content,
                                     from: account,
                                     jamiId: participantJamiId)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.debug("Message sent")
                })
                .disposed(by: self.disposeBag)
            return
        }
        if conversation.id.isEmpty {
            return
        }
        /// send swarm message
        self.conversationsService.sendSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: content, parentId: parentId)
    }

    func setMessagesAsRead() {
        guard let account = self.accountService.getAccount(fromAccountId: conversation.accountId),
              let ringId = AccountModelHelper(withAccount: account).ringId else { return }
        self.conversationsService
            .setMessagesAsRead(forConversation: self.conversation,
                               accountId: account.id,
                               accountURI: ringId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func messageDisplayed() {
        if let message = self.swiftUIModel.messagesModels.first, message.message.incoming {
            self.setMessagesAsRead()
        }
    }

    func showContactInfo() {
        if self.swiftUIModel.isTemporary {
            return
        }
        self.closeAllPlayers()
        if conversation.isSwarm() {
            if let swarmInfo = row.swarmInfo {
                self.stateSubject.onNext(ConversationState.presentSwarmInfo(swarmInfo: swarmInfo))
            }
        } else {
            self.stateSubject.onNext(ConversationState.contactDetail(conversationViewModel: self.conversation))
        }
    }

    func recordVideoFile() {
        closeAllPlayers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation, audioOnly: false))
        }
    }
}

// MARK: Location sharing
extension ConversationViewModel {

    func isAlreadySharingMyLocation() -> Bool {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return true }
        let accountId = self.conversation.accountId
        return self.locationSharingService.isAlreadySharingMyLocation(accountId: accountId,
                                                                      contactUri: jamiId)
    }

    func startSendingLocation(duration: TimeInterval? = nil) {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
        self.locationSharingService.startSharingLocation(from: self.conversation.accountId,
                                                         to: jamiId,
                                                         duration: duration)
    }
}

// MARK: share message
extension ConversationViewModel {

    private func changeConversationIfNeeded(items: [String]) {
        if items.contains(where: { $0 == self.conversation.id }) { return } // if items contains the current conversation, we do not need to change it
        guard let selectedConversationId = items.first else { return }
        self.stateSubject.onNext(ConversationState.openConversationForConversationId(conversationId: selectedConversationId,
                                                                                     accountId: conversation.accountId,
                                                                                     shouldOpenSmarList: true,
                                                                                     withAnimation: true))
    }

    private func shareMessage(message: MessageContentVM, to conversationModel: ConversationModel, fileURL: URL?, fileName: String) {
        if message.type != .fileTransfer {
            self.sendMessage(withContent: message.content, conversationModel: conversationModel)
            return
        }
        if let url = fileURL {
            let content = message.content
            let dataTransferService = self.dataTransferService
            self.conversationsService.readMessages(of: conversationModel) { [weak self] messages in
                let alreadyShared = messages.contains(where: { $0.content == content })
                if alreadyShared {
                    DispatchQueue.main.async {
                        self?.sendFile(filePath: url.path, displayName: fileName, conversationModel: conversationModel)
                    }
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let data = FileManager.default.contents(atPath: url.path) else { return }
                    dataTransferService.sendAndSaveFile(displayName: fileName,
                                                        conversation: conversationModel,
                                                        imageData: data)
                }
            }
            return
        }
    }

    func shareMessage(message: MessageContentVM, with selectedConversations: [String]) {
        // to send file we need to have file url or image
        let url = message.url
        var fileName = message.content
        if message.content.contains("\n") {
            guard let substring = message.content.split(separator: "\n").first else { return }
            fileName = String(substring)
        }
        let targets = selectedConversations.compactMap {
            self.conversationsService.getConversationForId(conversationId: $0, accountId: conversation.accountId)
        }
        targets.forEach { self.shareMessage(message: message, to: $0, fileURL: url, fileName: fileName) }
        self.changeConversationIfNeeded(items: targets.map(\.id))
    }

    func slectContactsToShareMessage(message: MessageContentVM) {
        guard message.message.type == .text || message.message.type == .fileTransfer else { return }
        self.stateSubject.onNext(ConversationState.showContactPicker(callID: "", contactSelectedCB: nil, conversationSelectedCB: { [weak self] selectedItems in
            guard let self = self, let selectedItems = selectedItems else { return }
            self.shareMessage(message: message, with: selectedItems)
        }))
    }

    /**
     Starts a collaborative document and opens it.

     - parameter failed: called when no document was started, the daemon having
     refused or the call itself having failed.
     */
    func createCollabDocument(named name: String, failed: @escaping () -> Void) {
        let conversation = self.conversation
        self.collaborationService
            .createDocument(accountId: conversation.accountId,
                            conversationId: conversation.id,
                            name: name)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] document in
                guard let self = self else { return }
                self.stateSubject.onNext(
                    ConversationState.openCollabDocument(accountId: conversation.accountId,
                                                         conversationId: conversation.id,
                                                         documentId: document.id,
                                                         name: document.name))
            }, onFailure: { _ in
                failed()
            })
            .disposed(by: self.disposeBag)
    }

    func openCollabDocument(documentId: String, name: String) {
        self.stateSubject.onNext(
            ConversationState.openCollabDocument(accountId: conversation.accountId,
                                                 conversationId: conversation.id,
                                                 documentId: documentId,
                                                 name: name))
    }
}

// MARK: file transfer
extension ConversationViewModel {

    func sendFile(filePath: String, displayName: String, localIdentifier: String? = nil, conversationModel: ConversationModel? = nil) {
        let conversation = conversationModel ?? self.conversation
        self.dataTransferService.sendFile(conversation: conversation, filePath: filePath, displayName: displayName, localIdentifier: localIdentifier)
    }

    func sendAndSaveFile(displayName: String, imageData: Data, conversationModel: ConversationModel? = nil) {
        let conversation = conversationModel ?? self.conversation
        self.dataTransferService.sendAndSaveFile(displayName: displayName, conversation: conversation, imageData: imageData)
    }
}
