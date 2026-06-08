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

public extension View {
    func navigationBarSearch(_ searchText: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>, activateSearch: Binding<Bool>) -> some View {
        return overlay(SearchBar(text: searchText, isActive: isActive, isSearchBarDisabled: isSearchBarDisabled, activateSearch: activateSearch).frame(width: 0, height: 0))
    }
}

private struct SearchBar: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool
    @Binding var isSearchBarDisabled: Bool
    @Binding var activateSearch: Bool

    init(text: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>, activateSearch: Binding<Bool>) {
        self._text = text
        self._isActive = isActive
        self._isSearchBarDisabled = isSearchBarDisabled
        self._activateSearch = activateSearch
    }

    func makeUIViewController(context: Context) -> SearchBarWrapperController {
        return SearchBarWrapperController()
    }

    func updateUIViewController(_ controller: SearchBarWrapperController, context: Context) {
        let coordinator = context.coordinator
        controller.searchController = coordinator.searchController

        // An explicit compose request always wins: re-enable the bar if it was
        // programmatically disabled (e.g. after creating a conversation) and activate it.
        // Deferred because we mutate SwiftUI state and present UIKit from within a view update.
        if self.activateSearch {
            DispatchQueue.main.async {
                self.activateSearch = false
                self.isSearchBarDisabled = false
                coordinator.activateSearch()
            }
            return
        }

        if self.isSearchBarDisabled {
            coordinator.searchController.isActive = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isActive: $isActive, isSearchBarDisabled: $isSearchBarDisabled)
    }

    class Coordinator: NSObject, UISearchResultsUpdating, UISearchControllerDelegate {
        @Binding var text: String
        @Binding var isActive: Bool
        @Binding var isSearchBarDisabled: Bool
        let searchController: UISearchController
        private var shouldFocusWhenPresented = false

        init(text: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>) {
            self._text = text
            self._isActive = isActive
            self._isSearchBarDisabled = isSearchBarDisabled
            self.searchController = UISearchController(searchResultsController: nil)

            super.init()

            searchController.searchResultsUpdater = self
            searchController.hidesNavigationBarDuringPresentation = true
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.searchTextField.accessibilityIdentifier = SmartListAccessibilityIdentifiers.searchBarTextField

            self.searchController.searchBar.text = self.text
            searchController.delegate = self
        }

        /// Programmatically open the search bar (e.g. from the compose button) and
        /// focus it once UIKit reports the presentation finished.
        func activateSearch() {
            guard !searchController.isActive else { return }
            shouldFocusWhenPresented = true
            searchController.isActive = true
        }

        func willPresentSearchController(_ searchController: UISearchController) {
            DispatchQueue.main.async {
                self.isSearchBarDisabled = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isActive = true
                }
            }
        }

        func didPresentSearchController(_ searchController: UISearchController) {
            guard shouldFocusWhenPresented else { return }
            shouldFocusWhenPresented = false
            searchController.searchBar.becomeFirstResponder()
        }

        func willDismissSearchController(_ searchController: UISearchController) {
            DispatchQueue.main.async {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.isActive = false
                }
            }
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
        var searchController: UISearchController?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            attachSearchController()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            attachSearchController()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachSearchController()
        }

        private func attachSearchController() {
            guard let parent = self.parent else { return }
            parent.navigationItem.searchController = self.searchController
            parent.navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
}
