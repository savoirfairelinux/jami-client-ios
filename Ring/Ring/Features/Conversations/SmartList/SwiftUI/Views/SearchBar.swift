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

public extension View {
    /// Adds a native search bar to the hosting navigation item. The `results`
    /// content is hosted inside the search controller's `searchResultsController`
    /// so it is shown — and stays interactive — while the search is active. This
    /// matters on iPadOS 26, where content rendered behind an active search
    /// controller no longer receives taps.
    func navigationBarSearch<Results: View>(_ searchText: Binding<String>,
                                            isActive: Binding<Bool>,
                                            isSearchBarDisabled: Binding<Bool>,
                                            activateSearch: Binding<Bool>,
                                            deactivateSearch: Binding<Bool> = .constant(false),
                                            @ViewBuilder results: @escaping () -> Results) -> some View {
        return overlay(
            NavigationSearchControllerHost(
                text: searchText,
                isActive: isActive,
                isSearchBarDisabled: isSearchBarDisabled,
                activateSearch: activateSearch,
                deactivateSearch: deactivateSearch,
                results: results
            )
            .frame(width: 0, height: 0)
        )
    }
}

private struct NavigationSearchControllerHost<Results: View>: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool
    @Binding var isSearchBarDisabled: Bool
    @Binding var activateSearch: Bool
    @Binding var deactivateSearch: Bool
    let results: () -> Results

    init(text: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>, activateSearch: Binding<Bool>, deactivateSearch: Binding<Bool>, results: @escaping () -> Results) {
        self._text = text
        self._isActive = isActive
        self._isSearchBarDisabled = isSearchBarDisabled
        self._activateSearch = activateSearch
        self._deactivateSearch = deactivateSearch
        self.results = results
    }

    func makeUIViewController(context: Context) -> SearchBarWrapperController {
        return SearchBarWrapperController()
    }

    func updateUIViewController(_ controller: SearchBarWrapperController, context: Context) {
        let coordinator = context.coordinator
        controller.searchController = coordinator.searchController
        coordinator.updateResults(results())
        coordinator.updateSearchText(text)

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

        // Request to leave search/compose mode (e.g. tapping the empty area of
        // the results controller). Deferred because updateUIViewController is already
        // inside SwiftUI's update cycle, and dismissing the UIKit search controller
        // also mutates SwiftUI bindings via delegate callbacks.
        if self.deactivateSearch {
            DispatchQueue.main.async {
                self.deactivateSearch = false
                coordinator.dismissSearch(clearText: true)
            }
            return
        }

        if self.isSearchBarDisabled {
            DispatchQueue.main.async {
                self.isSearchBarDisabled = false
                coordinator.dismissSearch(animated: false)
            }
            return
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(
            text: $text,
            isActive: $isActive,
            isSearchBarDisabled: $isSearchBarDisabled,
            initialResults: results()
        )
    }

    class Coordinator: NSObject, UISearchResultsUpdating, UISearchControllerDelegate {
        @Binding var text: String
        @Binding var isActive: Bool
        @Binding var isSearchBarDisabled: Bool
        private let hostingController: UIHostingController<Results>
        let searchController: UISearchController
        private var shouldFocusWhenPresented = false

        init(text: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>, initialResults: Results) {
            self._text = text
            self._isActive = isActive
            self._isSearchBarDisabled = isSearchBarDisabled

            self.hostingController = UIHostingController(rootView: initialResults)
            self.searchController = UISearchController(searchResultsController: hostingController)

            super.init()

            searchController.searchResultsUpdater = self
            searchController.hidesNavigationBarDuringPresentation = true
            searchController.obscuresBackgroundDuringPresentation = false
            // Show the results controller as soon as the search is active (even with an
            // empty query) so the compose shortcuts are visible and tappable immediately.
            searchController.showsSearchResultsController = true
            searchController.searchBar.searchTextField.accessibilityIdentifier = SmartListAccessibilityIdentifiers.searchBarTextField

            self.searchController.searchBar.text = self.text
            searchController.delegate = self
        }

        func updateResults(_ results: Results) {
            hostingController.rootView = results
        }

        func updateSearchText(_ text: String) {
            guard searchController.searchBar.text != text else { return }
            searchController.searchBar.text = text
        }

        /// Programmatically open the search bar (e.g. from the compose button) and
        /// focus it once UIKit reports the presentation finished.
        func activateSearch() {
            guard !searchController.isActive else { return }
            shouldFocusWhenPresented = true
            searchController.showsSearchResultsController = true
            searchController.isActive = true
        }

        func dismissSearch(clearText: Bool = false, animated: Bool = true) {
            shouldFocusWhenPresented = false
            if clearText {
                text = ""
                searchController.searchBar.text = ""
            }
            guard searchController.isActive else { return }
            if animated {
                searchController.isActive = false
            } else {
                UIView.performWithoutAnimation {
                    searchController.isActive = false
                }
            }
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
