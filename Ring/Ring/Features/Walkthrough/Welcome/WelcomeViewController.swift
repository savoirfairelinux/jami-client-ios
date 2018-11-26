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

    // MARK: constraints
    @IBOutlet weak var ringLogoBottomConstraint: NSLayoutConstraint!

    // MARK: members
    private let disposeBag = DisposeBag()

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initialAnimation()
        self.createAccountButton.applyGradient(with: [UIColor(hex: 0x1F4971, alpha: 1.0), UIColor(hex: 0x132F50, alpha: 1.0)], gradient: .horizontal)
        self.linkDeviceButton.applyGradient(with: [UIColor(hex: 0x1F4971, alpha: 1.0), UIColor(hex: 0x132F50, alpha: 1.0)], gradient: .horizontal)
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

    func initialAnimation() {
        DispatchQueue.global(qos: .background).async {
            sleep(1)
            DispatchQueue.main.async {
                self.ringLogoBottomConstraint.constant = -72
                UIView.animate(withDuration: 0.5, animations: {
                    self.ringLogoBottomConstraint.constant = -200
                    self.welcomeTextLabel.alpha = 1
                    self.createAccountButton.alpha = 1
                    self.linkDeviceButton.alpha = 1
                    self.view.layoutIfNeeded()
                })
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .default
        self.navigationController?.navigationBar.tintColor = UIColor.ringMain
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
    }

}
