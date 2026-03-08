/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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

import RxSwift
import RxRelay
import Combine

final class ContactPickerViewModel: ObservableObject, ViewModel {

    // MARK: - Published State

    @Published var searchText: String = ""
    @Published var contactSections: [ContactPickerSection] = []
    @Published var conversationSections: [ConversationPickerSection] = []
    @Published var isLoading: Bool = true
    @Published var selectedConversationIds: Set<String> = []

    // MARK: - Configuration

    var type: ContactPickerType = .forCall
    var currentCallId = ""
    var contactSelectedCB: (([ConferencableItem]) -> Void)?
    var conversationSelectedCB: (([String]) -> Void)?
    let injectionBag: InjectionBag

    // MARK: - Private

    private var unfilteredContactSections: [ContactPickerSection] = []
    private(set) var conversationAvatarProviders: [String: AvatarProvider] = [:]
    /// Presence trackers for 1:1 conversations, keyed by conversation id.
    private(set) var conversationPresenceTrackers: [String: ConversationPresenceTracker] = [:]
    private let disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()

    private let contactsService: ContactsService
    private let conversationsService: ConversationsService
    private let callService: CallsService
    let profileService: ProfilesService
    private let accountService: AccountsService
    let presenceService: PresenceService
    private let nameService: NameService

    // MARK: - Init

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.callService = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.presenceService = injectionBag.presenceService
        self.nameService = injectionBag.nameService
        self.conversationsService = injectionBag.conversationsService
        self.injectionBag = injectionBag
    }

    func bind() {
        switch type {
        case .forCall:
            bindContactSections()
        case .forConversation:
            bindConversationSections()
        }
    }

    private func bindContactSections() {
        // Combine contacts with active calls to show both sections.
        let contactsObservable = Observable
            .combineLatest(
                contactsService.contacts.asObservable(),
                callService.calls.observable
            ) { [weak self] contacts, calls -> [ContactPickerSection] in
                guard let self = self else { return [] }
                return self.buildContactAndCallSections(contacts: contacts, calls: calls)
            }

        contactsObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] sections in
                guard let self = self else { return }
                self.unfilteredContactSections = sections
                self.contactSections = self.filterContactSections(sections, query: self.searchText)
                self.isLoading = false
            })
            .disposed(by: disposeBag)

        // Re-filter when search text changes.
        $searchText
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] query in
                guard let self = self else { return }
                self.contactSections = self.filterContactSections(self.unfilteredContactSections, query: query)
            }
            .store(in: &cancellables)
    }

    private func bindConversationSections() {
        let conversations = conversationsService.conversations.value
            .compactMap { SwarmInfo(injectionBag: self.injectionBag, conversation: $0) }

        for swarmInfo in conversations {
            conversationAvatarProviders[swarmInfo.id] = AvatarProvider.from(
                swarmInfo: swarmInfo,
                profileService: profileService,
                size: .medium45
            )
            // Track presence for 1:1 (dialog) conversations.
            if let conversation = swarmInfo.conversation, conversation.isDialog(),
               let peerJamiId = swarmInfo.nonLocalParticipants.first?.jamiId {
                conversationPresenceTrackers[swarmInfo.id] = ConversationPresenceTracker(
                    jamiId: peerJamiId,
                    presenceService: presenceService
                )
            }
        }

        let section = ConversationPickerSection(items: conversations)
        conversationSections = [section]
        isLoading = false

        // Filter when search text changes.
        $searchText
            .removeDuplicates()
            .sink { [weak self, allSections = [section]] query in
                guard let self = self else { return }
                self.conversationSections = self.filterConversationSections(allSections, query: query)
            }
            .store(in: &cancellables)
    }

    // MARK: - Filtering

    private func filterContactSections(_ sections: [ContactPickerSection], query: String) -> [ContactPickerSection] {
        guard !query.isEmpty else { return sections }
        let lowered = query.lowercased()
        return sections.compactMap { section in
            let filtered = section.items.compactMap { item -> ConferencableItem? in
                var copy = item
                copy.contacts = item.contacts.filter { contact in
                    contact.firstLine.value.lowercased().contains(lowered)
                        || contact.secondLine.lowercased().contains(lowered)
                        || contact.hash.lowercased().contains(lowered)
                }
                return copy.contacts.isEmpty ? nil : copy
            }
            guard !filtered.isEmpty else { return nil }
            return ContactPickerSection(header: section.header, items: filtered)
        }
    }

    private func filterConversationSections(_ sections: [ConversationPickerSection], query: String) -> [ConversationPickerSection] {
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            let filtered = section.items.filter { $0.contains(searchQuery: query) }
            guard !filtered.isEmpty else { return nil }
            return ConversationPickerSection(items: filtered)
        }
    }

    // MARK: - Actions

    func selectContact(_ item: ConferencableItem) {
        contactSelectedCB?([item])
    }

    func toggleConversationSelection(_ id: String) {
        if selectedConversationIds.contains(id) {
            selectedConversationIds.remove(id)
        } else {
            selectedConversationIds.insert(id)
        }
    }

    func confirmConversationSelection() {
        conversationSelectedCB?(Array(selectedConversationIds))
    }

    // MARK: - Computed Properties

    var isSearchActive: Bool {
        !searchText.isEmpty
    }

    var hasNoResults: Bool {
        guard !isLoading else { return false }
        switch type {
        case .forCall:
            return contactSections.allSatisfy { $0.items.isEmpty }
        case .forConversation:
            return conversationSections.allSatisfy { $0.items.isEmpty }
        }
    }
}

// MARK: - Section Builders

private extension ContactPickerViewModel {

    func buildContactAndCallSections(contacts: [ContactModel], calls: [String: CallModel]) -> [ContactPickerSection] {
        guard callService.call(callID: currentCallId) != nil else { return [] }
        var sections = [ContactPickerSection]()
        let callURIs = appendCallSection(from: calls, to: &sections)
        let contactItems = buildContactItems(from: contacts, excluding: callURIs)
        if !contactItems.isEmpty {
            sections.append(ContactPickerSection(header: "contacts", items: contactItems))
        }
        return sections
    }

    func buildContactItems(from contacts: [ContactModel], excluding uris: [String] = []) -> [ConferencableItem] {
        guard let currentAccount = accountService.currentAccount else { return [] }
        let excludeSet = Set(uris)
        return contacts.compactMap { contact in
            guard let contactUri = contact.uriString, !excludeSet.contains(contactUri) else { return nil }
            let contactObj = Contact(
                contactUri: contactUri,
                accountId: currentAccount.id,
                registeredName: contact.userName ?? "",
                presService: presenceService,
                nameService: nameService,
                hash: contact.hash,
                profileService: profileService
            )
            let avatar = AvatarProvider(
                profileService: profileService,
                size: .medium45,
                avatar: contactObj.imageData.asObservable(),
                displayName: contactObj.firstLine.asObservable(),
                isGroup: false
            )
            return ConferencableItem(conferenceID: "", contacts: [contactObj], avatarProvider: avatar)
        }
    }

    func appendCallSection(from calls: [String: CallModel], to sections: inout [ContactPickerSection]) -> [String] {
        guard let currentCall = callService.call(callID: currentCallId) else { return [] }
        var callURIs = [String]()
        var callItems = [ConferencableItem]()
        var conferences = [String: [Contact]]()

        for call in calls.values {
            guard let account = accountService.getAccount(fromAccountId: call.accountId) else { continue }
            let uriType: URIType = account.type == AccountType.ring ? .ring : .sip
            let uri = JamiURI(schema: uriType, infoHash: call.callUri, account: account)
            guard let uriString = uri.uriString, let hashString = uri.hash else { continue }

            callURIs.append(uriString)

            // Skip calls already in the current conference or the current call itself.
            if currentCall.participantsCallId.contains(call.callId) || call.callId == currentCallId {
                continue
            }
            guard call.state == .current || call.state == .hold else { continue }

            let contact = Contact(
                contactUri: uriString,
                accountId: call.accountId,
                registeredName: call.registeredName,
                presService: presenceService,
                nameService: nameService,
                hash: hashString,
                profileService: profileService
            )

            if call.participantsCallId.count == 1 {
                let avatar = AvatarProvider(
                    profileService: profileService,
                    size: .medium45,
                    avatar: contact.imageData.asObservable(),
                    displayName: contact.firstLine.asObservable(),
                    isGroup: false
                )
                callItems.append(ConferencableItem(conferenceID: call.callId, contacts: [contact], avatarProvider: avatar))
            } else {
                conferences[call.callId, default: []].append(contact)
            }
        }

        for (conferenceID, contacts) in conferences {
            // Combine all participant names reactively for the display name.
            let nameStreams = contacts.map { $0.firstLine.asObservable() }
            let combinedName = Observable.combineLatest(nameStreams) { names in
                names.joined(separator: ", ")
            }
            let avatar = AvatarProvider(
                profileService: profileService,
                size: .medium45,
                avatar: contacts[0].imageData.asObservable(),
                displayName: combinedName,
                isGroup: true
            )
            callItems.append(ConferencableItem(conferenceID: conferenceID, contacts: contacts, avatarProvider: avatar))
        }

        if !callItems.isEmpty {
            callItems.sort { $0.contacts.count > $1.contacts.count }
            sections.append(ContactPickerSection(header: "calls", items: callItems))
        }
        return callURIs
    }
}
