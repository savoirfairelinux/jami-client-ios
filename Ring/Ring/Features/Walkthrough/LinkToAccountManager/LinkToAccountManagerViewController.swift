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

class LinkToAccountManagerViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: LinkToAccountManagerViewModel!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dismissView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var cancelButton: DesignableButton!
    @IBOutlet weak var signInButton: DesignableButton!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var accountManagerTextField: UITextField!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var accountManagerLabel: UILabel!

    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    var disposeBag = DisposeBag()
    var loadingViewPresenter = LoadingViewPresenter()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.bindViewToViewModel()
        self.applyL10()
        self.contentView.roundTopCorners(radius: 12)
        self.view.layoutIfNeeded()
        self.userNameTextField.becomeFirstResponder()
        signInButton.titleLabel?.ajustToTextSize()
        configureWalkrhroughNavigationBar()

        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.configureWalkrhroughNavigationBar()
            })
            .disposed(by: self.disposeBag)
        adaptToSystemColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func setContentInset(keyboardHeight: CGFloat = 0) {
        self.containerViewBottomConstraint.constant = keyboardHeight
    }

    @objc
    func dismissKeyboard() {
        self.isKeyboardOpened = false
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc
    func keyboardWillAppear(withNotification notification: NSNotification) {
        self.isKeyboardOpened = true
        self.dismissView.addGestureRecognizer(keyboardDismissTapRecognizer)

        if let userInfo = notification.userInfo,
           let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardFrame.size.height
            self.setContentInset(keyboardHeight: keyboardHeight)
        }
    }

    @objc
    func keyboardWillDisappear(withNotification: NSNotification) {
        dismissView.removeGestureRecognizer(keyboardDismissTapRecognizer)
        self.setContentInset()
    }

    func bindViewToViewModel() {
        self.userNameTextField.rx.text.orEmpty
            .throttle(Durations.threeSeconds.toTimeInterval(), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: self.viewModel.userName)
            .disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty
            .bind(to: self.viewModel.password)
            .disposed(by: self.disposeBag)
        self.accountManagerTextField.rx.text.orEmpty
            .bind(to: self.viewModel.manager).disposed(by: self.disposeBag)
        self.signInButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.linkToAccountManager()
                }
            })
            .disposed(by: self.disposeBag)
        self.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            })
            .disposed(by: self.disposeBag)
        self.viewModel.createState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .started:
                    self?.showLinkHUD()
                case .success:
                    self?.hideHud()
                case .error(let error):
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
            })
            .disposed(by: self.disposeBag)
        self.viewModel.canLink.bind(to: self.signInButton.rx.isEnabled)
            .disposed(by: self.disposeBag)
    }

    private func showLinkHUD() {
        loadingViewPresenter.presentWithMessage(message: L10n.LinkToAccountManager.signIn, presentingVC: self, animated: true)
    }

    private func hideHud() {
        loadingViewPresenter.hide(animated: false)
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
        titleLabel.text = L10n.LinkToAccountManager.signIn
        self.navigationItem.title = L10n.LinkToAccountManager.signIn
        passwordTextField.placeholder = L10n.Global.password
        userNameTextField.placeholder = L10n.Global.username
        accountManagerTextField.placeholder = L10n.LinkToAccountManager.accountManagerPlaceholder
        userNameLabel.text = L10n.Global.enterUsername
        passwordLabel.text = L10n.Global.enterPassword
        accountManagerLabel.text = L10n.LinkToAccountManager.accountManagerLabel
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        userNameLabel.textColor = UIColor.jamiTextSecondary
        passwordLabel.textColor = UIColor.jamiTextSecondary
        accountManagerLabel.textColor = UIColor.jamiTextSecondary
        userNameTextField.backgroundColor = UIColor.jamiBackgroundColor
        passwordTextField.backgroundColor = UIColor.jamiBackgroundColor
        accountManagerTextField.backgroundColor = UIColor.jamiBackgroundColor
        userNameTextField.borderColor = UIColor.jamiTextBlue
        passwordTextField.borderColor = UIColor.jamiTextBlue
        accountManagerTextField.borderColor = UIColor.jamiTextBlue
        signInButton.tintColor = UIColor.jamiButtonDark
    }
}
