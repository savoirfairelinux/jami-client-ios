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
    @Published var conversations: [SwarmInfo] = []
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
    private(set) var conversationPresenceTrackers: [String: PresenceTracker] = [:]
    private let disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()

    private let contactsService: ContactsService
    private let conversationsService: ConversationsService
    private let callService: CallService
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
        let contactsObservable = contactsService.contacts.asObservable()
            .map { [weak self] contacts -> [ContactPickerSection] in
                guard let self = self else { return [] }
                return self.buildContactSections(contacts: contacts)
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
            if let conversation = swarmInfo.conversation, conversation.isCoredialog(),
               let peerJamiId = swarmInfo.nonLocalParticipants.first?.jamiId {
                conversationPresenceTrackers[swarmInfo.id] = PresenceTracker(
                    jamiId: peerJamiId,
                    presenceService: presenceService
                )
            }
        }

        self.conversations = conversations
        isLoading = false

        $searchText
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] query in
                guard let self = self else { return }
                self.conversations = self.filterConversations(conversations, query: query)
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

    private func filterConversations(_ conversations: [SwarmInfo], query: String) -> [SwarmInfo] {
        guard !query.isEmpty else { return conversations }
        return conversations.filter { $0.contains(searchQuery: query) }
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
            return conversations.isEmpty
        }
    }
}

// MARK: - Section Builders

private extension ContactPickerViewModel {

    func buildContactSections(contacts: [ContactModel]) -> [ContactPickerSection] {
        var sections = [ContactPickerSection]()
        let contactItems = buildContactItems(from: contacts)
        if !contactItems.isEmpty {
            sections.append(ContactPickerSection(header: L10n.ContactPicker.contacts, items: contactItems))
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

}
