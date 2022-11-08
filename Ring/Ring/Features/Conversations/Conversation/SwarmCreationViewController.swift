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

class SwarmCreationViewController: UIViewController, ViewModelBased, StoryboardBased {
    var viewModel: SwarmCreationViewModel!
    private let disposeBag = DisposeBag()

    let contentView = UIHostingController(rootView: SwarmCreationUI())
    @IBOutlet weak var searchView: JamiSearchView!
    let searchController: CustomSearchController = {
        let searchController = CustomSearchController(searchResultsController: nil)
        searchController.searchBar.searchBarStyle = .minimal
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.definesPresentationContext = true
        searchController.hidesNavigationBarDuringPresentation = true
        return searchController
    }()

    override func viewDidLoad() {
        self.navigationItem.title = L10n.ContactList.title
        super.viewDidLoad()
        addChild(contentView)
        view.addSubview(contentView.view)
        self.setupConstraints()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                                    NSAttributedString.Key.foregroundColor: UIColor.jamiLabelColor]
    }
    func setupSearchBar() {
        print("Check Commit")
        guard let account = self.viewModel.currentAccount else { return }
        let accountSip = account.type == AccountType.sip
        let image = accountSip ? UIImage(asset: Asset.phoneBook) : UIImage(asset: Asset.qrCode)
        guard let buttonImage = image else { return }
        searchController
            .configureSearchBar(image: buttonImage, position: 0,
                                buttonPressed: { [weak self] in
                                    guard let self = self else { return }
                                    guard let account = self.viewModel.currentAccount else { return }
                                    let accountSip = account.type == AccountType.sip
                                    if accountSip {
                                        //                                        self.contactPicker.delegate = self
                                        //                                        self.present(self.contactPicker, animated: true, completion: nil)
                                    } else {
                                        self.openScan()
                                    }
                                })
        navigationItem.searchController = searchController

        navigationItem.hidesSearchBarWhenScrolling = false
        searchView.searchBar = searchController.searchBar
        self.searchView.editSearch
            .subscribe(onNext: {[weak self] (editing) in
                self?.viewModel.searching.onNext(editing)
            })
            .disposed(by: disposeBag)
    }

    func setupConstraints() {
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    @IBAction func openScan() {
        self.viewModel.showQRCode()
    }
}
