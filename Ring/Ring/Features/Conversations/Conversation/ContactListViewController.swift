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

class ContactListViewController: UIViewController, ViewModelBased, StoryboardBased {
    var viewModel: ContactListViewModel!
    let contentView = UIHostingController(rootView: ContactListUI())

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
    func setupConstraints() {
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
}
