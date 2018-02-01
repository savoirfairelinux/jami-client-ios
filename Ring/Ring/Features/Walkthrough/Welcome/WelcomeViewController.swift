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

class WelcomeViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: WelcomeViewModel!

    typealias VMType = WelcomeViewModel
    // MARK: outlets
    @IBOutlet weak var welcomeTextLabel: UILabel!
    @IBOutlet weak var linkDeviceButton: DesignableButton!
    @IBOutlet weak var createAccountButton: DesignableButton!

    // MARK: members
    private let disposeBag = DisposeBag()

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Bind ViewModel to View
        self.viewModel.welcomeText.bind(to: self.welcomeTextLabel.rx.text).disposed(by: self.disposeBag)
        self.viewModel.createAccount.bind(to: self.createAccountButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        self.viewModel.linkDevice.bind(to: self.linkDeviceButton.rx.title(for: .normal)).disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
        self.createAccountButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.proceedWithAccountCreation()
        }).disposed(by: self.disposeBag)

        self.linkDeviceButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.proceedWithLinkDevice()
        }).disposed(by: self.disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
    }

}
