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
    func navigationBarSearch(_ searchText: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>) -> some View {
        return overlay(SearchBar(text: searchText, isActive: isActive, isSearchBarDisabled: isSearchBarDisabled).frame(width: 0, height: 0))
    }
}

fileprivate struct SearchBar: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool
    @Binding var isSearchBarDisabled: Bool // used to programaticly dismiss search controller

    init(text: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>) {
        self._text = text
        self._isActive = isActive
        self._isSearchBarDisabled = isSearchBarDisabled
    }

    func makeUIViewController(context: Context) -> SearchBarWrapperController {
        return SearchBarWrapperController()
    }

    func updateUIViewController(_ controller: SearchBarWrapperController, context: Context) {
        controller.searchController = context.coordinator.searchController
        if self.isSearchBarDisabled {
            controller.searchController?.isActive = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isActive: $isActive, isSearchBarDisabled: $isSearchBarDisabled)
    }

    class Coordinator: NSObject, UISearchResultsUpdating {
        @Binding var text: String
        @Binding var isActive: Bool
        @Binding var isSearchBarDisabled: Bool
        let searchController: UISearchController

        init(text: Binding<String>, isActive: Binding<Bool>, isSearchBarDisabled: Binding<Bool>) {
            self._text = text
            self._isActive = isActive
            self._isSearchBarDisabled = isSearchBarDisabled
            self.searchController = UISearchController(searchResultsController: nil)

            super.init()

            searchController.searchResultsUpdater = self
            searchController.searchBar.searchTextField.addTarget(self, action: #selector(searchBarTextDidBeginEditing(_:)), for: .editingDidBegin)
            searchController.searchBar.searchTextField.addTarget(self, action: #selector(searchBarTextDidEndEditing(_:)), for: .editingDidEnd)
            searchController.hidesNavigationBarDuringPresentation = true
            searchController.obscuresBackgroundDuringPresentation = false

            self.searchController.searchBar.text = self.text
        }

        @objc private func searchBarTextDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                withAnimation {
                    self.isSearchBarDisabled = false
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
            super.viewWillAppear(animated)
            self.parent?.navigationItem.searchController = self.searchController
            // Ensure the search bar remains visible as the view appears.
            self.parent?.navigationItem.hidesSearchBarWhenScrolling = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            self.parent?.navigationItem.searchController = self.searchController
            // Allow the search bar to be hidden when scrolling, now that the view has fully appeared and is interactive.
          //  self.parent?.navigationItem.hidesSearchBarWhenScrolling = true
        }
    }
}
