//
//  ContactListViewController.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import UIKit
import SwiftUI
import Reusable
import RxSwift
import RxRelay

class SwarmCreationViewController: UIViewController, ViewModelBased, StoryboardBased, UISearchResultsUpdating {
    var viewModel: SwarmCreationViewModel!
    var model: SwarmCreationUIModel!
    private let disposeBag = DisposeBag()

    let searchController: CustomSearchController = {
        let searchController = CustomSearchController(searchResultsController: nil)
        searchController.searchBar.searchBarStyle = .minimal
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.definesPresentationContext = true
        searchController.hidesNavigationBarDuringPresentation = true
        return searchController
    }()

    override func viewDidLoad() {
        self.navigationItem.title = L10n.SwarmCreation.title
        super.viewDidLoad()
        guard let accountId = self.viewModel.currentAccount?.id else { return }

        model = SwarmCreationUIModel(with: self.viewModel.injectionBag, accountId: accountId, swarmCreated: {
            self.dismiss(animated: false)
        })
        let contentView = UIHostingController(rootView: SwarmCreationUI(list: model))
        addChild(contentView)
        view.addSubview(contentView.view)
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        self.setupSearchBar()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                                    NSAttributedString.Key.foregroundColor: UIColor.jamiLabelColor]
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
        searchController.searchBar.placeholder = L10n.SwarmCreation.searchBar
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        model.strSearchText.accept(searchText)
    }
}
