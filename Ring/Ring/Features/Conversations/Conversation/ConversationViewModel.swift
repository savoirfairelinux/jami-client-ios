/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
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

enum BubblePosition {
    case received
    case sent
    case generated
}

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
    @Published var temporary: Bool = false
    @Published var presence: PresenceStatus = .offline

    func getDefaultAvatar() -> UIImage {
        return UIImage.createContactAvatar(username: (self.displayName.value?.isEmpty ?? true) ? self.userName.value : self.displayName.value!)
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

//    private var players = [String: PlayerViewModel]()
//
//    func getPlayer(messageID: String) -> PlayerViewModel? {
//        return players[messageID]
//    }
//    func setPlayer(messageID: String, player: PlayerViewModel) { players[messageID] = player }
//    func closeAllPlayers() {
//        let queue = DispatchQueue.global(qos: .default)
//        queue.sync {
//            self.players.values.forEach { (player) in
//                player.closePlayer()
//            }
//            self.players.removeAll()
//        }
//    }

    let showInvitation = BehaviorRelay<Bool>(value: false)

    let showIncomingLocationSharing = BehaviorRelay<Bool>(value: false)
    let showOutgoingLocationSharing = BehaviorRelay<Bool>(value: false)

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    var synchronizing = BehaviorRelay<Bool>(value: false)

    lazy var typingIndicator: Observable<Bool> = {
        return self.conversationsService
            .sharedResponseStream
            .filter({ [weak self] (event) -> Bool in
                return event.eventType == ServiceEventType.messageTypingIndicator &&
                event.getEventInput(ServiceEventInput.accountId) == self?.conversation.accountId &&
                event.getEventInput(ServiceEventInput.peerUri) == self?.conversation.hash
            })
            .map({ (event) -> Bool in
                if let status: Int = event.getEventInput(ServiceEventInput.state), status == 1 {
                    return true
                }
                return false
            })
    }()

    private var isJamsAccount: Bool { self.accountService.isJams(for: self.conversation.accountId) }

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
    /// My profile's image data
    var myOwnProfileImageData: Data?

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
                                      transferHelper: transferHelper,
                                      bestName: BehaviorRelay<String>(value: "").asObservable(),
                                      screenTapped: BehaviorRelay<Bool>(value: false).asObservable())
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
//                let nameNSString = name as NSString
//                self?.conversationInSyncLabel.text = L10n.Conversation.synchronizationMessage(nameNSString)
            })
            .disposed(by: self.disposeBag)

        self.profileImageData
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith(self.profileImageData.value)
            .subscribe(onNext: { [weak self] imageData in
                if let imageData = imageData, !imageData.isEmpty {
                    if let image = UIImage(data: imageData) {
                        self?.avatar = image
                    } else {
                        print("*****could not create image")
                    }
                }
//                let name = bestName.replacingOccurrences(of: "\0", with: "")
//                guard !name.isEmpty else { return }
//                self?.name = name
                //                let nameNSString = name as NSString
                //                self?.conversationInSyncLabel.text = L10n.Conversation.synchronizationMessage(nameNSString)
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

        self.showInvitation
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] show in
                self?.swiftUIModel.isTemporary = show
                self?.temporary = show
            } onError: { _ in }
            .disposed(by: self.disposeBag)
    }

    private func setConversation(_ conversation: ConversationModel) {
       // if self.conversation != nil {
            self.conversation = conversation
//        } else {
//            self.conversation = BehaviorRelay(value: conversation)
//        }
    }

    convenience init(with injectionBag: InjectionBag, conversation: ConversationModel, user: JamiSearchViewModel.JamsUserSearchModel) {
        self.init(with: injectionBag)
        self.userName.accept(user.username)
        self.displayName.accept(user.firstName + " " + user.lastName)
        self.profileImageData.accept(user.profilePicture)
        self.setConversation(conversation) // required to trigger the didSet
    }

    var request: RequestModel? {
        didSet {
            if request != nil && !self.showInvitation.value {
                self.showInvitation.accept(true)
            }
        }
    }

    var swiftUIModel: MessagesListVM

    var lastMessageObservable: Observable <String> {
        return swiftUIModel.lastMessage.asObservable()
    }

    var lastMessageDateObservable: Observable <String> {
        return swiftUIModel.lastMessageDate.asObservable()
    }

    var conversation: ConversationModel! {
        didSet {
            self.subscribeUnreadMessages()
            self.subscribeProfileServiceMyPhoto()

            guard let account = self.accountService.getAccount(fromAccountId: self.conversation.accountId) else { return }
            if account.type == AccountType.sip {
                self.userName.accept(self.conversation.hash)
                self.isAccountSip = true
                self.subscribeLastMessagesUpdate()
                return
            }
            self.swiftUIModel.conversation = conversation
            ///
            let showInv = self.request != nil || self.conversation.id.isEmpty
            if self.showInvitation.value != showInv {
                self.showInvitation.accept(showInv)
            }
            self.subscribePresenceServiceContactPresence()
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
                    print("&&&&&&& not contact not swarm. lookup\(filterParicipants.first?.jamiId ?? "")")
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
            subscribeLastMessagesUpdate()
            subscribeConversationSynchronization()
            subscribeLocationEvents()
            // self.subscribeConversationServiceTypingIndicator()
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
                guard let self = self else { return }
                self.synchronizing.accept(synchronizing)
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
        let partString: String =  self.conversation.getParticipants().first?.jamiId ?? ""
        print("&&&&&&& create swarm info \(partString)")
        self.swarmInfo = SwarmInfo(injectionBag: self.injectionBag, conversation: self.conversation)
        self.swarmInfo!.finalAvatar.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] image in
                self?.profileImageData.accept(image.pngData())
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        self.swarmInfo!.finalTitle.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] name in
                self?.displayName.accept(name)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    private func subscribeNonSwarmProfiles(uri: String, accountId: String) {
        print("&&&&&&& subscribe not swarm profile \(uri)")
        self.profileService
            .getProfile(uri: uri, createIfNotexists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe { profile in
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

    private func subscribeLastMessagesUpdate() {
        conversation.newMessages
            .subscribe { [weak self] _ in
                guard let self = self, let lastMessage = self.conversation.lastMessage else { return }
                //self.lastMessage.accept(lastMessage.content)
                let lastMessageDate = lastMessage.receivedDate
                let dateToday = Date()
                var dateString = ""
                let todayWeekOfYear = Calendar.current.component(.weekOfYear, from: dateToday)
                let todayDay = Calendar.current.component(.day, from: dateToday)
                let todayMonth = Calendar.current.component(.month, from: dateToday)
                let todayYear = Calendar.current.component(.year, from: dateToday)
                let weekOfYear = Calendar.current.component(.weekOfYear, from: lastMessageDate)
                let day = Calendar.current.component(.day, from: lastMessageDate)
                let month = Calendar.current.component(.month, from: lastMessageDate)
                let year = Calendar.current.component(.year, from: lastMessageDate)
                if todayDay == day && todayMonth == month && todayYear == year {
                    dateString = self.hourFormatter.string(from: lastMessageDate)
                } else if day == todayDay - 1 {
                    dateString = L10n.Smartlist.yesterday
                } else if todayYear == year && todayWeekOfYear == weekOfYear {
                    dateString = lastMessageDate.dayOfWeek()
                } else {
                    dateString = self.dateFormatter.string(from: lastMessageDate)
                }
                self.lastMessageReceivedDate.accept(dateString)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    /// Displays the entire date ( for messages received before the current week )
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    /// Displays the hour of the message reception ( for messages received today )
    private lazy var hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var unreadMessagesObservable = BehaviorRelay<String>(value: "")

   // var lastMessage = BehaviorRelay<String>(value: "")
    var lastMessageReceivedDate = BehaviorRelay<String>(value: "")

    var hideNewMessagesLabel = BehaviorRelay<Bool>(value: true)

    var hideDate: Bool { self.conversation.messages.isEmpty }

    func editMessage(content: String, messageId: String) {
        guard let conversation = self.conversation else { return }
        self.conversationsService.editSwarmMessage(conversationId: conversation.id, accountId: conversation.accountId, message: content, parentId: messageId)
    }

    func sendMessage(withContent content: String, parentId: String = "", contactURI: String? = nil, conversationModel: ConversationModel? = nil) {
        let conversation = conversationModel ?? self.conversation
        guard let conversation = conversation else { return }
        if !conversation.isSwarm() {
            /// send not swarm message
            guard let participantJamiId = conversation.getParticipants().first?.jamiId,
                  let account = self.accountService.currentAccount else { return }
            /// if in call send sip msg
            if let call = self.callService.call(participantHash: participantJamiId, accountID: conversation.accountId) {
                self.callService.sendTextMessage(callID: call.callId, message: content, accountId: account)
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

    func setMessageAsRead(daemonId: String, messageId: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.conversationsService
                .setMessageAsRead(conversation: self.conversation,
                                  messageId: messageId,
                                  daemonId: daemonId)
        }
    }

    func startCall() {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
       // self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: jamiId, userName: self.displayName.value ?? self.userName.value))
    }

    func startAudioCall() {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
       // self.closeAllPlayers()
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: jamiId, userName: self.displayName.value ?? self.userName.value))
    }

    func showContactInfo() {
        if self.showInvitation.value {
            return
        }
        //self.closeAllPlayers()
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
       // closeAllPlayers()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stateSubject.onNext(ConversationState.recordFile(conversation: self.conversation, audioOnly: false))
        }
    }

    func recordAudioFile() {
       // closeAllPlayers()
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
        return self.callService.call(participantHash: jamiId, accountID: self.conversation.accountId) != nil
    }

    lazy var showCallButton: Observable<Bool> = {
        return self.callService
            .currentCallsEvents
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
                .call(participantHash: self.conversation.getParticipants().first?.jamiId ?? "",
                      accountID: self.conversation.accountId) else { return }

        self.stateSubject.onNext(ConversationState.navigateToCall(call: call))
    }

//    deinit {
//        self.closeAllPlayers()
//    }

    func setIsComposingMsg(isComposing: Bool) {
        //        if composingMessage == isComposing {
        //            return
        //        }
        //        composingMessage = isComposing
        //        guard let account = self.accountService.currentAccount else { return }
        //        conversationsService
        //            .setIsComposingMsg(to: self.conversation.participantUri,
        //                               from: account.id,
        //                               isComposing: isComposing)
    }

    func addComposingIndicatorMsg() {
        //        if peerComposingMessage {
        //            return
        //        }
        //        peerComposingMessage = true
        //        var messagesValue = self.messages.value
        //        let msgModel = MessageModel(withId: "",
        //                                    receivedDate: Date(),
        //                                    content: "       ",
        //                                    authorURI: self.conversation.participantUri,
        //                                    incoming: true)
        //        let composingIndicator = MessageViewModel(withInjectionBag: self.injectionBag, withMessage: msgModel, isLastDisplayed: false)
        //        composingIndicator.isComposingIndicator = true
        //        messagesValue.append(composingIndicator)
        //        self.messages.accept(messagesValue)
    }

    var composingMessage: Bool = false
    // var peerComposingMessage: Bool = false

    func removeComposingIndicatorMsg() {
        //        if !peerComposingMessage {
        //            return
        //        }
        //        peerComposingMessage = false
        //        let messagesValue = self.messages.value
        //        let conversationsMsg = messagesValue.filter { (messageModel) -> Bool in
        //            !messageModel.isComposingIndicator
        //        }
        //        self.messages.accept(conversationsMsg)
    }

    var myContactsLocation = BehaviorSubject<CLLocationCoordinate2D?>(value: nil)
    let shouldDismiss = BehaviorRelay<Bool>(value: false)

    func openFullScreenPreview(parentView: UIViewController, viewModel: PlayerViewModel?, image: UIImage?, initialFrame: CGRect, delegate: PreviewViewControllerDelegate) {
        self.stateSubject.onNext(ConversationState.openFullScreenPreview(parentView: parentView, viewModel: viewModel, image: image, initialFrame: initialFrame, delegate: delegate))
    }

    var conversationCreated = BehaviorRelay(value: true)

    func openInvitationView(parentView: UIViewController) {
        let name = self.displayName.value?.isEmpty ?? true ? self.userName.value : self.displayName.value ?? ""
        let handler: ((String) -> Void) = { [weak self] conversationId in
            guard let self = self else { return }
            guard let conversation = self.conversationsService.getConversationForId(conversationId: conversationId, accountId: self.conversation.accountId),
                  !conversationId.isEmpty else {
                self.shouldDismiss.accept(true)
                return
            }
            self.request = nil
            self.conversation = conversation
            self.conversationCreated.accept(true)
            if self.showInvitation.value {
                self.showInvitation.accept(false)
            }
        }
        if let request = self.request {
            // show incoming request
            self.stateSubject.onNext(ConversationState.openIncomingInvitationView(displayName: name, request: request, parentView: parentView, invitationHandeledCB: handler))
        } else if self.conversation.id.isEmpty {
            // send invitation for search result
            let alias = (self.conversation.type == .jams ? self.displayName.value : "") ?? ""
            self.stateSubject.onNext(ConversationState
                                        .openOutgoingInvitationView(displayName: name, alias: alias, avatar: self.profileImageData.value,
                                                                    contactJamiId: self.conversation.hash,
                                                                    accountId: self.conversation.accountId,
                                                                    parentView: parentView,
                                                                    invitationHandeledCB: handler))
        }
    }
}

// MARK: Conversation didSet functions
extension ConversationViewModel {

    private func subscribeProfileServiceMyPhoto() {
        guard let account = self.accountService.currentAccount else { return }
        self.profileService
            .getAccountProfile(accountId: account.id)
            .subscribe(onNext: { [weak self] profile in
                guard let self = self else { return }
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    self.myOwnProfileImageData = data
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribePresenceServiceContactPresence() {
        if !self.conversation.isDialog() {
            return
        }
        // subscribe to presence updates for the conversation's associated contact
        if let jamiId = self.conversation.getParticipants().first?.jamiId, let contactPresence = self.presenceService.getSubscriptionsForContact(contactId: jamiId) {
            self.contactPresence = contactPresence
        } else {
            self.contactPresence.accept(.offline)
            self.presenceService
                .sharedResponseStream
                .filter({ [weak self] serviceEvent in
                    guard let uri: String = serviceEvent.getEventInput(ServiceEventInput.uri),
                          let accountID: String = serviceEvent.getEventInput(ServiceEventInput.accountId),
                    let conversation = self?.conversation else { return false }
                    return uri == conversation.getParticipants().first?.jamiId && accountID == conversation.accountId
                })
                .subscribe(onNext: { [weak self] _ in
                    self?.subscribePresence()
                })
                .disposed(by: self.disposeBag)
            self.presenceService.subscribeBuddy(withAccountId: self.conversation.accountId, withUri: self.conversation.getParticipants().first!.jamiId, withFlag: true)
        }
        self.contactPresence
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] presence in
                self?.presence = presence
            } onError: { _ in }
            .disposed(by: self.disposeBag)
    }

    private func subscribeUnreadMessages() {
        self.conversation.numberOfUnreadMessages
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] unreadMessages in
                guard let self = self else { return }
               // self.hideNewMessagesLabel.accept(unreadMessages == 0)
                DispatchQueue.main.async {
                    self.unreadMessages = unreadMessages
                }
               // self.unreadMessages.accept(String(unreadMessages.description))
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
                return lookupNameResponse.address != nil &&
                (lookupNameResponse.address == self?.conversation.getParticipants().first?.jamiId ||
                 lookupNameResponse.address == self?.conversation.getParticipants().first?.jamiId)
            })
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if let name = lookupNameResponse.name, !name.isEmpty {
                    self?.userName.accept(name)
                    contact?.userName = name
                } else if let address = lookupNameResponse.address {
                    self?.userName.accept(address)
                }
            })
            .disposed(by: disposeBag)
    }

    private func subscribeConversationServiceTypingIndicator() {
        self.typingIndicator
            .subscribe(onNext: { [weak self] (typing) in
                if typing {
                    self?.addComposingIndicatorMsg()
                } else {
                    self?.removeComposingIndicatorMsg()
                }
            })
            .disposed(by: self.disposeBag)
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
        self.stateSubject.onNext(ConversationState.openConversationForConversationId(conversationId: selectedConversationId, accountId: accountId, shouldOpenSmarList: true))
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
