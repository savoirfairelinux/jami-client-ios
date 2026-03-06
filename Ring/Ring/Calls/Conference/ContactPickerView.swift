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

    var doneButtonTitle: String {
        selectedConversationIds.isEmpty ? L10n.Global.cancel : L10n.DataTransfer.sendMessage
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
                    searchBar
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(state.doneButtonTitle) {
                        if state.type == .forConversation && !state.selectedConversationIds.isEmpty {
                            state.confirmConversationSelection()
                        }
                        onDismiss()
                    }
                    .font(.body.weight(
                        state.type == .forConversation && !state.selectedConversationIds.isEmpty
                            ? .semibold : .regular
                    ))
                    .foregroundColor(Color(UIColor.jamiTextBlue))
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 15))
            TextField(L10n.Smartlist.searchBarPlaceholder, text: $state.searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.body)
            if !state.searchText.isEmpty {
                Button {
                    state.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.tertiaryLabel))
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
        VStack(spacing: 12) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                Image(systemName: state.isSearchActive ? "magnifyingglass" : "person.2")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.bottom, 4)

            Text(state.isSearchActive
                 ? L10n.Smartlist.noResults
                 : L10n.Smartlist.noConversation)
                .font(.headline)
                .foregroundColor(.secondary)

            if state.isSearchActive {
                Text(L10n.Smartlist.noConversationsFound)
                    .font(.subheadline)
                    .foregroundColor(Color(.tertiaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
                            isSelected: state.selectedConversationIds.contains(swarmInfo.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Contact Row View

private struct ContactRowView: View {
    let item: ConferencableItem

    @StateObject private var avatarProvider: ContactAvatarProvider

    init(item: ConferencableItem) {
        self.item = item
        _avatarProvider = StateObject(wrappedValue: ContactAvatarProvider(item: item))
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarView
                .frame(width: 44, height: 44)

            Text(avatarProvider.displayName)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            presenceIndicator
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatarView: some View {
        if item.contacts.count == 1, let avatarImage = avatarProvider.avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            monogramView
        }
    }

    private var monogramView: some View {
        let name = avatarProvider.displayName
        let hex = name.toMD5HexString().prefixString()
        var idxValue: UInt64 = 0
        let colorIndex = Scanner(string: hex).scanHexInt64(&idxValue) ? Int(idxValue) : 0
        let bgColor = avatarColors[colorIndex]

        return ZStack {
            Circle()
                .fill(Color(bgColor))
            if !name.isSHA1() && !name.isEmpty && item.contacts.count <= 1 {
                Text(MonogramHelper.extractFirstGraphemeCluster(from: name))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: item.contacts.count > 1 ? "person.2.fill" : "person.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private var presenceIndicator: some View {
        if item.contacts.count == 1, avatarProvider.isOnline {
            Circle()
                .fill(Color(avatarProvider.presenceColor))
                .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Conversation Row View

private struct ContactPickerConversationRow: View {
    let swarmInfo: SwarmInfo
    let isSelected: Bool

    @StateObject private var avatarProvider: SwarmAvatarProvider

    init(swarmInfo: SwarmInfo, isSelected: Bool) {
        self.swarmInfo = swarmInfo
        self.isSelected = isSelected
        _avatarProvider = StateObject(wrappedValue: SwarmAvatarProvider(swarmInfo: swarmInfo))
    }

    var body: some View {
        HStack(spacing: 12) {
            selectionCircle

            avatarView
                .frame(width: 44, height: 44)

            Text(avatarProvider.title)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? Color(UIColor.jamiTextBlue) : Color(.systemGray3),
                    lineWidth: isSelected ? 0 : 1.5
                )
                .frame(width: 24, height: 24)

            if isSelected {
                Circle()
                    .fill(Color(UIColor.jamiTextBlue))
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarImage = avatarProvider.avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            swarmMonogramView
        }
    }

    private var swarmMonogramView: some View {
        let name = avatarProvider.title
        let isGroup = !(swarmInfo.conversation?.isDialog() ?? true)
        let hex = name.toMD5HexString().prefixString()
        var idxValue: UInt64 = 0
        let colorIndex = Scanner(string: hex).scanHexInt64(&idxValue) ? Int(idxValue) : 0
        let bgColor = avatarColors[colorIndex]

        return ZStack {
            Circle()
                .fill(Color(bgColor))
            if !name.isSHA1() && !name.isEmpty && !isGroup {
                Text(MonogramHelper.extractFirstGraphemeCluster(from: name))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: isGroup ? "person.2.fill" : "person.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Reactive Avatar Providers

/// Observes a ConferencableItem's contact data via RxSwift and publishes
/// changes to SwiftUI.
private final class ContactAvatarProvider: ObservableObject {
    @Published var displayName: String = ""
    @Published var avatarImage: UIImage?
    @Published var isOnline: Bool = false
    @Published var presenceColor: UIColor = .clear

    private let disposeBag = DisposeBag()

    init(item: ConferencableItem) {
        guard let contact = item.contacts.first else {
            if item.contacts.count > 1 {
                displayName = item.contacts.map { $0.firstLine.value }.joined(separator: ", ")
            }
            return
        }

        // Display name
        contact.firstLine
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard let self = self else { return }
                if item.contacts.count > 1 {
                    self.displayName = item.contacts.map { $0.firstLine.value }.joined(separator: ", ")
                } else {
                    self.displayName = name
                }
            })
            .disposed(by: disposeBag)

        // Avatar image
        contact.imageData
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                if let data = data {
                    self?.avatarImage = UIImage(data: data)
                }
            })
            .disposed(by: disposeBag)

        // Presence
        if let presenceStatus = contact.presenceStatus {
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
}

/// Observes SwarmInfo reactive data and publishes changes to SwiftUI.
private final class SwarmAvatarProvider: ObservableObject {
    @Published var title: String = ""
    @Published var avatarImage: UIImage?

    private let disposeBag = DisposeBag()

    init(swarmInfo: SwarmInfo) {
        swarmInfo.finalTitle
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] title in
                self?.title = title
            })
            .disposed(by: disposeBag)

        swarmInfo.finalAvatarData
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] data in
                if let data = data {
                    self?.avatarImage = UIImage(data: data)
                }
            })
            .disposed(by: disposeBag)
    }
}


