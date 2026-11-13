/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import SwiftUI
import UIKit
import Combine

struct SmartListView: View, StateEmittingView {
    typealias StateEmitterType = ConversationStatePublisher

    @StateObject var model: ConversationsViewModel
    var stateEmitter: ConversationStatePublisher
    @SwiftUI.State var showAccountList = false
    @SwiftUI.State private var coverBackgroundOpacity: CGFloat = 0
    @SwiftUI.State private var activateSearch = false
    @SwiftUI.State private var showingPicker = false
    @SwiftUI.State private var isSharing = false
    @SwiftUI.State private var isNavigatingToSettings = false

    let maxCoverBackgroundOpacity: CGFloat = 0.09
    let minCoverBackgroundOpacity: CGFloat = 0

    init(model: ConversationsViewModel) {
        self.stateEmitter = model.stateEmitter
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SearchableConversationsView(model: model,
                                        stateEmitter: stateEmitter,
                                        activateSearch: $activateSearch)
                .zIndex(0)
                .accessibility(identifier: SmartListAccessibilityIdentifiers.conversationView)
            if showAccountList {
                backgroundCover()
                accountListsView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(leading: SmartListLeadingBarItem(model: model))
        .onReceive(model.barActions) { action in
            switch action {
            case .toggleAccounts:
                toggleAccountList()
            case .compose:
                activateSearch = true
            case .contacts:
                showingPicker.toggle()
            }
        }
        .sheet(isPresented: $showingPicker) {
            ContactPicker { [weak model] contact in
                guard let model = model else { return }
                model.showSipConversation(withNumber: contact,
                                          publisher: stateEmitter)
                showingPicker = false
            }
            .accessibility(identifier: SmartListAccessibilityIdentifiers.contactPicker)
        }
        .onChange(of: model.searchFlow.isActive) { _ in
            showAccountList = false
        }
    }

    @ViewBuilder
    private func backgroundCover() -> some View {
        Color(UIColor.black).opacity(coverBackgroundOpacity)
            .ignoresSafeArea()
            .allowsHitTesting(true)
            .onTapGesture {
                toggleAccountList()
            }
            .accessibility(identifier: SmartListAccessibilityIdentifiers.backgroundCover)
    }

    @ViewBuilder
    private func accountListsView() -> some View {
        AccountLists(model: model.accountsModel, createAccountCallback: {[weak stateEmitter] in
            toggleAccountList()
            stateEmitter?.createAccount()
        }, accountSelectedCallback: {
            showAccountList.toggle()
        }, closeCallback: {
            animateAccountListVisibility()
        })
        .zIndex(1)
        .transition(.move(edge: .bottom))
        .animation(.easeOut, value: showAccountList)
    }

    private func toggleAccountList() {
        setupBeforeTogglingAccountList()
        animateAccountListVisibility()
    }

    private func setupBeforeTogglingAccountList() {
        prepareAccountsIfNeeded()
        updateCoverBackgroundOpacity()
    }

    // Update accounts if the list is about to be shown.
    private func prepareAccountsIfNeeded() {
        guard !showAccountList else { return }
        model.accountsModel.getAccountsRows()
    }

    private func updateCoverBackgroundOpacity() {
        coverBackgroundOpacity = showAccountList ? minCoverBackgroundOpacity : maxCoverBackgroundOpacity
    }

    private func animateAccountListVisibility() {
        withAnimation {
            showAccountList.toggle()
        }
    }

    private var diapladButton: some View {
        Button(action: { [weak stateEmitter] in
            guard let stateEmitter = stateEmitter else { return }
            stateEmitter.showDialpad()
        }, label: {
            Image(systemName: "dialpad")
                .foregroundColor(Color.jami)
        })
    }
}

struct SmartListLeadingBarItem: View {
    @ObservedObject var model: ConversationsViewModel

    var body: some View {
        Button(action: {
            model.barActions.send(.toggleAccounts)
        }, label: {
            CurrentAccountButton(model: model.accountsModel)
        })
        .accessibility(identifier: SmartListAccessibilityIdentifiers.openAccountsButton)
    }
}

struct SmartListTrailingBarItems: View {
    @ObservedObject var model: ConversationsViewModel
    let menuAnchor: PopoverAnchor
    let perform: (SmartListMenuAction) -> Void

    var body: some View {
        NavBarButtonGroup {
            menuButton
            if model.isSipAccount() {
                contactsButton
            } else {
                NavBarIconButton(systemName: "square.and.pencil",
                                 accessibilityLabel: SmartListMenuAction.compose.title,
                                 accessibilityIdentifier: SmartListAccessibilityIdentifiers.composeButton) {
                    perform(.compose)
                }
            }
        }
    }

    private var contactsButton: some View {
        NavBarIconButton(accessibilityLabel: SmartListMenuAction.contacts.title,
                         accessibilityIdentifier: SmartListAccessibilityIdentifiers.bookButton,
                         action: { perform(.contacts) }, icon: {
            if let uiImage = SmartListMenuAction.contacts.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: NavBarIcon.glyphSize, height: NavBarIcon.glyphSize)
            }
        })
    }

    private var menuButton: some View {
        Menu {
            ForEach(SmartListMenuAction.menu(isSip: model.isSipAccount()), id: \.self) { action in
                Button(action: {
                    perform(action)
                }, label: {
                    Label {
                        Text(action.title)
                    } icon: {
                        if let image = action.image {
                            Image(uiImage: image)
                        }
                    }
                })
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .navBarIconStyle()
                .popoverAnchor(menuAnchor)
                .accessibility(identifier: SmartListAccessibilityIdentifiers.openMenuInSmartList)
        }
    }
}

struct SearchableConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    var stateEmitter: ConversationStatePublisher
    @Binding var activateSearch: Bool
    @SwiftUI.State private var deactivateSearch = false

    var body: some View {
        SmartListContentView(model: model,
                             stateEmitter: stateEmitter,
                             requestsModel: model.requestsModel,
                             onRestoreSearch: { activateSearch = true },
                             onAddContact: { activateSearch = true })
            .navigationBarSearch(searchTextBinding,
                                 isActive: searchActiveBinding,
                                 isSearchBarDisabled: searchBarDisabledBinding,
                                 activateSearch: $activateSearch,
                                 deactivateSearch: $deactivateSearch,
                                 results: {
                                    SmartListSearchResultsView(
                                        model: model,
                                        stateEmitter: stateEmitter,
                                        onDismissEmptyArea: { deactivateSearch = true }
                                    )
                                 })
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { model.searchFlow.text },
            set: { model.updateSearchText($0) }
        )
    }

    private var searchActiveBinding: Binding<Bool> {
        Binding(
            get: { model.searchFlow.isActive },
            set: { model.setSearchActive($0) }
        )
    }

    private var searchBarDisabledBinding: Binding<Bool> {
        Binding(
            get: { model.searchFlow.isSearchBarDisabled },
            set: { model.setSearchBarDisabled($0) }
        )
    }
}

struct CurrentAccountButton: View {
    @ObservedObject var model: AccountsViewModel
    var body: some View {
        HStack(spacing: 0) {
            avatarWithStatus
                .accessibilityHidden(true) // Prevents duplicate announcements

            Spacer().frame(width: model.dimensions.spacing)

            VStack(alignment: .leading) {
                Text(model.bestName)
                    .bold()
                    .lineLimit(1)
                    .foregroundColor(Color.jami)
                    .frame(maxWidth: 150, alignment: .leading)
                    .accessibilityHidden(true) // Hides redundant VoiceOver announcements
            }

            Spacer()
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.Accessibility.smartListSwitchAccounts)
        .accessibilityHint(L10n.Accessibility.smartListConnectedAs(model.bestName))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var avatarWithStatus: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarSwiftUIView(source: model)
            AccountStatusIndicator(status: model.accountStatus, size: 8, borderWidth: 1, blurStyle: .systemChromeMaterial)
                .offset(x: 1, y: 2)
        }
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content

    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }

    var body: some View {
        build()
    }
}
