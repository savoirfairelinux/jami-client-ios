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
import Reusable
import RxSwift

class CreateAccountViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var createAccountButton: DesignableButton!
    @IBOutlet weak var createAccountTitle: UILabel!
    @IBOutlet weak var registerUsernameHeightConstraint: NSLayoutConstraint! {
        didSet {
            self.registerUsernameHeightConstraintConstant = registerUsernameHeightConstraint.constant
        }
    }
    @IBOutlet weak var usernameSwitch: UISwitch!
    @IBOutlet weak var registerUsernameView: UIView!

    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: CreateAccountViewModel!
    var registerUsernameHeightConstraintConstant: CGFloat = 0.0

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Bind ViewModel to View
        self.viewModel.createAccountTitle.bind(to: self.createAccountTitle.rx.text).disposed(by: self.disposeBag)
        self.viewModel.createAccountButton.bind(to: self.createAccountButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        self.viewModel.registerUsername.asObservable().subscribe(onNext: { [unowned self] (isOn) in
            UIView.animate(withDuration: 0.5, animations: {
                if isOn {
                    self.registerUsernameHeightConstraint.constant = self.registerUsernameHeightConstraintConstant
                    self.registerUsernameView.alpha = 1.0
                } else {
                    self.registerUsernameHeightConstraint.constant = 0
                    self.registerUsernameView.alpha = 0.0
                }

                self.view.layoutIfNeeded()
            })
        }).disposed(by: self.disposeBag)

        // Bind View Outlets to ViewModel
        self.usernameSwitch.rx.isOn.bind(to: self.viewModel.registerUsername).disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
        self.createAccountButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.createAccount()
        }).disposed(by: self.disposeBag)

    }
}
