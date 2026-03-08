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

enum ContactPickerType {
    case forConversation
    case forCall
}

protocol ContactPickerDismissHandler: AnyObject {
    func contactPickerDidDismiss()
}


struct ContactPickerView: View {
    @ObservedObject var viewModel: ContactPickerViewModel
    @Environment(\.presentationMode) private var presentationMode
    var onDismissed: (() -> Void)?

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
            .applySearchable(text: $viewModel.searchText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(UIColor.label))
                }
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.type == .forConversation {
                        Button(L10n.DataTransfer.sendMessage) {
                            viewModel.confirmConversationSelection()
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.jamiColor)
                        .font(.body.weight(.semibold))
                        .opacity(viewModel.selectedConversationIds.isEmpty ? 0.35 : 1.0)
                        .disabled(viewModel.selectedConversationIds.isEmpty)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onDisappear { onDismissed?() }
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

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)

            Text(L10n.Smartlist.noResults)
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

    private var contactList: some View {
        List {
            ForEach(viewModel.contactSections) { section in
                Section(header: Text(section.header)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .textCase(nil)
                ) {
                    ForEach(section.items) { item in
                        Button {
                            viewModel.selectContact(item)
                            presentationMode.wrappedValue.dismiss()
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
                            avatarSource: viewModel.conversationAvatarProviders[swarmInfo.id]
                                ?? AvatarProvider(profileService: viewModel.profileService, size: .medium45),
                            presenceTracker: viewModel.conversationPresenceTrackers[swarmInfo.id]
                                ?? ConversationPresenceTracker(jamiId: "", presenceService: viewModel.presenceService)
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
    @ObservedObject private var avatarSource: AvatarProvider
    @StateObject private var presenceTracker: ContactPresenceTracker

    init(item: ConferencableItem) {
        self.item = item
        self.avatarSource = item.avatarProvider
        _presenceTracker = StateObject(wrappedValue: ContactPresenceTracker(contact: item.contacts[0]))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarSwiftUIView(source: avatarSource)
                if item.contacts.count == 1 {
                    presenceIndicator
                }
            }

            Text(avatarSource.profileName)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var presenceIndicator: some View {
        switch presenceTracker.presenceStatus {
        case .connected:
            presenceCircle(color: .onlinePresenceColor)
        case .available:
            presenceCircle(color: .availablePresenceColor)
        default:
            EmptyView()
        }
    }

    private func presenceCircle(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle().stroke(Color(UIColor.systemBackground), lineWidth: 1)
            )
            .offset(x: -1, y: 0)
    }
}

// MARK: - Conversation Row View

private struct ContactPickerConversationRow: View {
    let isSelected: Bool
    @ObservedObject private var avatarSource: AvatarProvider
    @ObservedObject private var presenceTracker: ConversationPresenceTracker

    init(isSelected: Bool, avatarSource: AvatarProvider, presenceTracker: ConversationPresenceTracker) {
        self.isSelected = isSelected
        self.avatarSource = avatarSource
        self.presenceTracker = presenceTracker
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarSwiftUIView(source: avatarSource)
                presenceIndicator
            }

            Text(avatarSource.profileName)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .truncationMode(.middle)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.jamiColor)
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

    @ViewBuilder
    private var presenceIndicator: some View {
        switch presenceTracker.presenceStatus {
        case .connected:
            presenceCircle(color: .onlinePresenceColor)
        case .available:
            presenceCircle(color: .availablePresenceColor)
        default:
            EmptyView()
        }
    }

    private func presenceCircle(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle().stroke(Color(UIColor.systemBackground), lineWidth: 1)
            )
            .offset(x: -1, y: 0)
    }
}

// MARK: - Presence Tracker

private final class ContactPresenceTracker: ObservableObject {
    @Published var presenceStatus: PresenceStatus = .offline

    private var disposeBag = DisposeBag()

    init(contact: Contact) {
        guard let relay = contact.presenceStatus else { return }
        relay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                self?.presenceStatus = status
            })
            .disposed(by: disposeBag)
    }
}

/// Presence tracker for a conversation's peer, used in conversation rows.
final class ConversationPresenceTracker: ObservableObject {
    @Published var presenceStatus: PresenceStatus = .offline

    private var disposeBag = DisposeBag()

    init(jamiId: String, presenceService: PresenceService) {
        guard let relay = presenceService.getSubscriptionsForContact(contactId: jamiId) else { return }
        relay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                self?.presenceStatus = status
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
