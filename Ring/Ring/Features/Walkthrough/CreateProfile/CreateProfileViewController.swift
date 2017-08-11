//
//  CreateProfileViewController.swift
//  Ring
//
//  Created by Thibault Wittemberg on 2017-07-18.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit
import Reusable
import RxSwift

class CreateProfileViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var skipButton: DesignableButton!

    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: CreateProfileViewModel!

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Bind ViewModel to View
        self.viewModel.skipButtonTitle.bind(to: self.skipButton.rx.title(for: .normal)).disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
        self.skipButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.proceedWithAccountCreationOrDeviceLink()
        }).disposed(by: self.disposeBag)
    }

}
