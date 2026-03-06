/*
 * Copyright (C) 2019-2025 Savoir-faire Linux Inc.
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
import SwiftUI
import Combine
import RxSwift
import RxRelay

// MARK: - Types

enum ContactPickerType {
    case forConversation
    case forCall
}

/// Optional protocol for presenters that need to react when the picker is dismissed.
protocol ContactPickerDismissHandler: AnyObject {
    func contactPickerDidDismiss()
}

// MARK: - Hosting Controller Factory

extension ContactPickerView {
    /// Creates a ready-to-present `UIHostingController` for the contact picker.
    static func makeHostingController(
        injectionBag: InjectionBag,
        callId: String,
        contactSelectedCB: (([ConferencableItem]) -> Void)? = nil,
        conversationSelectedCB: (([String]) -> Void)? = nil,
        onDismissed: (() -> Void)? = nil
    ) -> UIHostingController<ContactPickerView> {
        let vm = ContactPickerViewModel(with: injectionBag)
        let type: ContactPickerType = callId.isEmpty ? .forConversation : .forCall
        vm.currentCallId = callId
        vm.contactSelectedCB = contactSelectedCB
        vm.conversationSelectedCB = conversationSelectedCB

        let state = ContactPickerViewState(viewModel: vm, type: type)

        var dismiss: () -> Void = {}
        let pickerView = ContactPickerView(state: state, onDismiss: { dismiss() })

        let hostingController = UIHostingController(rootView: pickerView)
        hostingController.modalPresentationStyle = .pageSheet

        // Wire up dismiss to the hosting controller.
        dismiss = { [weak hostingController] in
            hostingController?.dismiss(animated: true) {
                onDismissed?()
            }
        }

        return hostingController
    }
}

// MARK: - Observable ViewModel Wrapper

/// Bridges the existing RxSwift-based ContactPickerViewModel into SwiftUI's
/// ObservableObject world.  Subscribes to the reactive streams and publishes
/// plain Swift arrays that the SwiftUI view can consume directly.
final class ContactPickerViewState: ObservableObject {

    // MARK: Published state

    @Published var searchText: String = ""
    @Published var contactSections: [ContactPickerSection] = []
    @Published var conversationSections: [ConversationPickerSection] = []
    @Published var isLoading: Bool = true

    // For-conversation mode: tracks selected conversation IDs.
    @Published var selectedConversationIds: Set<String> = []

    // MARK: Dependencies

    let viewModel: ContactPickerViewModel
    let type: ContactPickerType
    private let disposeBag = DisposeBag()

    // MARK: Init

    init(viewModel: ContactPickerViewModel, type: ContactPickerType) {
        self.viewModel = viewModel
        self.type = type
        bind()
    }

    // MARK: Bindings

    private func bind() {
        // Push search text into the RxSwift subject whenever it changes.
        $searchText
            .removeDuplicates()
            .sink { [weak self] text in
                self?.viewModel.search.onNext(text)
            }
            .store(in: &cancellables)

        // Loading state
        viewModel.loading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] loading in
                self?.isLoading = loading
            })
            .disposed(by: disposeBag)

        // Bind appropriate data source based on type.
        switch type {
        case .forCall:
            viewModel.searchResultItems
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] sections in
                    self?.contactSections = sections
                })
                .disposed(by: disposeBag)
        case .forConversation:
            viewModel.conversationsSearchResultItems
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] sections in
                    self?.conversationSections = sections
                })
                .disposed(by: disposeBag)
        }
    }

    // Combine cancellables (used for $searchText sink)
    private var cancellables = Set<AnyCancellable>()

    // MARK: Actions

    func selectContact(_ item: ConferencableItem) {
        viewModel.contactSelected(contacts: [item])
    }

    func toggleConversationSelection(_ id: String) {
        if selectedConversationIds.contains(id) {
            selectedConversationIds.remove(id)
        } else {
            selectedConversationIds.insert(id)
        }
    }

    func confirmConversationSelection() {
        viewModel.conversationSelected(conversaionIds: Array(selectedConversationIds))
    }

    var profileService: ProfilesService {
        viewModel.injectionBag.profileService
    }

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

// MARK: - Main SwiftUI View

struct ContactPickerView: View {
    @ObservedObject var state: ContactPickerViewState
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    if #unavailable(iOS 15) {
                        legacySearchBar
                    }
                    contentList
                }

                if state.isLoading {
                    loadingOverlay
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(state.type == .forConversation
                             ? L10n.Swarm.selectContacts
                             : L10n.Smartlist.searchBarPlaceholder)
            .applySearchable(text: $state.searchText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.cancel) {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if state.type == .forConversation {
                        Button(L10n.DataTransfer.sendMessage) {
                            state.confirmConversationSelection()
                            onDismiss()
                        }
                        .font(.body.weight(.semibold))
                        .opacity(state.selectedConversationIds.isEmpty ? 0.35 : 1.0)
                        .disabled(state.selectedConversationIds.isEmpty)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Legacy Search Bar (iOS 14)

    private var legacySearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(.tertiaryLabel))
            TextField(L10n.Smartlist.searchBarPlaceholder, text: $state.searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .overlay(
            Capsule().stroke(Color(.quaternaryLabel), lineWidth: 1)
        )
        .padding()
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()
            SwiftUI.ProgressView()
                .scaleEffect(1.2)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground).opacity(0.9))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                )
        }
        .transition(.opacity)
    }

    // MARK: - Content List

    @ViewBuilder
    private var contentList: some View {
        if state.hasNoResults {
            emptyStateView
                .transition(.opacity)
        } else {
            switch state.type {
            case .forCall:
                contactList
            case .forConversation:
                conversationList
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: state.isSearchActive ? "magnifyingglass" : "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            Text(state.isSearchActive
                 ? L10n.Smartlist.noResults
                 : L10n.Smartlist.noConversation)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(state.isSearchActive ? .secondary : .primary)

            if state.isSearchActive {
                Text(L10n.Smartlist.noConversationsFound)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: Contact List (forCall)

    private var contactList: some View {
        List {
            ForEach(Array(state.contactSections.enumerated()), id: \.offset) { _, section in
                Section(header: Text(section.header)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textCase(nil)
                ) {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        Button {
                            state.selectContact(item)
                            onDismiss()
                        } label: {
                            ContactRowView(item: item)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: Conversation List (forConversation)

    private var conversationList: some View {
        List {
            ForEach(Array(state.conversationSections.enumerated()), id: \.offset) { _, section in
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, swarmInfo in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.toggleConversationSelection(swarmInfo.id)
                        }
                    } label: {
                        ContactPickerConversationRow(
                            swarmInfo: swarmInfo,
                            isSelected: state.selectedConversationIds.contains(swarmInfo.id),
                            profileService: state.profileService
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 15, bottom: 4, trailing: 15))
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Contact Row View

private struct ContactRowView: View {
    let item: ConferencableItem

    @StateObject private var avatar: AvatarProvider
    @StateObject private var presenceTracker: ContactPresenceTracker

    init(item: ConferencableItem) {
        self.item = item
        let contact = item.contacts.first!
        _avatar = StateObject(wrappedValue: AvatarProvider(
            profileService: contact.profileService,
            size: .medium40,
            avatar: contact.imageData.asObservable(),
            displayName: contact.firstLine.asObservable(),
            isGroup: item.contacts.count > 1
        ))
        _presenceTracker = StateObject(wrappedValue: ContactPresenceTracker(contact: contact))
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarSwiftUIView(source: avatar)

            Text(displayName)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .truncationMode(.middle)
                .lineLimit(1)

            Spacer()

            if item.contacts.count == 1, presenceTracker.isOnline {
                Circle()
                    .fill(Color(presenceTracker.presenceColor))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var displayName: String {
        if item.contacts.count > 1 {
            return item.contacts.map { $0.firstLine.value }.joined(separator: ", ")
        }
        return avatar.profileName.isEmpty ? avatar.jamiId : avatar.profileName
    }
}

// MARK: - Conversation Row View

private struct ContactPickerConversationRow: View {
    let swarmInfo: SwarmInfo
    let isSelected: Bool

    @StateObject private var avatar: AvatarProvider

    init(swarmInfo: SwarmInfo, isSelected: Bool, profileService: ProfilesService) {
        self.swarmInfo = swarmInfo
        self.isSelected = isSelected
        _avatar = StateObject(wrappedValue: AvatarProvider.from(
            swarmInfo: swarmInfo,
            profileService: profileService,
            size: .medium40
        ))
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarSwiftUIView(source: avatar)

            Text(!avatar.profileName.isEmpty ? avatar.profileName : avatar.jamiId)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .truncationMode(.middle)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Presence Tracker

/// Lightweight observer for contact presence status.
private final class ContactPresenceTracker: ObservableObject {
    @Published var isOnline: Bool = false
    @Published var presenceColor: UIColor = .clear

    private let disposeBag = DisposeBag()

    init(contact: Contact) {
        guard let presenceStatus = contact.presenceStatus else { return }
        presenceStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                self?.isOnline = status != .offline
                switch status {
                case .connected:
                    self?.presenceColor = .onlinePresenceColor
                case .available:
                    self?.presenceColor = .availablePresenceColor
                default:
                    self?.presenceColor = .clear
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Searchable Compatibility

private extension View {
    @ViewBuilder
    func applySearchable(text: Binding<String>) -> some View {
        if #available(iOS 15.0, *) {
            self.searchable(
                text: text,
                prompt: L10n.Smartlist.searchBarPlaceholder
            )
            .autocorrectionDisabled()
        } else {
            self
        }
    }
}
