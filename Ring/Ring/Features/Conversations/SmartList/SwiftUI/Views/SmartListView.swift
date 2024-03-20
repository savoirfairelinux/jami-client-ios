//
//  SmartListView.swift
//  Ring
//
//  Created by kateryna on 2024-03-19.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI
import Combine

public extension View {
    func navigationBarSearch(_ searchText: Binding<String>, isActive: Binding<Bool>) -> some View {
        return overlay(SearchBar(text: searchText, isActive: isActive).frame(width: 0, height: 0))
    }
}

fileprivate struct SearchBar: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool

    init(text: Binding<String>, isActive: Binding<Bool>) {
        self._text = text
        self._isActive = isActive
    }

    func makeUIViewController(context: Context) -> SearchBarWrapperController {
        return SearchBarWrapperController()
    }

    func updateUIViewController(_ controller: SearchBarWrapperController, context: Context) {
        controller.searchController = context.coordinator.searchController
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isActive: $isActive)
    }

    class Coordinator: NSObject, UISearchResultsUpdating {
        @Binding var text: String
        @Binding var isActive: Bool
        let searchController: UISearchController

        private var subscription: AnyCancellable?

        init(text: Binding<String>, isActive: Binding<Bool>) {
            self._text = text
            self._isActive = isActive
            self.searchController = UISearchController(searchResultsController: nil)

            super.init()

            searchController.searchResultsUpdater = self
            // Add these lines to observe changes to the search controller's active state
            searchController.searchBar.searchTextField.addTarget(self, action: #selector(searchBarTextDidBeginEditing(_:)), for: .editingDidBegin)
            searchController.searchBar.searchTextField.addTarget(self, action: #selector(searchBarTextDidEndEditing(_:)), for: .editingDidEnd)
            searchController.hidesNavigationBarDuringPresentation = true
            searchController.obscuresBackgroundDuringPresentation = false

            self.searchController.searchBar.text = self.text
            self.subscription = self.text.publisher.sink { _ in
                self.searchController.searchBar.text = self.text
            }
        }

        @objc private func searchBarTextDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                withAnimation {
                    self.isActive = true
                }
            }
        }

        @objc private func searchBarTextDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                withAnimation {
                    self.isActive = false
                }
            }
        }

        deinit {
            self.subscription?.cancel()
        }

        func updateSearchResults(for searchController: UISearchController) {
            // DispatchQueue.main.async is important to avoid "Modifying state during view update, this will cause undefined behavior." error
            DispatchQueue.main.async {
                guard let text = searchController.searchBar.text else { return }
                self.text = text
            }
        }
    }

    class SearchBarWrapperController: UIViewController {
        var searchController: UISearchController? {
            didSet {
                self.parent?.navigationItem.searchController = searchController
            }
        }

        override func viewWillAppear(_ animated: Bool) {
            self.parent?.navigationItem.searchController = searchController
        }
        override func viewDidAppear(_ animated: Bool) {
            self.parent?.navigationItem.searchController = searchController
        }
    }
}

struct PlatformAdaptiveNavView<Content: View>: View {
    let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
        }
    }
}

enum SearchMode {
    case smartList
    case newMessage
}

struct SearchableSmartList: View {
    @ObservedObject var model: ConversationsViewModel
    var mode: SearchMode
    @SwiftUI.State private var searchText = ""
    @SwiftUI.State private var isSearchBarActive = false
    @Binding var isNewMessageViewPresented: Bool
    let dismissAction: (() -> Void)?
    var body: some View {
        SmartListContainer(model: model, mode: mode, isSearchBarActive: $isSearchBarActive, isNewMessageViewPresented: $isNewMessageViewPresented, dismissAction: dismissAction)
            .navigationBarSearch(self.$searchText, isActive: $isSearchBarActive)
                .onChange(of: searchText) { _ in
                    model.performSearch(query: searchText)
                }
    }
}

class SmartListState: ObservableObject {
    enum Target {
        case smartList
        case newMessage
       // case conversation
    }

    @Published var slideDirectionUp: Bool = true

    @Published var navigationTarget: Target = .smartList
}

struct SlideTransition: ViewModifier {
    let directionUp: Bool

    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: directionUp ? .bottom : .top),
                removal: .move(edge: directionUp ? .top : .bottom)
            ))
    }
}

extension View {
    func applySlideTransition(directionUp: Bool) -> some View {
        self.modifier(SlideTransition(directionUp: directionUp))
    }
}


struct SmartListView: View {
    let maxCoverBackgroundOpacity: CGFloat = 0.08
    let minCoverBackgroundOpacity: CGFloat = 0
    @ObservedObject var model: ConversationsViewModel
    @StateObject var navigationManager = NavigationManager()
    @SwiftUI.State var isNewMessageViewPresented = false
    @StateObject private var state = SmartListState()
    @SwiftUI.State private var showAccountList = false
    @SwiftUI.State private var coverBackgroundOpacity: CGFloat = 0
    @SwiftUI.State private var isSharing = false
    var body: some View {
        switch state.navigationTarget {
            case .smartList:
                PlatformAdaptiveNavView {
                    ZStack(alignment: .bottom) {
                        SearchableSmartList(model: model, mode: .smartList, isNewMessageViewPresented: $isNewMessageViewPresented, dismissAction: {})
                            .navigationBarItems(leading: leadingBarItems)
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle("")
                            .navigationBarItems(trailing: trailingBarItems)
                            .zIndex(0)
                        if showAccountList {
                            BackgroundCover()
                            AccountListsView()
                        }
                    }
                }
            case .newMessage:
                NewMessageView(model: model, isNewMessageViewPresented: $isNewMessageViewPresented, smartListState: state)
                    .applySlideTransition(directionUp: state.slideDirectionUp)
        }
    }

    private var leadingBarItems: some View {
        Button(action: {
            toggleAccountList()
        }) {
            CurrentAccountButton(model: model.accountsModel)
        }
    }

    @ViewBuilder
    private func BackgroundCover() -> some View {
        Color.black.opacity(coverBackgroundOpacity)
            .ignoresSafeArea(edges: [.top, .bottom])
            .allowsHitTesting(true)
            .onTapGesture {
                toggleAccountList()
            }
    }

    @ViewBuilder
    private func AccountListsView() -> some View {
        AccountLists(model: model.accountsModel) {
            toggleAccountList()
            model.createAccount()
        }
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
            Menu {
                Button(action: model.createSwarm) {
                    Label {
                        Text(L10n.Swarm.newSwarm)
                    } icon: {
                        Image(systemName: "person.2")
                    }
                }

                if #available(iOS 16.0, *) {
                    ShareLink(item: model.accountInfoToShare) {
                        HStack {
                            Text(L10n.Smartlist.inviteFriends)
                            Image(systemName: "envelope.open")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                Button(action: {toggleAccountList()}) {
                    Label {
                        Text(L10n.Smartlist.accounts)
                    } icon: {
                        Image(systemName: "list.bullet")
                    }
                }
                Button(action: model.openSettings) {
                    Label {
                        Text(L10n.Global.accountSettings)
                    } icon: {
                        Image(systemName: "person.circle")
                    }
                }
                Button(action: model.showGeneralSettings) {
                    Label {
                        Text(L10n.Global.advancedSettings)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                Button(action: model.donate) {
                    Label {
                        Text(L10n.Global.donate)
                    } icon: {
                        Image(systemName: "heart")
                    }
                }
                Button(action: model.openAboutJami) {
                    Label {
                        Text(L10n.Smartlist.aboutJami)
                            .foregroundColor(Color(UIColor(named: "jamiMain")!))
                    } icon: {
                        Image(uiImage: UIImage(asset: Asset.jamiIcon)!.resizeImageWith(newSize: CGSize(width: 20, height: 20), opaque: false)!)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }

            Button(action: {
                state.slideDirectionUp = true
                withAnimation {
                    state.navigationTarget = .newMessage
                }
            }) {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct CurrentAccountButton: View {
    @ObservedObject var model: AccountsViewModel
    var body: some View {
        HStack(spacing: 0){
            Image(uiImage: model.avatar)
                .frame(width: model.dimensions.imageSize, height: model.dimensions.imageSize)
                .clipShape(Circle())
            Spacer()
                .frame(width: model.dimensions.spacing)
            VStack(alignment: .leading){
                Text(model.bestName)
                    .bold()
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .leading)
            }
            Spacer()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}




