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
    var body: some View {
        switch state.navigationTarget {
            case .smartList:
                PlatformAdaptiveNavView {
                    SearchableSmartList(model: model, mode: .smartList, isNewMessageViewPresented: $isNewMessageViewPresented, dismissAction: {})
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationTitle("Conversations")
                        .navigationBarItems(trailing: trailingBarItems)
                      //  .applySlideTransition(directionUp: state.slideDirectionUp)
                }
            case .newMessage:
                NewMessageView(model: model, isNewMessageViewPresented: $isNewMessageViewPresented, smartListState: state)
                    .applySlideTransition(directionUp: state.slideDirectionUp)
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
                Button(action: model.openSettings) {
                    Label {
                        Text(L10n.Smartlist.inviteFriends)
                    } icon: {
                        Image(systemName: "envelope.open")
                    }
                }
                Button(action: model.openSettings) {
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


