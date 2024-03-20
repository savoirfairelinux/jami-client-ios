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
    @ObservedObject var model: ConversationsViewModel
    @StateObject var navigationManager = NavigationManager()
    @SwiftUI.State var isNewMessageViewPresented = false
    @StateObject private var state = SmartListState()
    @SwiftUI.State private var showAccountSelection = false
    @SwiftUI.State private var opacity = 0.08
    @SwiftUI.State private var isSharing = false
    let shareItem = URL(string: "https://example.com")!
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
                        if showAccountSelection {
                            Color.black.opacity(opacity)
                                .ignoresSafeArea(edges: [.top, .bottom])
                                .allowsHitTesting(true)
                                            .onTapGesture {
                                                opacity = 0
                                                withAnimation {
                                                    showAccountSelection = false
                                                }
                                            }
                            AccountLists(model: model.accountsModel) {
                                opacity = showAccountSelection ? 0 : 0.08
                                showAccountSelection = false
                                model.createAccount()
                            }
                            .transition(.move(edge: .bottom))
                            .animation(.easeOut, value: showAccountSelection)
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
                opacity = showAccountSelection ? 0 : 0.08
                withAnimation {
                    model.accountsModel.getAccountsRows()
                    showAccountSelection.toggle()
                }
            }) {
                CurrentAccountButton(model: model.accountsModel)
            }
    }

    private var accountLists: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    opacity = showAccountSelection ? 0 : 0.08
                    showAccountSelection = false
                    model.createAccount()
                }, label: {
                    HStack {
                        Image(systemName: "plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundColor(Color(UIColor(named: "jamiMain")!))
                        Spacer()
                            .frame(width: 15)
                        Text(L10n.Smartlist.addAccountButton)
                            .lineLimit(1)

                    }
                    .padding()
                    .frame(height: 35)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor(named: "donationBanner")!))
                    .cornerRadius(12)
                })

                Spacer()
            }
            .padding()
            List(model.accountsModel.accountsRows, id: \.id) { account in
                HStack {
                    Image(uiImage: account.avatar)
                        .resizable()
                        .frame(width: 25, height: 25)
                        .clipShape(Circle())
                    Spacer().frame(width: 10)
                    VStack(alignment: .leading) {
                        if !account.profileName.isEmpty {
                            Text(account.profileName)
                            Spacer().frame(height: 5)
                        }
                        Text(account.registeredName)
                    }
                    Spacer()
                }
                .frame(height: 30)
                .listRowBackground(account.id == model.accountsModel.selectedAccount ? Color(UIColor.tertiarySystemGroupedBackground) : nil)
                .onTapGesture {
                    model.accountsModel.changeCurrentAccount(accountId: account.id)
                }
            }
            .listStyle(PlainListStyle())
        }
        .frame(maxHeight: 200)
        .transition(.move(edge: .bottom))
        .animation(.default, value: showAccountSelection)
        .ignoresSafeArea()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .onAppear {
            model.accountsModel.getAccountsRows()
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
//                    ShareLink(item: shareItem,
//                              subject: Text("Check this out!"),
//                              message: Text("I thought you might find this interesting: "))
                }
//                Button(action: {isSharing = true}) {
//                    Label {
//                        Text(L10n.Smartlist.inviteFriends)
//                    } icon: {
//                        Image(systemName: "envelope.open")
//                    }
//                }
                Button(action: {opacity = showAccountSelection ? 0 : 0.08
                    withAnimation {
                        showAccountSelection.toggle()
                    }}) {
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
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            Spacer()
                .frame(width: 10)
            VStack(alignment: .leading){
                if !model.profileName.isEmpty {
                    Text(model.profileName)
                        .bold()
                        .lineLimit(1)
                } else {
                    Text(model.registeredName)
                        .bold()
//                        .font(.callout)
//                        .fontWeight(model.profileName.isEmpty ? .medium : .regular)
                        .truncationMode(.tail)
                        .lineLimit(1)
                        .frame(maxWidth: 150, alignment: .leading)
                }
            }
            Spacer()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

struct AccountLists: View {
    @ObservedObject var model: AccountsViewModel
    var createAccountCallback: (() -> Void)
    var body: some View {
        VStack(spacing: 10) {
            VStack {
                Spacer()
                    .frame(height: 15)
                Text("Accounts")
                    .fontWeight(.semibold)
                Spacer()
                    .frame(height: 15)
                ScrollView {
                    VStack {
                        ForEach(model.accountsRows, id: \.id) { accountRow in
                            AccountRowView(accountRow: accountRow)
                                .background(accountRow.id == model.selectedAccount ? Color(UIColor.secondarySystemFill).clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal, 5) : nil)
                                .onTapGesture {
                                    model.changeCurrentAccount(accountId: accountRow.id)
                                }
                                .hideRowSeparator()
                        }
                    }
                    .frame(minHeight: 0, maxHeight: .infinity)
                }
                .frame(maxHeight: 300)
                Spacer()
                    .frame(height: 15)
            }
            .applyAlertBackgroundMaterial()
            .cornerRadius(16)
            .shadow(radius: 10)
            .fixedSize(horizontal: false, vertical: true)
            Button(action: {
                createAccountCallback()
            }, label: {
                Text(L10n.Smartlist.addAccountButton)
                    .lineLimit(1)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
            })
            .frame(minWidth: 100, maxWidth: .infinity)
            .shadow(radius: 10)
        }
        .padding(.horizontal, 5)
    }
}

struct AccountRowView: View {
    @ObservedObject var accountRow: AccountRow
    var body: some View {
        HStack(spacing: 0) {
            Image(uiImage: accountRow.avatar)
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            Spacer().frame(width: 10)
            VStack(alignment: .leading) {
                if !accountRow.profileName.isEmpty {
                    Text(accountRow.profileName)
                        .lineLimit(1)
                } else {
                    Text(accountRow.registeredName)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct MaxSizeModifier: ViewModifier {
    var maxHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxHeight: maxHeight)
    }
}

struct AlertBackgroundMaterialModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .background(Material.ultraThickMaterial)
        } else {
            content
                .background(Color(UIColor.systemBackground))
        }
    }
}

extension View {
    func applyAlertBackgroundMaterial() -> some View {
        self.modifier(AlertBackgroundMaterialModifier())
    }
}



