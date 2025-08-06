/*
 *  Copyright (C) 2017-2024 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

import UIKit
import RxSwift
import RxCocoa
import SwiftyBeaver
import SwiftUI

enum MessageSequencing {
    case singleMessage
    case firstOfSequence
    case lastOfSequence
    case middleOfSequence
    case unknown
}

enum GeneratedMessageType: String {
    case receivedContactRequest = "Contact request received"
    case contactAdded = "Contact added"
    case missedIncomingCall = "Missed incoming call"
    case missedOutgoingCall = "Missed outgoing call"
    case incomingCall = "Incoming call"
    case outgoingCall = "Outgoing call"
}

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class ConversationViewModel: Stateable, ViewModel, ObservableObject, Identifiable {

    @Published var avatar: UIImage?
    @Published var name: String = ""
    @Published var lastMessage: String = ""
    @Published var lastMessageDate: String = ""
    @Published var unreadMessages: Int = 0
    @Published var presence: PresenceStatus = .offline

    func getDefaultAvatar() -> UIImage {
        if let conversation = self.conversation,
           !conversation.isDialog() {
            return UIImage.createSwarmAvatar(convId: conversation.id, size: CGSize(width: 55, height: 55))
        }
        return UIImage.createContactAvatar(username: (self.displayName.value?.isEmpty ?? true) ? self.userName.value : self.displayName.value!, size: CGSize(width: 55, height: 55))
    }

    /// Logger
    private let log = SwiftyBeaver.self

    // Services
    private let conversationsService: ConversationsService
    private let accountService: AccountsService
    private let nameService: NameService
    private let contactsService: ContactsService
    private let presenceService: PresenceService
    private let profileService: ProfilesService
    private let callService: CallsService
    private let locationSharingService: LocationSharingService
    let dataTransferService: DataTransferService

    let injectionBag: InjectionBag

    internal let disposeBag = DisposeBag()

    func closeAllPlayers() {
        self.swiftUIModel.transferHelper.closeAllPlayers()
    }

    let showIncomingLocationSharing = BehaviorRelay<Bool>(value: false)
    let showOutgoingLocationSharing = BehaviorRelay<Bool>(value: false)
    let updateNavigationBar = BehaviorRelay<Bool>(value: false)

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    var isAccountSip: Bool = false

    var displayName = BehaviorRelay<String?>(value: nil)
    var userName = BehaviorRelay<String>(value: "")
    lazy var bestName: Observable<String> = {
        return Observable
            .combineLatest(userName.asObservable(),
                           displayName.asObservable(),
                           resultSelector: {(userName, displayname) in
                            guard let displayname = displayname, !displayname.isEmpty else {
                                return userName }
                            return displayname
                           })
    }()

    /// Group's image data
    var profileImageData = BehaviorRelay<Data?>(value: nil)

    var contactPresence = BehaviorRelay<PresenceStatus>(value: .offline)
    var swarmInfo: SwarmInfoProtocol?

    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.contactsService = injectionBag.contactsService
        self.presenceService = injectionBag.presenceService
        self.profileService = injectionBag.profileService
        self.dataTransferService = injectionBag.dataTransferService
        self.callService = injectionBag.callService
        self.locationSharingService = injectionBag.locationSharingService
        let transferHelper = TransferHelper(injectionBag: injectionBag)

        swiftUIModel = MessagesListVM(injectionBag: self.injectionBag,
                                      transferHelper: transferHelper)
        swiftUIModel.subscribeBestName(bestName: self.bestName)
        self.bestName
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith((self.displayName.value?.isEmpty ?? true) ? self.userName.value : self.displayName.value!)
            .subscribe(onNext: { [weak self] bestName in
                let name = bestName.replacingOccurrences(of: "\0", with: "")
                guard !name.isEmpty else { return }
                self?.name = name
                self?.swiftUIModel.name = name
            })
            .disposed(by: self.disposeBag)

        self.profileImageData
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith(self.profileImageData.value)
            .subscribe(onNext: { [weak self] imageData in
                if let imageData = imageData, !imageData.isEmpty {
                    let targetSize: CGFloat = 55
                    let image = UIImage.resizeImage(from: imageData, targetSize: targetSize)
                    self?.avatar = image
                }
            })
            .disposed(by: self.disposeBag)

        self.lastMessageObservable
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith(swiftUIModel.lastMessage.value)
            .subscribe(onNext: { [weak self] mesage in
                self?.lastMessage = mesage
            })
            .disposed(by: self.disposeBag)

        self.lastMessageDateObservable
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith(swiftUIModel.lastMessageDate.value)
            .subscribe(onNext: { [weak self] mesageDate in
                self?.lastMessageDate = mesageDate
            })
            .disposed(by: self.disposeBag)
        self.conversationCreated
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] update in
                guard let self = self, update else { return }
                if self.conversation != nil {
                    self.swiftUIModel.conversation = self.conversation
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func setConversation(_ conversation: ConversationModel) {
        self.conversation = conversation
    }

    convenience init(with injectionBag: InjectionBag, conversation: ConversationModel, user: JamiSearchViewModel.JamsUserSearchModel) {
        self.init(with: injectionBag)
        self.userName.accept(user.username)
        self.displayName.accept(user.firstName + " " + user.lastName)
        self.profileImageData.accept(user.profilePicture)
        self.swiftUIModel.jamsAvatarData = user.profilePicture
        self.swiftUIModel.jamsName = user.firstName + " " + user.lastName
        self.setConversation(conversation) // required to trigger the didSet
    }

    var swiftUIModel: MessagesListVM

    var lastMessageObservable: Observable <String> {
        return swiftUIModel.lastMessage.asObservable()
    }

    var lastMessageDateObservable: Observable <String> {
        return swiftUIModel.lastMessageDate.asObservable()
    }

    func cleanMessages() {
        self.swiftUIModel.cleanMessages()
    }

    var conversation: ConversationModel! {
        didSet {
            self.subscribeUnreadMessages()
            self.swiftUIModel.conversation = conversation

            guard let account = self.accountService.getAccount(fromAccountId: self.conversation.accountId) else { return }
            if account.type == AccountType.sip {
                self.userName.accept(self.conversation.hash)
                self.isAccountSip = true
                return
            }
            self.updateBlockedStatus()
            self.setupPresence()
            if self.shouldCreateSwarmInfo() {
                self.createSwarmInfo()
            } else {
                let filterParicipants = conversation.getParticipants()
                if let participantId = filterParicipants.first?.jamiId,
                   let contact = self.contactsService.contact(withHash: participantId) {
                    self.subscribeNonSwarmProfiles(uri: "ring:" + participantId,
                                                   accountId: self.conversation.accountId)
                    if let contactUserName = contact.userName {
                        self.userName.accept(contactUserName)
                    } else if self.userName.value.isEmpty {
                        self.userName.accept(filterParicipants.first?.jamiId ?? "")
                        self.subscribeUserServiceLookupStatus()
                        self.nameService.lookupAddress(withAccount: self.conversation.accountId, nameserver: "", address: filterParicipants.first?.jamiId ?? "")
                    }
                } else {
                    self.userName.accept(filterParicipants.first?.jamiId ?? "")
                    self.subscribeUserServiceLookupStatus()
                    self.nameService.lookupAddress(withAccount: self.conversation.accountId, nameserver: "", address: filterParicipants.first?.jamiId ?? "")
                }
                /*
                 By default, a conversation is created as non-swarm. Upon receiving the conversationReady
                 notification, we need to verify whether it is a swarm or not
                 */
                subscribeConversationReady()
            }
            subscribeConversationSynchronization()
            subscribeLocationEvents()
        }
    }

    private func subscribeConversationSynchronization() {
        let syncObservable = self.conversation.flatMap { conversation -> BehaviorRelay<Bool> in
            let innerObservable = conversation.synchronizing
            return innerObservable
        }
        syncObservable?
            .startWith(self.conversation.synchronizing.value)
            .subscribe { [weak self] synchronizing in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.swiftUIModel.isSyncing = synchronizing
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func subscribeConversationReady() {
        self.conversationsService.conversationReady
            .subscribe { [weak self] conversationId in
                guard let self = self else { return }
                /*
                 Check if the conversation, originally created as non-swarm,
                 becomes a swarm after an update. If so, update the relevant information.
                 */
                if conversationId == self.conversation.id {
                    if self.shouldCreateSwarmInfo() {
                        self.createSwarmInfo()
                    }
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    func shouldCreateSwarmInfo() -> Bool {
        return self.conversation.isSwarm() && self.swarmInfo == nil && !self.conversation.id.isEmpty
    }

    func createSwarmInfo() {
        self.swarmInfo = SwarmInfo(injectionBag: self.injectionBag, conversation: self.conversation)
        self.swarmInfo!.finalAvatar.share()
            .subscribe { [weak self] image in
                self?.profileImageData.accept(image.pngData())
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        self.swarmInfo!.title.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] name in
                self?.displayName.accept(name)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        self.swarmInfo!.participantsString.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] name in
                self?.userName.accept(name)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func subscribeNonSwarmProfiles(uri: String, accountId: String) {
        self.profileService
            .getProfile(uri: uri, createIfNotexists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe {[weak self] profile in
                guard let self = self else { return }
                if let alias = profile.alias, let photo = profile.photo {
                    if !alias.isEmpty {
                        self.displayName.accept(alias)
                    }
                    if !photo.isEmpty {
                        let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? // {
                        self.profileImageData.accept(data)
                    }
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    // Add the matches method to handle filtering logic
    func matches(_ searchQuery: String) -> Bool {
        if self.model().isSwarm() {
            guard let swarmInfo = self.swarmInfo else { return false }
            return swarmInfo.contains(searchQuery: searchQuery)
        } else {
            var displayNameContainsText = false
            if let displayName = self.displayName.value {
                displayNameContainsText = displayName.containsCaseInsensitive(string: searchQuery)
            }
            var participantHashContainsText = false
            if let hash = self.model().getParticipants().first?.jamiId {
                participantHashContainsText = hash.containsCaseInsensitive(string: searchQuery)
            }
            return self.userName.value.containsCaseInsensitive(string: searchQuery) ||
                displayNameContainsText || participantHashContainsText
        }
    }

    func editMessage(content: String, messageId: String) {
        guard let conversation = self.conversation else { return }
        self.conversationsService.editSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: content, parentId: messageId)
    }

    func setIsComposingMsg(isComposing: Bool) {
        if let conversationx = conversation {
            guard let uri = conversationx.getConversationURI() else { return }
            conversationsService.setIsComposingMsg(
                to: uri,
                from: conversation.accountId,
                isComposing: isComposing
            )
        }
    }

    func joinActiveCall(call: ActiveCall, withVideo: Bool) {
        let callURI = call.constructURI()
        if withVideo {
            stateSubject.onNext(ConversationState.startCall(contactRingId: callURI, userName: ""))
        } else {
            stateSubject.onNext(ConversationState.startAudioCall(contactRingId: callURI, userName: ""))
        }
    }

    private func prepareCallURI() -> String? {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return nil }
        var uri = self.conversation.isDialog() ? jamiId : "swarm:" + self.conversation.id

        if let activeCall = self.callService.getActiveCall(accountId: self.conversation.accountId, conversationId: self.conversation.id), !self.conversation.isDialog() {
            uri = activeCall.constructURI()
        }

        return uri
    }

    func startCall() {
        guard let uri = prepareCallURI() else { return }
        let name = self.conversation.isDialog() ? self.displayName.value ?? self.userName.value : ""
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: uri, userName: name))
    }

    func startAudioCall() {
        guard let uri = prepareCallURI() else { return }
        let name = self.conversation.isDialog() ? self.displayName.value ?? self.userName.value : ""
        self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: uri, userName: name))
    }

    func sendMessage(withContent content: String, parentId: String = "", contactURI: String? = nil, conversationModel: ConversationModel? = nil) {
        let conversation = conversationModel ?? self.conversation
        guard let conversation = conversation else { return }
        if !conversation.isSwarm() {
            /// send not swarm message
            guard let participantJamiId = conversation.getParticipants().first?.jamiId,
                  let account = self.accountService.currentAccount else { return }
            // if in call send sip msg
            if let call = self.callService.call(participantId: participantJamiId, accountId: conversation.accountId) {
                self.callService.sendInCallMessage(callID: call.callId, message: content, accountId: account)
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
        guard let account = self.accountService.currentAccount,
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
        let isSwarmConversation = conversation.type != .nonSwarm && conversation.type != .sip
        if isSwarmConversation {
            if let swarmInfo = self.swarmInfo {
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

    func recordAudioFile() {
        closeAllPlayers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation, audioOnly: true))
        }
    }

    func haveCurrentCall() -> Bool {
        if !self.conversation.isDialog() {
            return false
        }
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return false }
        return self.callService.call(participantId: jamiId, accountId: self.conversation.accountId) != nil
    }

    lazy var showCallButton: Observable<Bool> = {
        return self.callService
            .callUpdates
            .share()
            .asObservable()
            .filter({ [weak self] (call) -> Bool in
                guard let self = self else { return false }
                if !self.conversation.isDialog() {
                    return false
                }
                guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return false }
                return call.paricipantHash() == jamiId
                    && call.accountId == self.conversation.accountId
            })
            .map({ [weak self]  call in
                guard let self = self else { return false }
                let show = self.shouldShowCallButton(call: call)
                self.currentCallId.accept(show ? call.callId : "")
                return show
            })
    }()

    let currentCallId = BehaviorRelay<String>(value: "")

    func callIsValid(call: CallModel) -> Bool {
        return call.stateValue == CallState.hold.rawValue ||
            call.stateValue == CallState.unhold.rawValue ||
            call.stateValue == CallState.current.rawValue ||
            call.stateValue == CallState.ringing.rawValue ||
            call.stateValue == CallState.connecting.rawValue
    }

    func shouldShowCallButton(call: CallModel) -> Bool {
        // From iOS 15 picture in picture is supported and it will take care of presenting the video call.
        if #available(iOS 15.0, *) {
            if call.isAudioOnly {
                return callIsValid(call: call)
            }
            return call.stateValue == CallState.ringing.rawValue || call.stateValue == CallState.connecting.rawValue
        }
        return callIsValid(call: call)
    }

    func openCall() {
        guard let call = self.callService
                .call(participantId: self.conversation.getParticipants().first?.jamiId ?? "",
                      accountId: self.conversation.accountId) else { return }

        self.stateSubject.onNext(ConversationState.navigateToCall(call: call))
    }

    deinit {
        self.closeAllPlayers()
    }

    var myContactsLocation = BehaviorSubject<CLLocationCoordinate2D?>(value: nil)
    let shouldDismiss = BehaviorRelay<Bool>(value: false)

    func openFullScreenPreview(parentView: UIViewController, viewModel: PlayerViewModel?, image: UIImage?, initialFrame: CGRect, delegate: PreviewViewControllerDelegate) {
        self.stateSubject.onNext(ConversationState.openFullScreenPreview(parentView: parentView, viewModel: viewModel, image: image, initialFrame: initialFrame, delegate: delegate))
    }

    var conversationCreated = BehaviorRelay(value: true)

    func updateBlockedStatus() {
        self.swiftUIModel.updateBlockedStatus(blocked: isConversationForBlockedContact())
        self.updateNavigationBar.accept(true)
    }

    func isConversationForBlockedContact() -> Bool {
        if !self.conversation.isDialog() {
            return false
        }

        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return false }
        guard let contact = self.contactsService.contact(withHash: jamiId) else { return false }
        return contact.banned
    }
}

// MARK: Conversation didSet functions
extension ConversationViewModel {

    private func setupPresence() {
        if !self.conversation.isDialog() {
            return
        }

        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
        if let contact = self.contactsService.contact(withHash: jamiId) {
            // Exit if the contact is banned
            guard !contact.banned else { return }

            // Subscribe to presence updates for the contact
            subscribePresence(contactId: jamiId)
        } else if self.isCoreConversationWith(jamiId: jamiId) {
            // If contact is not available and it's a core conversation, subscribe to the contact added event
            subscribeToContactAdded()
        }
    }

    private func subscribePresence(contactId: String) {
        if let contactPresence = self.presenceService.getSubscriptionsForContact(contactId: contactId) {
            self.contactPresence = contactPresence
            self.contactPresence
                .observe(on: MainScheduler.instance)
                .subscribe(
                    onNext: { [weak self] presence in
                        self?.presence = presence
                    },
                    onError: { error in
                        print("Error observing presence updates: \(error)")
                    }
                )
                .disposed(by: self.disposeBag)
        }
    }

    private func subscribeToContactAdded() {
        self.contactsService.sharedResponseStream
            .filter { $0.eventType == .contactAdded &&
                $0.getEventInput(.conversationId) == self.conversation.id
            }
            .take(1)
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let peerUri: String = event.getEventInput(.peerUri),
                      self.isCoreConversationWith(jamiId: peerUri) else { return }
                self.setupPresence()
            })
            .disposed(by: disposeBag)
    }

    private func subscribeUnreadMessages() {
        self.conversation.numberOfUnreadMessages
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] unreadMessages in
                guard let self = self else { return }
                self.unreadMessages = unreadMessages
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func subscribePresence() {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId, self.conversation.isDialog() else { return }
        if let contactPresence = self.presenceService
            .getSubscriptionsForContact(contactId: jamiId) {
            self.contactPresence = contactPresence
        } else {
            self.contactPresence.accept(.offline)
        }
    }

    private func subscribeUserServiceLookupStatus() {
        let contact = self.contactsService.contact(withHash: self.conversation.getParticipants().first?.jamiId ?? "")

        // Return an observer for the username lookup
        self.nameService
            .usernameLookupStatus
            .filter({ [weak self] lookupNameResponse in
                return lookupNameResponse.requestedName != nil &&
                    (lookupNameResponse.requestedName == self?.conversation.getParticipants().first?.jamiId ||
                        lookupNameResponse.requestedName == self?.conversation.getParticipants().first?.jamiId)
            })
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if let name = lookupNameResponse.name, !name.isEmpty {
                    self?.userName.accept(name)
                    contact?.userName = name
                } else if let address = lookupNameResponse.requestedName {
                    self?.userName.accept(address)
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: Location sharing
extension ConversationViewModel {

    func isAlreadySharingLocation() -> Bool {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return true }
        let accountId = self.conversation.accountId
        return self.locationSharingService.isAlreadySharing(accountId: accountId,
                                                            contactUri: jamiId)
    }

    func isAlreadySharingMyLocation() -> Bool {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return true }
        let accountId = self.conversation.accountId
        return self.locationSharingService.isAlreadySharingMyLocation(accountId: accountId,
                                                                      contactUri: jamiId)
    }

    func startSendingLocation(duration: TimeInterval? = nil) {
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

    func model() -> ConversationModel {
        return self.conversation
    }

    func subscribeLocationEvents() {
        self.locationSharingService
            .peerUriAndLocationReceived
            .subscribe(onNext: { [weak self] tuple in
                guard let self = self else { return }
                if tuple.1 != nil &&
                    self.isAlreadySharingLocation() {
                    self.showIncomingLocationSharing.accept(true)
                } else {
                    self.showIncomingLocationSharing.accept(false)
                }
            })
            .disposed(by: self.disposeBag)

        self.locationSharingService.currentLocation
            .subscribe(onNext: { [weak self] myCurrentLocation in
                guard let self = self else { return }
                if myCurrentLocation != nil &&
                    self.isAlreadySharingMyLocation() {
                    self.showOutgoingLocationSharing.accept(true)
                } else {
                    self.showOutgoingLocationSharing.accept(false)
                }
            })
            .disposed(by: self.disposeBag)
    }
}

// MARK: share message
extension ConversationViewModel {

    private func changeConversationIfNeeded(items: [String]) {
        guard let accountId = self.accountService.currentAccount?.id else { return }
        if items.contains(where: { $0 == self.conversation.id }) { return } // if items contains the current conversation, we do not need to change it
        guard let selectedConversationId = items.first else { return }
        self.stateSubject.onNext(ConversationState.openConversationForConversationId(conversationId: selectedConversationId, accountId: accountId, shouldOpenSmarList: true, withAnimation: true))
    }

    private func shareMessage(message: MessageContentVM, with conversationId: String, fileURL: URL?, fileName: String) {
        guard let accountId = self.accountService.currentAccount?.id else { return }
        let conversationModel = self.conversationsService.getConversationForId(conversationId: conversationId, accountId: accountId) ?? self.conversation
        if message.type != .fileTransfer {
            self.sendMessage(withContent: message.content, conversationModel: conversationModel)
            return
        }
        if let url = fileURL, let conversationModel = conversationModel {
            if conversationModel.messages.contains(where: { $0.content == message.content }) {
                self.sendFile(filePath: url.path, displayName: fileName, conversationModel: conversationModel)
            } else if let data = FileManager.default.contents(atPath: url.path) {
                self.sendAndSaveFile(displayName: fileName, imageData: data, conversationModel: conversationModel)
            }
            return
        }
    }

    private func shareMessage(message: MessageContentVM, with selectedConversations: [String]) {
        // to send file we need to have file url or image
        let url = message.url
        var fileName = message.content
        if message.content.contains("\n") {
            guard let substring = message.content.split(separator: "\n").first else { return }
            fileName = String(substring)
        }
        selectedConversations.forEach { [ weak self, weak message ] item in
            guard let self = self, let message = message else { return }
            self.shareMessage(message: message, with: item, fileURL: url, fileName: fileName)
        }
        self.changeConversationIfNeeded(items: selectedConversations)
    }

    func slectContactsToShareMessage(message: MessageContentVM) {
        guard message.message.type == .text || message.message.type == .fileTransfer else { return }
        self.stateSubject.onNext(ConversationState.showContactPicker(callID: "", contactSelectedCB: nil, conversationSelectedCB: { [weak self] selectedItems in
            guard let self = self, let selectedItems = selectedItems else { return }
            self.shareMessage(message: message, with: selectedItems)
        }))
    }
}

// MARK: file transfer
extension ConversationViewModel {

    func sendFile(filePath: String, displayName: String, localIdentifier: String? = nil, conversationModel: ConversationModel? = nil) {
        guard let conversation = (conversationModel ?? self.conversation) else { return }
        self.dataTransferService.sendFile(conversation: conversation, filePath: filePath, displayName: displayName, localIdentifier: localIdentifier)
    }

    func sendAndSaveFile(displayName: String, imageData: Data, conversationModel: ConversationModel? = nil) {
        guard let conversation = (conversationModel ?? self.conversation) else { return }
        self.dataTransferService.sendAndSaveFile(displayName: displayName, conversation: conversation, imageData: imageData)
    }
}

extension ConversationViewModel: Equatable {
    static func == (lhs: ConversationViewModel, rhs: ConversationViewModel) -> Bool {
        lhs.conversation == rhs.conversation
    }
}

extension ConversationViewModel {
    func isCoreConversationWith(jamiId: String) -> Bool {
        guard conversation.isCoredialog(),
              let participantJamiId = conversation.getParticipants().first?.jamiId else {
            return false
        }
        return participantJamiId == jamiId
    }


}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
