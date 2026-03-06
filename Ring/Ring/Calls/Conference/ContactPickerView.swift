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

import SwiftUI
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
        vm.type = callId.isEmpty ? .forConversation : .forCall
        vm.currentCallId = callId
        vm.contactSelectedCB = contactSelectedCB
        vm.conversationSelectedCB = conversationSelectedCB
        vm.bind()

        var dismiss: () -> Void = {}
        let pickerView = ContactPickerView(viewModel: vm, onDismiss: { dismiss() })

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

// MARK: - Main SwiftUI View

struct ContactPickerView: View {
    @ObservedObject var viewModel: ContactPickerViewModel
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

                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(viewModel.type == .forConversation
                             ? L10n.Swarm.selectContacts
                             : L10n.Smartlist.searchBarPlaceholder)
            .applySearchable(text: $viewModel.searchText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.cancel) {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.type == .forConversation {
                        Button(L10n.DataTransfer.sendMessage) {
                            viewModel.confirmConversationSelection()
                            onDismiss()
                        }
                        .font(.body.weight(.semibold))
                        .opacity(viewModel.selectedConversationIds.isEmpty ? 0.35 : 1.0)
                        .disabled(viewModel.selectedConversationIds.isEmpty)
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
            TextField(L10n.Smartlist.searchBarPlaceholder, text: $viewModel.searchText)
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
        if viewModel.hasNoResults {
            emptyStateView
                .transition(.opacity)
        } else {
            switch viewModel.type {
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

            Image(systemName: viewModel.isSearchActive ? "magnifyingglass" : "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            Text(viewModel.isSearchActive
                 ? L10n.Smartlist.noResults
                 : L10n.Smartlist.noConversation)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.isSearchActive ? .secondary : .primary)

            if viewModel.isSearchActive {
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
            ForEach(viewModel.contactSections) { section in
                Section(header: Text(section.header)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textCase(nil)
                ) {
                    ForEach(section.items) { item in
                        Button {
                            viewModel.selectContact(item)
                            onDismiss()
                        } label: {
                            ContactRowView(item: item)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .hideRowSeparator()
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: Conversation List (forConversation)

    private var conversationList: some View {
        List {
            ForEach(viewModel.conversationSections) { section in
                ForEach(section.items) { swarmInfo in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleConversationSelection(swarmInfo.id)
                        }
                    } label: {
                        ContactPickerConversationRow(
                            isSelected: viewModel.selectedConversationIds.contains(swarmInfo.id),
                            avatar: viewModel.conversationAvatarProviders[swarmInfo.id]
                                ?? AvatarProvider(profileService: viewModel.profileService, size: .medium45)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .hideRowSeparator()
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Contact Row View

private struct ContactRowView: View {
    let item: ConferencableItem
    @ObservedObject var avatar: AvatarProvider
    @StateObject private var presenceTracker: ContactPresenceTracker

    init(item: ConferencableItem) {
        self.item = item
        self.avatar = item.avatarProvider
        // ConferencableItem is always constructed with at least one contact.
        _presenceTracker = StateObject(wrappedValue: ContactPresenceTracker(contact: item.contacts[0]))
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarSwiftUIView(source: avatar)

            Text(displayName)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if item.contacts.count == 1, presenceTracker.isOnline {
                Circle()
                    .fill(Color(presenceTracker.presenceColor))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
    let isSelected: Bool
    @ObservedObject var avatar: AvatarProvider

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
    @Published var isOnline = false
    @Published var presenceColor: UIColor = .clear

    private var disposeBag = DisposeBag()

    init(contact: Contact) {
        subscribe(to: contact.presenceStatus)
    }

    private func subscribe(to relay: BehaviorRelay<PresenceStatus>?) {
        guard let relay = relay else { return }
        relay
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
