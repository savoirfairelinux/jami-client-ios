//
//  SwarmSettingsViewController.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Reusable
import UIKit
import RxSwift
import RxCocoa
import SwiftUI

class SwarmInfoViewController: UIViewController, StoryboardBased, ViewModelBased {

    var viewModel: SwarmInfoViewModel!
    let disposeBag = DisposeBag()
    var contentView: UIHostingController<TopProfileView>! = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        contentView = UIHostingController(rootView: TopProfileView(viewmodel: viewModel))
        addChild(contentView)
        view.addSubview(contentView.view)
        setupConstraints()
    }

    func setupConstraints() {
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
}
