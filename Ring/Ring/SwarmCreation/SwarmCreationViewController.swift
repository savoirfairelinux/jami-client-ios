/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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

import UIKit
import SwiftUI
import Reusable
import RxSwift
import RxRelay

class SwarmCreationViewController: UIViewController, ViewModelBased, StoryboardBased, UISearchResultsUpdating {
    var viewModel: SwarmCreationViewModel!
    private let disposeBag = DisposeBag()
    let strSearchText = BehaviorRelay<String>(value: "")

    let searchController: CustomSearchController = {
        let searchController = CustomSearchController(searchResultsController: nil)
        searchController.searchBar.searchBarStyle = .minimal
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.definesPresentationContext = true
        searchController.hidesNavigationBarDuringPresentation = true
        return searchController
    }()

    override func viewDidLoad() {
        self.navigationItem.title = L10n.Swarm.selectContacts
        let backButton = UIBarButtonItem(title: L10n.Global.cancel, style: .plain, target: self, action: #selector(backButtonTapped))

        self.navigationItem.leftBarButtonItem = backButton

        let continueButton = UIBarButtonItem(title: L10n.Global.create, style: .plain, target: self, action: #selector(backButtonTapped))

        self.navigationItem.rightBarButtonItem = continueButton
        super.viewDidLoad()
        guard let accountId = self.viewModel.currentAccount?.id else { return }

        let model = SwarmCreationUIModel(with: self.viewModel.injectionBag, accountId: accountId, strSearchText: strSearchText, swarmCreated: {[weak self] conversationId, accountId in
            self?.viewModel.showConversation(withConversationId: conversationId, andWithAccountId: accountId)
        })
        let contentView = UIHostingController(rootView: SwarmCreationUI(list: model))
        addChild(contentView)
        view.addSubview(contentView.view)
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        self.configureNavigationBar()
        self.setupSearchBar()
        continueButton.rx.tap
            .subscribe(onNext: { [weak model] in
                guard let model = model else { return }
                model.createTheSwarm()
            })
            .disposed(by: self.disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.clear.cgColor
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                                    NSAttributedString.Key.foregroundColor: UIColor.jamiLabelColor]
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // Waiting for screen size change
        DispatchQueue.global(qos: .background).async {
            sleep(UInt32(0.5))
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      UIDevice.current.portraitOrLandscape else { return }
                self.searchController.sizeChanged(to: size.width, totalItems: 0.0)
            }
        }
        super.viewWillTransition(to: size, with: coordinator)
    }

    override func viewDidAppear(_ animated: Bool) {
        self.searchController.sizeChanged(to: self.view.frame.size.width, totalItems: 0.0)
        super.viewDidAppear(animated)
    }

    func setupSearchBar() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = L10n.Swarmcreation.searchBar
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        self.strSearchText.accept(searchText)
    }

    @objc
    func backButtonTapped() {
        // Handle the back action
        // For instance, pop the current view controller from the navigation stack
        self.navigationController?.popViewController(animated: true)
    }
}
