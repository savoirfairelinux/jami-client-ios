/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
*
*  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import PKHUD

class LinkToAccountManagerViewController: UIViewController, StoryboardBased, ViewModelBased {
var viewModel: LinkToAccountManagerViewModel!

    @IBOutlet weak var signInButton: DesignableButton!
    @IBOutlet weak var passwordTextField: DesignableTextField!
    @IBOutlet weak var userNameTextField: DesignableTextField!
    @IBOutlet weak var accountManagerTextField: DesignableTextField!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var accountManagerLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var enableNotificationsLabel: UILabel!
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.bindViewToViewModel()
        self.applyL10()
        self.view.layoutIfNeeded()
        self.userNameTextField.becomeFirstResponder()
        self.signInButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        signInButton.titleLabel?.ajustToTextSize()
        configureWalkrhroughNavigationBar()
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
        .observeOn(MainScheduler.instance)
        .subscribe(onNext: { [weak self] (_) in
            self?.signInButton.updateGradientFrame()
            self?.configureWalkrhroughNavigationBar()
        }).disposed(by: self.disposeBag)
        adaptToSystemColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    @objc func dismissKeyboard() {
        self.isKeyboardOpened = false
        view.endEditing(true)
        self.view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc func keyboardWillAppear(withNotification: NSNotification) {
        self.isKeyboardOpened = true
        self.view.addGestureRecognizer(keyboardDismissTapRecognizer)
    }

    func bindViewToViewModel() {
        self.userNameTextField.rx.text.orEmpty
            .throttle(3, scheduler: MainScheduler.instance).distinctUntilChanged()
            .bind(to: self.viewModel.userName)
            .disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty
            .bind(to: self.viewModel.password)
            .disposed(by: self.disposeBag)
        self.accountManagerTextField.rx.text.orEmpty
            .bind(to: self.viewModel.manager).disposed(by: self.disposeBag)
        self.signInButton.rx.tap
            .subscribe(onNext: { [unowned self] in
            DispatchQueue.global(qos: .background).async {
                self.viewModel.linkToAccountManager()
            }
        }).disposed(by: self.disposeBag)
        self.viewModel.createState
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .started:
                    self?.showLinkHUD()
                case .success:
                    self?.hideHud()
                case .error (let error):
                    self?.hideHud()
                    self?.showAccountCreationError(error: error)
                default:
                    self?.hideHud()
                }
                }, onError: { [weak self] (error) in
                    self?.hideHud()

                    if let error = error as? AccountCreationError {
                        self?.showAccountCreationError(error: error)
                    }
            }).disposed(by: self.disposeBag)
        self.viewModel.canLink.bind(to: self.signInButton.rx.isEnabled)
            .disposed(by: self.disposeBag)
        self.notificationsSwitch.rx.isOn.bind(to: self.viewModel.notificationSwitch).disposed(by: self.disposeBag)
    }

    private func showLinkHUD() {
        HUD.show(.labeledProgress(title: L10n.LinkToAccountManager.signIn, subtitle: nil))
    }

    private func hideHud() {
        HUD.hide()
    }

    private func showAccountCreationError(error: AccountCreationError) {
        let alert = UIAlertController.init(title: error.title,
                                           message: error.message,
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L10n.Global.ok, style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    func applyL10() {
        signInButton.setTitle(L10n.LinkToAccountManager.signIn, for: .normal)
        self.navigationItem.title = L10n.LinkToAccountManager.signIn
        passwordTextField.placeholder = L10n.LinkToAccountManager.passwordPlaceholder
        userNameTextField.placeholder = L10n.LinkToAccountManager.usernamePlaceholder
        accountManagerTextField.placeholder = L10n.LinkToAccountManager.accountManagerPlaceholder
        userNameLabel.text = L10n.LinkToAccountManager.usernameLabel
        passwordLabel.text = L10n.LinkToAccountManager.passwordLabel
        accountManagerLabel.text = L10n.LinkToAccountManager.accountManagerLabel
        self.enableNotificationsLabel.text = L10n.CreateAccount.enableNotifications
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        scrollView.backgroundColor = UIColor.jamiBackgroundColor
        userNameLabel.textColor = UIColor.jamiTextSecondary
        passwordLabel.textColor = UIColor.jamiTextSecondary
        accountManagerLabel.textColor = UIColor.jamiTextSecondary
        enableNotificationsLabel.textColor = UIColor.jamiTextSecondary
        userNameTextField.backgroundColor = UIColor.jamiBackgroundColor
        passwordTextField.backgroundColor = UIColor.jamiBackgroundColor
        accountManagerTextField.backgroundColor = UIColor.jamiBackgroundColor
        userNameTextField.borderColor = UIColor.jamiTextBlue
        passwordTextField.borderColor = UIColor.jamiTextBlue
        accountManagerTextField.borderColor = UIColor.jamiTextBlue
        notificationsSwitch.tintColor = UIColor.jamiTextBlue
    }
}
