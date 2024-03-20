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
    func navigationBarSearch(_ searchText: Binding<String>) -> some View {
        return overlay(SearchBar(text: searchText).frame(width: 0, height: 0))
    }
}

fileprivate struct SearchBar: UIViewControllerRepresentable {
    @Binding
    var text: String

    init(text: Binding<String>) {
        self._text = text
    }

    func makeUIViewController(context: Context) -> SearchBarWrapperController {
        return SearchBarWrapperController()
    }

    func updateUIViewController(_ controller: SearchBarWrapperController, context: Context) {
        controller.searchController = context.coordinator.searchController
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }

    class Coordinator: NSObject, UISearchResultsUpdating {
        @Binding
        var text: String
        let searchController: UISearchController

        private var subscription: AnyCancellable?

        init(text: Binding<String>) {
            self._text = text
            self.searchController = UISearchController(searchResultsController: nil)

            super.init()

            searchController.searchResultsUpdater = self
            searchController.hidesNavigationBarDuringPresentation = true
            searchController.obscuresBackgroundDuringPresentation = false

            self.searchController.searchBar.text = self.text
            self.subscription = self.text.publisher.sink { _ in
                self.searchController.searchBar.text = self.text
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

struct SearchableListView<ContentView: View>: View {
    @SwiftUI.State private var searchText = ""
    let contentView: ContentView
    var body: some View {
        List {
            contentView
        }
        .listStyle(.plain)
        .navigationBarSearch(self.$searchText)
    }
}

struct SearchableSmartList: View {
    @ObservedObject var model: ConversationsViewModel
    @SwiftUI.State private var searchText = ""
    var body: some View {
        SmartListCotainer(model: model)
       .navigationBarSearch(self.$searchText)
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

