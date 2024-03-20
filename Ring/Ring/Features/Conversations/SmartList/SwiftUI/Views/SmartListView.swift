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

struct SearchableSmartList: View {
    @ObservedObject var model: ConversationsViewModel
    @SwiftUI.State private var searchText = ""
    @SwiftUI.State private var isSearchBarActive = false
    var body: some View {
        SmartListContainer(model: model, isSearchBarActive: $isSearchBarActive)
            .navigationBarSearch(self.$searchText, isActive: $isSearchBarActive)
                .onChange(of: searchText) { _ in
                    model.performSearch(query: searchText)
                }
    }
}


struct SmartListView: View {
    @ObservedObject var model: ConversationsViewModel
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                SearchableSmartList(model: model)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Conversations")
                    .navigationBarItems(trailing:
                                            HStack {
                        Menu {
                            Button("account settings", action: model.openSettings)
                            Button("Option 2", action: model.openSettings)
                            Button("Option 3", action: model.openSettings)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.blue)
                        }

                        Button(action: {
                            self.model.newMessage()
                        }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.blue)
                        }
                    }
                    )


            }
        } else {
            NavigationView {
                SearchableSmartList(model: model)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Conversations")
                    .navigationBarItems(trailing:
                                            HStack {
                        Menu {
                            Button("account settings", action: model.openSettings)
                            Button("Option 2", action: model.openSettings)
                            Button("Option 3", action: model.openSettings)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.blue)
                        }

                        Button(action: {
                            self.model.newMessage()
                        }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.blue)
                        }
                    }
                    )


            }
            .navigationViewStyle(.stack)
        }
    }
}

