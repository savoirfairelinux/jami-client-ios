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

struct NewMessageView: View, StateEmittingView {
    typealias StateEmitterType = ConversationStatePublisher

    @StateObject var viewModel: ConversationsViewModel
    var stateEmitter: ConversationStatePublisher
    @SwiftUI.State private var isSearchBarActive = false // To track state initiated by the user

    init(injectionBag: InjectionBag, source: ConversationDataSource) {
        let emitter = ConversationStatePublisher()
        self.stateEmitter = emitter
        _viewModel = StateObject(wrappedValue:
                                    ConversationsViewModel(with: injectionBag, conversationsSource: source, stateEmitter: emitter))
    }

    var body: some View {
        SearchableConversationsView(model: viewModel,
                                    stateEmitter: stateEmitter,
                                    mode: .newMessage,
                                    isSearchBarActive: $isSearchBarActive)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.Smartlist.newMessage)
            .navigationBarItems(leading: leadingBarItem)
    }

    private var leadingBarItem: some View {
        Button(action: {[weak stateEmitter] in
            stateEmitter?.closeComposingMessage()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color.jamiColor)
        })
    }
}

struct SmartListView: View, StateEmittingView {
    typealias StateEmitterType = ConversationStatePublisher

    @StateObject var model: ConversationsViewModel
    var stateEmitter: ConversationStatePublisher
    @SwiftUI.State var showAccountList = false
    @SwiftUI.State private var coverBackgroundOpacity: CGFloat = 0
    @SwiftUI.State private var isSearchBarActive = false
    @SwiftUI.State private var showingPicker = false
    @SwiftUI.State private var isSharing = false
    @SwiftUI.State private var isMenuOpen = false
    @SwiftUI.State private var isNavigatingToSettings = false

    let maxCoverBackgroundOpacity: CGFloat = 0.09
    let minCoverBackgroundOpacity: CGFloat = 0

    init(injectionBag: InjectionBag, source: ConversationDataSource) {
        let emitter = ConversationStatePublisher()
        self.stateEmitter = emitter
        _model = StateObject(wrappedValue:
                                ConversationsViewModel(with: injectionBag, conversationsSource: source,
                                                       stateEmitter: emitter))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SearchableConversationsView(model: model,
                                        stateEmitter: stateEmitter,
                                        mode: .smartList,
                                        isSearchBarActive: $isSearchBarActive)
                .zIndex(0)
                .accessibility(identifier: SmartListAccessibilityIdentifiers.conversationView)
            if showAccountList {
                backgroundCover()
                accountListsView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(leading: leadingBarItems, trailing: trailingBarItems)
        .sheet(isPresented: $showingPicker) {
            ContactPicker { [weak model] contact in
                guard let model = model else { return }
                model.showSipConversation(withNumber: contact,
                                          publisher: stateEmitter)
                showingPicker = false
            }
            .accessibility(identifier: SmartListAccessibilityIdentifiers.contactPicker)
        }
        .onChange(of: isSearchBarActive) { _ in
            showAccountList = false
        }
        .overlay(isMenuOpen ? makeOverlay() : nil)
    }

    func makeOverlay() -> some View {
        return Color.white.opacity(0.001)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                isMenuOpen = false
            }
            .accessibility(identifier: SmartListAccessibilityIdentifiers.overlay)
    }

    private var leadingBarItems: some View {
        Button(action: {
            isMenuOpen = false
            toggleAccountList()
        }, label: {
            CurrentAccountButton(model: model.accountsModel)
        })
        .accessibility(identifier: SmartListAccessibilityIdentifiers.openAccountsButton)
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

    private var trailingBarItems: some View {
        HStack {
            if model.isSipAccount() {
                menuButton
                bookButton
            } else {
                menuButton
                composeButton
            }
        }
    }

    private var bookButton: some View {
        Button(action: {
            isMenuOpen = false
            showingPicker.toggle()
        }, label: {
            if let uiImage = UIImage(asset: Asset.phoneBook) {
                Image(uiImage: uiImage)
                    .foregroundColor(Color.jamiColor)
            }
        })
        .accessibility(identifier: SmartListAccessibilityIdentifiers.bookButton)
    }

    private var diapladButton: some View {
        Button(action: { [weak stateEmitter] in
            isMenuOpen = false
            guard let stateEmitter = stateEmitter else { return }
            stateEmitter.showDialpad()
        }, label: {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .foregroundColor(Color.jamiColor)
        })
    }

    private var menuButton: some View {
        Menu {
            if !model.isSipAccount() {
                createSwarmButton
                if #available(iOS 16.0, *) {
                    shareLinkButton
                }
            }
            accountsButton
            settingsButton
            aboutJamiButton
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(Color.jamiColor)
                .accessibility(identifier: SmartListAccessibilityIdentifiers.openMenuInSmartList)
        }
        .onTapGesture {
            isMenuOpen = true
        }
    }

    private var composeButton: some View {
        Button(action: { [weak stateEmitter] in
            isMenuOpen = false
            guard let stateEmitter = stateEmitter else { return }
            stateEmitter.openNewMessagesWindow()
        }, label: {
            Image(systemName: "square.and.pencil")
                .foregroundColor(Color.jamiColor)
        })
    }

    private var createSwarmButton: some View {
        Button(action: { [weak stateEmitter] in
            isMenuOpen = false
            guard let stateEmitter = stateEmitter else { return }
            stateEmitter.createSwarm()
        }, label: {
            Label(L10n.Swarm.newGroup, systemImage: "person.2")
        })
    }

    @available(iOS 16.0, *)
    private var shareLinkButton: some View {
        ShareLink(item: model.accountInfoToShare) {
            Label(L10n.Smartlist.inviteFriends, systemImage: "envelope.open")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .onTapGesture {
                    isMenuOpen = false
                }
        }
    }

    private var accountsButton: some View {
        Button(action: {
            isMenuOpen = false
            toggleAccountList()
        }, label: {
            Label(L10n.Smartlist.accounts, systemImage: "list.bullet")
        })
    }

    private var settingsButton: some View {
        Button(action: {[weak model, weak stateEmitter] in
            isMenuOpen = false
            guard let model = model,
                  let stateEmitter = stateEmitter else { return }
            model.showAccount(publisher: stateEmitter)
        }, label: {
            Label(L10n.AccountPage.settingsHeader, systemImage: "person.circle")
        })
    }

    private var donateButton: some View {
        Button(action: {[weak model] in
            isMenuOpen = false
            guard let model = model else { return }
            model.donate()
        }, label: {
            Label(L10n.Global.donate, systemImage: "heart")
        })
    }

    private var aboutJamiButton: some View {
        Button(action: {[weak stateEmitter] in
            isMenuOpen = false
            guard let stateEmitter = stateEmitter else { return }
            stateEmitter.openAboutJami()
        }, label: {
            Label {
                Text(L10n.Smartlist.aboutJami)
            } icon: {
                Image(uiImage: model.jamiImage)
            }
        })
    }
}

struct SearchableConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    var stateEmitter: ConversationStatePublisher
    @SwiftUI.State var mode: ConversationsViewModel.Target
    @Binding var isSearchBarActive: Bool
    @SwiftUI.State private var searchText = ""
    @SwiftUI.State private var isSearchBarDisabled = false // To programmatically disable the search bar
    @SwiftUI.State private var scrollViewOffset: CGFloat = 0
    var body: some View {
        SmartListContentView(model: model,
                             stateEmitter: stateEmitter,
                             mode: mode,
                             requestsModel: model.requestsModel,
                             isSearchBarActive: $isSearchBarActive)
            .navigationBarSearch(self.$searchText, isActive: $isSearchBarActive, isSearchBarDisabled: $isSearchBarDisabled)
            .onChange(of: searchText) {[weak model] _ in
                guard let model = model else { return }
                model.performSearch(query: searchText.lowercased())
            }
            .onChange(of: model.conversationCreated) {[weak model] _ in
                guard let model = model else { return }
                if model.conversationCreated.isEmpty { return }
                isSearchBarDisabled = true
                searchText = ""
            }
    }
}

struct CurrentAccountButton: View {
    @ObservedObject var model: AccountsViewModel
    var body: some View {
        HStack(spacing: 0) {
            Image(uiImage: model.avatar)
                .resizable()
                .scaledToFill()
                .frame(width: model.dimensions.imageSize, height: model.dimensions.imageSize)
                .clipShape(Circle())
                .accessibilityHidden(true) // Prevents duplicate announcements

            Spacer().frame(width: model.dimensions.spacing)

            VStack(alignment: .leading) {
                Text(model.bestName)
                    .bold()
                    .lineLimit(1)
                    .foregroundColor(Color.jamiColor)
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
