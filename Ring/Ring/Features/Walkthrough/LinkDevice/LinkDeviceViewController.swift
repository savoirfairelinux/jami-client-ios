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

class LinkDeviceViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var linkButton: DesignableButton!

    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: LinkDeviceViewModel!

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        self.linkButton.rx.tap.subscribe(onNext: { [unowned self] (_) in
            self.viewModel.linkDevice()
        }).disposed(by: self.disposeBag)
    }

}
