/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

// swiftlint:disable type_body_length
class ConversationRowVM: ObservableObject, Identifiable {

    @Published var name: String = "" {
        didSet {
            if conversation != nil {
                updateName()
            }
        }
    }
    @Published var nameWithSuffix: String = ""
    @Published var lastMessage: String = ""
    @Published var lastMessageDate: String = ""
    @Published var unreadMessages: Int = 0
    @Published var presence: PresenceStatus = .offline
    @Published var isBlocked: Bool = false
    @Published var isSyncing: Bool = false
    @Published var hasIncomingCall: Bool = false

    var isTemporary = false
    var temporaryPeerProfile: Profile?
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
    var profileImageData = BehaviorRelay<Data?>(value: nil)
    var contactPresence = BehaviorRelay<PresenceStatus>(value: .offline)
    let swarmInfoChanges = BehaviorRelay<SwarmInfoProtocol?>(value: nil)
    var swarmInfo: SwarmInfoProtocol? {
        didSet {
            swarmInfoChanges.accept(swarmInfo)
        }
    }

    lazy var avatarProvider: AvatarProvider = {
        return AvatarProvider(
            profileService: self.injectionBag.profileService,
            size: Constants.AvatarSize.default55,
            avatar: self.profileImageData.asObservable(),
            displayName: self.bestName.asObservable(),
            isGroup: !(self.conversation?.isCoredialog() ?? true)
        )
    }()

    let conversationChanges = BehaviorRelay<ConversationModel?>(value: nil)

    var conversation: ConversationModel! {
        didSet {
            conversationChanges.accept(conversation)
            conversationBindingsDisposeBag = DisposeBag()
            swarmInfo = nil
            messageUnreadCount = 0
            documentUnreadCount = 0
            lastMessageIds = []

            self.subscribeUnreadMessages()
            self.subscribeUnreadDocuments()
            self.subscribeLastMessage()
            self.subscribeIncomingCalls()

            guard let account = self.accountService.getAccount(fromAccountId: self.conversation.accountId) else { return }
            if account.type == AccountType.sip {
                self.userName.accept(self.conversation.hash)
                self.isAccountSip = true
                if let participantId = conversation.getParticipants().first?.jamiId,
                   let uri = ProfilesService.profileUriString(
                    for: JamiURI(schema: .sip, infoHash: participantId)
                   ) {
                    self.subscribeNonSwarmProfiles(uri: uri,
                                                   accountId: self.conversation.accountId)
                }
                return
            }
            self.updateBlockedStatus()
            self.setupPresence()
            self.updateName()

            if self.shouldCreateSwarmInfo() {
                self.createSwarmInfo()
            } else {
                let filterParicipants = conversation.getParticipants()
                if let participantId = filterParicipants.first?.jamiId,
                   let contact = self.contactsService.contact(withHash: participantId) {
                    if let uri = JamiURI(schema: .ring, infoHash: participantId).uriString {
                        self.subscribeNonSwarmProfiles(uri: uri,
                                                       accountId: self.conversation.accountId)
                    }
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
                subscribeConversationReady()
            }
            subscribeConversationSynchronization()
        }
    }

    private let conversationsService: ConversationsService
    private let accountService: AccountsService
    private let nameService: NameService
    private let contactsService: ContactsService
    private let presenceService: PresenceService
    private let profileService: ProfilesService
    private let callService: CallService
    private let collaborationService: CollaborationService
    let injectionBag: InjectionBag

    private let disposeBag = DisposeBag()
    private var conversationBindingsDisposeBag = DisposeBag()
    private var lastMessageDisposeBag = DisposeBag()
    private var messageUnreadCount = 0
    private var documentUnreadCount = 0
    private var lastMessageIds = Set<String>()
    private var lastMessageAuthor: ParticipantInfo?

    init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.accountService = injectionBag.accountService
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.contactsService = injectionBag.contactsService
        self.presenceService = injectionBag.presenceService
        self.profileService = injectionBag.profileService
        self.callService = injectionBag.callService
        self.collaborationService = injectionBag.collaborationService

        self.bestName
            .observe(on: MainScheduler.instance)
            .startWith((self.displayName.value?.isEmpty ?? true) ? self.userName.value : self.displayName.value!)
            .subscribe(onNext: { [weak self] bestName in
                let name = bestName.replacingOccurrences(of: "\0", with: "")
                guard !name.isEmpty else { return }
                self?.name = name
            })
            .disposed(by: self.disposeBag)
    }

    convenience init(with injectionBag: InjectionBag, conversation: ConversationModel, user: JamiSearchViewModel.JamsUserSearchModel) {
        self.init(with: injectionBag)
        self.userName.accept(user.username)
        self.displayName.accept(user.firstName + " " + user.lastName)
        self.profileImageData.accept(user.profilePicture)
        if self.accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId != user.jamiId,
           let uri = JamiURI(schema: .ring, infoHash: user.jamiId).uriString {
            let alias = (user.firstName + " " + user.lastName).simplified()
            let profile = Profile(uri: uri,
                                  alias: alias.isEmpty ? nil : alias,
                                  photo: user.profilePicture?.base64EncodedString(),
                                  type: ProfileType.ring.rawValue)
            self.temporaryPeerProfile = profile.isEmpty ? nil : profile
        }
        self.conversation = conversation
    }

    func model() -> ConversationModel {
        return self.conversation
    }

    func matches(_ searchQuery: String) -> Bool {
        let isSelfConversation = self.model().isOnlyLocalParticipant()
        if isSelfConversation {
            let localJamiId = self.model().getLocalParticipants()?.jamiId ?? ""
            let registeredName = self.accountService.getAccount(fromAccountId: self.model().accountId)?.registeredName ?? ""
            return localJamiId.containsCaseInsensitive(string: searchQuery) ||
                (!registeredName.isEmpty && registeredName.containsCaseInsensitive(string: searchQuery))
        }

        if self.model().isSwarm() {
            guard let swarmInfo = self.swarmInfo else { return false }
            return swarmInfo.contains(searchQuery: searchQuery)
        } else {
            let normalizedQuery = searchQuery.normalized()
            var displayNameContainsText = false
            if let displayName = self.displayName.value {
                displayNameContainsText = displayName.normalized().containsCaseInsensitive(string: normalizedQuery)
            }
            var participantHashContainsText = false
            if let hash = self.model().getParticipants().first?.jamiId {
                participantHashContainsText = hash.normalized().containsCaseInsensitive(string: normalizedQuery)
            }
            return self.userName.value.normalized().containsCaseInsensitive(string: normalizedQuery) ||
                displayNameContainsText || participantHashContainsText
        }
    }

    func isCoreConversationWith(jamiId: String) -> Bool {
        guard conversation.isCoredialog(),
              let participantJamiId = conversation.getParticipants().first?.jamiId else {
            return false
        }
        return participantJamiId == jamiId
    }

    func updateBlockedStatus() {
        let blocked = isConversationForBlockedContact()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isBlocked = blocked
        }
    }

    func isConversationForBlockedContact() -> Bool {
        if !self.conversation.isDialog() {
            return false
        }
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return false }
        guard let contact = self.contactsService.contact(withHash: jamiId) else { return false }
        return contact.banned
    }

    private func updateName() {
        let isSelfConversation = conversation?.getParticipants().isEmpty ?? false
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nameWithSuffix = isSelfConversation ? self.name.withYourselfSuffix() : self.name
        }
    }

    private func shouldCreateSwarmInfo() -> Bool {
        return self.conversation.isSwarm() && self.swarmInfo == nil && !self.conversation.id.isEmpty
    }

    private func createSwarmInfo() {
        let newSwarmInfo = SwarmInfo(injectionBag: self.injectionBag, conversation: self.conversation)
        self.swarmInfo = newSwarmInfo
        newSwarmInfo.finalAvatarData.share()
            .subscribe { [weak self] image in
                if let image = image {
                    self?.profileImageData.accept(image)
                }
            } onError: { _ in
            }
            .disposed(by: conversationBindingsDisposeBag)
        newSwarmInfo.finalTitle.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] name in
                self?.displayName.accept(name)
            } onError: { _ in
            }
            .disposed(by: conversationBindingsDisposeBag)
        newSwarmInfo.participantsString.share()
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] name in
                self?.userName.accept(name)
            } onError: { _ in
            }
            .disposed(by: conversationBindingsDisposeBag)
        self.avatarProvider = AvatarProvider.from(
            swarmInfo: newSwarmInfo,
            profileService: self.injectionBag.profileService,
            size: .default55
        )
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private func subscribeConversationReady() {
        self.conversationsService.conversationReady
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] conversationId in
                guard let self = self else { return }
                if conversationId == self.conversation.id {
                    if self.shouldCreateSwarmInfo() {
                        self.createSwarmInfo()
                    } else if let swarmInfo = self.swarmInfo,
                              self.avatarProvider.isGroup != !self.conversation.isCoredialog() {
                        self.avatarProvider = AvatarProvider.from(
                            swarmInfo: swarmInfo,
                            profileService: self.injectionBag.profileService,
                            size: .default55
                        )
                        self.swarmInfoChanges.accept(swarmInfo)
                        self.objectWillChange.send()
                    }
                }
            } onError: { _ in
            }
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func subscribeConversationSynchronization() {
        self.conversation?.synchronizing
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] synchronizing in
                self?.isSyncing = synchronizing
            })
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func subscribeNonSwarmProfiles(uri: String, accountId: String) {
        self.profileService
            .getProfile(uri: uri, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe {[weak self] profile in
                guard let self = self else { return }
                self.displayName.accept((profile.alias ?? "").simplified())
                self.profileImageData.accept(profile.photo?.toImageData())
            } onError: { _ in
            }
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func subscribeUserServiceLookupStatus() {
        let contact = self.contactsService.contact(withHash: self.conversation.getParticipants().first?.jamiId ?? "")

        self.nameService
            .usernameLookupStatus
            .filter({ [weak self] lookupNameResponse in
                return lookupNameResponse.requestedName != nil &&
                    lookupNameResponse.requestedName == self?.conversation.getParticipants().first?.jamiId
            })
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if let name = lookupNameResponse.name, !name.isEmpty {
                    self?.userName.accept(name)
                    contact?.userName = name
                } else if let address = lookupNameResponse.requestedName {
                    self?.userName.accept(address)
                }
            })
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func setupPresence() {
        if !self.conversation.isCoredialog() {
            return
        }

        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
        if let contact = self.contactsService.contact(withHash: jamiId) {
            guard !contact.banned else { return }
            subscribePresence(contactId: jamiId)
        } else if self.isCoreConversationWith(jamiId: jamiId) {
            subscribeToContactAdded()
        }
    }

    private func subscribePresence(contactId: String) {
        if let contactPresence = self.presenceService.getSubscriptionsForContact(contactId: contactId) {
            self.contactPresence = contactPresence
            self.contactPresence
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] presence in
                    self?.presence = presence
                })
                .disposed(by: conversationBindingsDisposeBag)
        }
    }

    private func subscribeToContactAdded() {
        self.contactsService.sharedResponseStream
            .filter { [weak self] event in
                guard let self = self else { return false }
                return event.eventType == .contactAdded &&
                    event.getEventInput(.conversationId) == self.conversation.id
            }
            .take(1)
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let peerUri: String = event.getEventInput(.peerUri),
                      self.isCoreConversationWith(jamiId: peerUri) else { return }
                self.setupPresence()
            })
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func subscribeUnreadMessages() {
        messageUnreadCount = conversation.unreadMessagesCount
        updateUnreadCount()
        self.conversation.numberOfUnreadMessages
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] unreadMessages in
                guard let self = self else { return }
                self.messageUnreadCount = unreadMessages
                self.updateUnreadCount()
            } onError: { _ in
            }
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func subscribeUnreadDocuments() {
        collaborationService
            .unreadDocumentCount(forAccount: conversation.accountId,
                                 conversationId: conversation.id)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] count in
                guard let self = self else { return }
                self.documentUnreadCount = count
                self.updateUnreadCount()
            })
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func updateUnreadCount() {
        unreadMessages = messageUnreadCount + documentUnreadCount
    }

    private func subscribeIncomingCalls() {
        let conversation: ConversationModel = self.conversation
        callService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] accountTrackers in
                let incomingCalls = accountTrackers[conversation.accountId]?
                    .incomingNotAcceptedCalls(for: conversation.id) ?? []
                self?.hasIncomingCall = !incomingCalls.isEmpty
            })
            .disposed(by: conversationBindingsDisposeBag)
    }

    private func subscribeLastMessage() {
        let conversation: ConversationModel = self.conversation
        conversationsService.readMessages(of: conversation) { [weak self, weak conversation] snapshot in
            DispatchQueue.main.async {
                guard let self = self, let conversation = conversation,
                      self.conversation === conversation else { return }
                conversation.newMessages
                    .startWith(LoadedMessages(messages: snapshot, fromHistory: true, reset: snapshot.isEmpty))
                    .observe(on: MainScheduler.instance)
                    .subscribe(onNext: { [weak self] messages in
                        self?.lastMessageCandidates(messages)
                    })
                    .disposed(by: self.conversationBindingsDisposeBag)
            }
        }
    }

    private func lastMessageCandidates(_ messages: LoadedMessages) {
        if messages.reset {
            lastMessageIds = []
            return
        }
        let hadMessages = !lastMessageIds.isEmpty
        let newMessages = messages.messages.filter { !lastMessageIds.contains($0.id) }
        lastMessageIds.formUnion(newMessages.map { $0.id })
        guard let newest = newMessages.first,
              !(hadMessages && messages.fromHistory) else { return }
        showLastMessage(newest)
    }

    private func showLastMessage(_ message: MessageModel) {
        lastMessageDisposeBag = DisposeBag()
        lastMessageAuthor = nil
        lastMessageDate = message.receivedDate.conversationTimestamp()

        guard message.type.isContact else {
            lastMessage = message.isMessageDeleted()
                ? L10n.Conversation.lastMessageDeleted
                : MessageMarkdown.displayText(from: message.content)
            return
        }
        guard message.incoming else {
            lastMessage = message.content
            return
        }
        let jamiId = message.uri.isEmpty ? message.authorId : message.uri
        let localJamiId = accountService.getAccount(fromAccountId: conversation.accountId)?.jamiId
        let isLocal = jamiId == localJamiId
        lastMessage = message.getContactInteractionString(name: jamiId) ?? ""
        guard let author = ParticipantInfo.loaded(jamiId: jamiId, role: .unknown,
                                                  accountId: conversation.accountId,
                                                  isLocal: isLocal,
                                                  injectionBag: injectionBag) else { return }
        lastMessageAuthor = author
        author.finalName
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                let displayedName = isLocal ? name.withYourselfSuffix() : name
                self?.lastMessage = message.getContactInteractionString(name: displayedName) ?? ""
            })
            .disposed(by: lastMessageDisposeBag)
    }
}

extension ConversationRowVM: Equatable {
    static func == (lhs: ConversationRowVM, rhs: ConversationRowVM) -> Bool {
        lhs.conversation == rhs.conversation
    }
}
// swiftlint:enable type_body_length
