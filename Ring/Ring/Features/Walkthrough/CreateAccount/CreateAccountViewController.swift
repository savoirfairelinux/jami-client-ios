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
import Reusable
import RxSwift

class CreateAccountViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var joinButton: DesignableButton!
    @IBOutlet weak var cancelButton: DesignableButton!
    @IBOutlet weak var userNameTitleLabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var registerUsernameErrorLabel: UILabel!

    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: CreateAccountViewModel!
    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    var loadingViewPresenter = LoadingViewPresenter()

    // MARK: functions
    override func viewDidLoad() {
        // L10n
        self.applyL10n()
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        configureWalkrhroughNavigationBar()

        // Style
        joinButton.titleLabel?.ajustToTextSize()
        self.usernameTextField.becomeFirstResponder()
        self.usernameTextField.tintColor = UIColor.jamiSecondary
        self.joinButton.tintColor = .jamiButtonDark

        // Bind ViewModel to View
        self.bindViewModelToView()

        // Bind Voew to ViewModel
        self.bindViewToViewModel()

        // handle keyboard
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        //        NotificationCenter.default.rx
        //            .notification(UIDevice.orientationDidChangeNotification)
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] (_) in
        //                guard UIDevice.current.portraitOrLandscape else { return }
        //                self?.configureWalkrhroughNavigationBar()
        //                if self?.registerPasswordView.isHidden ?? true {
        //                    return
        //                }
        //                guard let height = self?.passwordInfoLabel.frame.height else { return }
        //                self?.choosePasswordViewHeightConstraint.constant = 133 + height
        //                self?.view.layoutIfNeeded()
        //            })
        //            .disposed(by: self.disposeBag)
        adaptToSystemColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        //        registerUsernameLabel.textColor = UIColor.jamiTextSecondary
        //        recommendedLabel.textColor = UIColor.jamiTextSecondary
        //        chooseAPasswordLabel.textColor = UIColor.jamiTextSecondary
        //        enableNotificationsLabel.textColor = UIColor.jamiTextSecondary
        //        passwordInfoLabel.textColor = UIColor.jamiTextBlue
        //        registerPasswordView.backgroundColor = UIColor.jamiBackgroundColor
        //        registerUsernameView.backgroundColor = UIColor.jamiBackgroundColor
        //        usernameTextField.backgroundColor = UIColor.jamiBackgroundColor
        //        passwordTextField.backgroundColor = UIColor.jamiBackgroundColor
        //        confirmPasswordTextField.backgroundColor = UIColor.jamiBackgroundColor
        //        usernameTextField.borderColor = UIColor.jamiTextBlue
        //        passwordTextField.borderColor = UIColor.jamiTextBlue
        //        confirmPasswordTextField.borderColor = UIColor.jamiTextBlue
        //        usernameSwitch.tintColor = UIColor.jamiTextBlue
        //        passwordSwitch.tintColor = UIColor.jamiTextBlue
        //        notificationsSwitch.tintColor = UIColor.jamiTextBlue
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
        self.view.addGestureRecognizer(keyboardDismissTapRecognizer)

        if let userInfo = notification.userInfo,
           let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardFrame.size.height
            self.setContentInset(keyboardHeight: keyboardHeight)
        }
    }

    @objc
    func keyboardWillDisappear(withNotification: NSNotification) {
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
        self.setContentInset()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    private func applyL10n() {
        self.joinButton
            .setTitle(self.viewModel.createAccountButton, for: .normal)
        self.usernameTextField.placeholder = "Recommended"
        self.userNameTitleLabel.text = self.viewModel.usernameTitle
        self.navigationItem.title = self.viewModel.createAccountTitle
    }

    private func bindViewModelToView() {

        self.viewModel.canAskForAccountCreation.bind(to: self.joinButton.rx.isEnabled)
            .disposed(by: self.disposeBag)

        // handle registration error
        self.viewModel.usernameValidationState.asObservable()
            .map { $0.isDefault }
            .skip(until: self.usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .bind(to: self.registerUsernameErrorLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.usernameValidationState.asObservable()
            .map { $0.message }
            .skip(until: self.usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .bind(to: self.registerUsernameErrorLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.viewModel.usernameValidationState.asObservable()
            .map { $0.isAvailable }
            .skip(until: self.usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] available in
                self?.registerUsernameErrorLabel.textColor = available ? UIColor.jamiSuccess : UIColor.jamiFailure
            }
            .disposed(by: self.disposeBag)

        // handle creation state
        self.viewModel.createState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .started:
                    self?.showAccountCreationInProgress()
                case .success:
                    self?.hideAccountCreationHud()
                case .nameNotRegistered:
                    self?.hideAccountCreationHud()
                    self?.showNameNotRegistered()
                case .timeOut:
                    self?.hideAccountCreationHud()
                    self?.showTimeOutAlert()
                default:
                    self?.hideAccountCreationHud()
                }
            }, onError: { [weak self] (error) in
                self?.hideAccountCreationHud()

                if let error = error as? AccountCreationError {
                    self?.showAccountCreationError(error: error)
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func bindViewToViewModel() {
        // Bind View Outlets to ViewModel

        self.usernameTextField
            .rx
            .text
            .orEmpty
            .throttle(Durations.threeSeconds.toTimeInterval(),
                      scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: self.viewModel.username)
            .disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
        self.joinButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.createAccount()
                }
            })
            .disposed(by: self.disposeBag)

        self.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            })
            .disposed(by: self.disposeBag)
    }

    private func showAccountCreationInProgress() {
        loadingViewPresenter.presentWithMessage(message: L10n.CreateAccount.loading, presentingVC: self, animated: true)
    }

    private func hideAccountCreationHud() {
        loadingViewPresenter.hide(animated: false)
    }

    private func showAccountCreationError(error: AccountCreationError) {
        let alert = UIAlertController.init(title: error.title,
                                           message: error.message,
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L10n.Global.ok, style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showNameNotRegistered() {
        let alert = UIAlertController
            .init(title: L10n.CreateAccount.usernameNotRegisteredTitle,
                  message: L10n.CreateAccount.usernameNotRegisteredMessage,
                  preferredStyle: .alert)
        let okAction =
            UIAlertAction(title: L10n.Global.ok,
                          style: .default) { [weak self](_: UIAlertAction!) -> Void in
                self?.viewModel.finish()
            }
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }

    private func showTimeOutAlert() {
        let alert = UIAlertController
            .init(title: L10n.CreateAccount.timeoutTitle,
                  message: L10n.CreateAccount.timeoutMessage,
                  preferredStyle: .alert)
        let okAction =
            UIAlertAction(title: L10n.Global.ok,
                          style: .default) { [weak self](_: UIAlertAction!) -> Void in
                self?.viewModel.finish()
            }
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
}
