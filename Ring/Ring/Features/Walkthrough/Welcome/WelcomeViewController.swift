/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
    @IBOutlet weak var createSipAccountButton: DesignableButton!
    @IBOutlet weak var connectToAccountManagerButton: DesignableButton!

    // MARK: constraints
    @IBOutlet weak var ringLogoBottomConstraint: NSLayoutConstraint!

    // MARK: members
    private let disposeBag = DisposeBag()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        self.applyL10n()
        if self.viewModel.isAnimatable {
           self.initialAnimation()
        } else {
            self.ringLogoBottomConstraint.constant = -220
            self.welcomeTextLabel.alpha = 1
            self.createAccountButton.alpha = 1
            self.linkDeviceButton.alpha = 1
            self.createSipAccountButton.alpha = 1
            self.connectToAccountManagerButton.alpha = 1
        }
        self.createAccountButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.linkDeviceButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.connectToAccountManagerButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        // Bind ViewModel to View
        self.viewModel.welcomeText.bind(to: self.welcomeTextLabel.rx.text).disposed(by: self.disposeBag)
        self.viewModel.createAccount.bind(to: self.createAccountButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        self.viewModel.linkDevice.bind(to: self.linkDeviceButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        createSipAccountButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        if !self.viewModel.notCancelable {
            let cancelButton = UIButton(type: .custom)
            cancelButton.setTitleColor(.jamiMain, for: .normal)
            cancelButton.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 25)
            cancelButton.setTitle(L10n.Actions.cancelAction, for: .normal)
            cancelButton.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
            let buttonItem = UIBarButtonItem(customView: cancelButton)
            cancelButton.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
                .subscribe(onNext: { [unowned self] in
                    self.viewModel.cancelWalkthrough()
                })
                .disposed(by: self.disposeBag)
            self.navigationItem.leftBarButtonItem = buttonItem
        }
        Observable.just(self.viewModel.notCancelable).bind(to: self.createSipAccountButton.rx.isHidden).disposed(by: self.disposeBag)
        Observable.just(!self.viewModel.notCancelable).bind(to: self.createSipAccountButton.rx.isEnabled).disposed(by: self.disposeBag)
        // Bind View Actions to ViewModel
        self.createAccountButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.proceedWithAccountCreation()
        }).disposed(by: self.disposeBag)

        self.linkDeviceButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.proceedWithLinkDevice()
        }).disposed(by: self.disposeBag)

        self.createSipAccountButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.createSipAccount()
        }).disposed(by: self.disposeBag)

        self.connectToAccountManagerButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.linkToAccountManager()
        }).disposed(by: self.disposeBag)
        view.backgroundColor = UIColor.jamiBackgroundColor
        self.welcomeTextLabel.textColor = UIColor.jamiLabelColor
        self.createSipAccountButton.setTitleColor(UIColor.jamiTextBlue, for: .normal)
    }

    func applyL10n() {
        createSipAccountButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        linkDeviceButton.setTitle(L10n.Welcome.linkDevice, for: .normal)
        connectToAccountManagerButton
            .setTitle(L10n.Welcome.connectToManager, for: .normal)
        createAccountButton.setTitle(L10n.Welcome.createAccount, for: .normal)
        welcomeTextLabel.text = L10n.Welcome.title
    }

    func initialAnimation() {
        DispatchQueue.global(qos: .background).async {
            sleep(1)
            DispatchQueue.main.async { [weak self] in
                self?.ringLogoBottomConstraint.constant = -72
                UIView.animate(withDuration: 0.5, animations: {
                    self?.ringLogoBottomConstraint.constant = -220
                    self?.welcomeTextLabel.alpha = 1
                    self?.createAccountButton.alpha = 1
                    self?.linkDeviceButton.alpha = 1
                    self?.connectToAccountManagerButton.alpha = 1
                    self?.view.layoutIfNeeded()
                })
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.tintColor = UIColor.jamiSecondary
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
    }

}
