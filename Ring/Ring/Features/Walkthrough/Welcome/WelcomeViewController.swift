/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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
import RxSwift
import RxCocoa
import Reusable

class WelcomeViewController: UIViewController, StoryboardBased {

    // MARK: outlets
    @IBOutlet weak var welcomeTitleLabel: UILabel!
    @IBOutlet weak var welcomeTextLabel: UILabel!
    @IBOutlet weak var linkDeviceButton: DesignableButton!
    @IBOutlet weak var createAccountButton: DesignableButton!

    // MARK: members
    private let disposeBag = DisposeBag()

    // MARK: functions
//    public static func instantiate(with viewModel: WelcomeViewModel) -> WelcomeViewController {
//        let viewController = WelcomeViewController.instantiate()
//        viewController.viewModel = viewModel
//        return viewController
//    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
//        self.viewModel.welcomeTitle.bind(to: self.welcomeTitleLabel.rx.text).disposed(by: self.disposeBag)
//        self.viewModel.welcomeText.bind(to: self.welcomeTextLabel.rx.text).disposed(by: self.disposeBag)
//        self.viewModel.createAccountText.bind(to: self.createAccountButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
//        self.viewModel.linkDeviceText.bind(to: self.linkDeviceButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }

}
