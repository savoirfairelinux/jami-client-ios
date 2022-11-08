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
        self.navigationItem.title = L10n.SwarmCreation.title
        super.viewDidLoad()
        guard let accountId = self.viewModel.currentAccount?.id else { return }
        let conversation = ConversationModel()
        conversation.accountId = accountId

        let model = SwarmCreationUIModel(with: self.viewModel.injectionBag, conversation: conversation)
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
                self.searchController.sizeChanged(to: size.width, totalItems: 1.0)
            }
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
    override func viewDidAppear(_ animated: Bool) {
        self.searchController.sizeChanged(to: self.view.frame.size.width, totalItems: 1.0)
        super.viewDidAppear(animated)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // -50 from total width as number of buttons in navigation items is 1
        if let container = self.searchController.searchBar.superview {
            container.frame = CGRect(x: container.frame.origin.x, y: container.frame.origin.y, width: self.view.frame.size.width - 50, height: container.frame.size.height)
        }
    }
    func setupSearchBar() {
        guard let account = self.viewModel.currentAccount else { return }
        let accountSip = account.type == AccountType.sip
        let image = accountSip ? UIImage(asset: Asset.phoneBook) : UIImage(asset: Asset.qrCode)
        guard let buttonImage = image else { return }
        searchController
            .configureSearchBar(image: buttonImage, position: 1,
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

    @IBAction func openScan() {
        self.viewModel.showQRCode()
    }
}
