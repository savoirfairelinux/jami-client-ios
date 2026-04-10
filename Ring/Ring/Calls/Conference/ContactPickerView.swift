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
                    .foregroundColor(.jamiColor)
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
                ) {
                    ForEach(section.items) { item in
                        Button {
                            viewModel.selectContact(item)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            ContactRowView(item: item)
                        }
                        .pickerRowStyle()
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { swarmInfo in
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
                            ?? PresenceTracker(relay: nil)
                    )
                }
                .pickerRowStyle()
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Avatar with Presence

/// Combines avatar image with an overlapping presence indicator.
private struct AvatarWithPresence: View {
    @ObservedObject var avatarSource: AvatarProvider
    @ObservedObject var presenceTracker: PresenceTracker

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarSwiftUIView(source: avatarSource)
            switch presenceTracker.status {
            case .connected:
                presenceCircle(color: .onlinePresenceColor)
            case .available:
                presenceCircle(color: .availablePresenceColor)
            default:
                EmptyView()
            }
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

// MARK: - Contact Row View

private struct ContactRowView: View {
    let item: ConferencableItem
    @ObservedObject private var avatarSource: AvatarProvider
    @StateObject private var presenceTracker: PresenceTracker

    init(item: ConferencableItem) {
        self.item = item
        self.avatarSource = item.avatarProvider
        _presenceTracker = StateObject(wrappedValue: PresenceTracker(contact: item.contacts[0]))
    }

    var body: some View {
        HStack(spacing: 12) {
            if item.contacts.count == 1 {
                AvatarWithPresence(avatarSource: avatarSource, presenceTracker: presenceTracker)
            } else {
                AvatarSwiftUIView(source: avatarSource)
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
}

// MARK: - Conversation Row View

private struct ContactPickerConversationRow: View {
    let isSelected: Bool
    @ObservedObject private var avatarSource: AvatarProvider
    @ObservedObject private var presenceTracker: PresenceTracker

    init(isSelected: Bool, avatarSource: AvatarProvider, presenceTracker: PresenceTracker) {
        self.isSelected = isSelected
        self.avatarSource = avatarSource
        self.presenceTracker = presenceTracker
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarWithPresence(avatarSource: avatarSource, presenceTracker: presenceTracker)

            Text(avatarSource.profileName)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(isSelected ? .jamiColor : .secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Presence Tracker

final class PresenceTracker: ObservableObject {
    @Published var status: PresenceStatus = .offline

    private var disposeBag = DisposeBag()

    init(relay: BehaviorRelay<PresenceStatus>?) {
        guard let relay = relay else { return }
        relay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                self?.status = status
            })
            .disposed(by: disposeBag)
    }

    convenience init(contact: Contact) {
        self.init(relay: contact.presenceStatus)
    }

    convenience init(jamiId: String, presenceService: PresenceService) {
        self.init(relay: presenceService.getSubscriptionsForContact(contactId: jamiId))
    }
}

// MARK: - View Modifiers

private extension View {
    func pickerRowStyle() -> some View {
        self
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .hideRowSeparator()
    }

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
