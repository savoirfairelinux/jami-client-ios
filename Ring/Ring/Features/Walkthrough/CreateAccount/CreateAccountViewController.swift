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
import PKHUD

class CreateAccountViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var createAccountButton: DesignableButton!
    @IBOutlet weak var registerUsernameHeightConstraint: NSLayoutConstraint! {
        didSet {
            self.registerUsernameHeightConstraintConstant = registerUsernameHeightConstraint.constant
        }
    }
    @IBOutlet weak var choosePasswordViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var usernameSwitch: UISwitch!
    @IBOutlet weak var passwordSwitch: UISwitch!
    @IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var registerUsernameView: UIView!
    @IBOutlet weak var registerPasswordView: UIView!
    @IBOutlet weak var registerUsernameLabel: UILabel!
    @IBOutlet weak var recommendedLabel: UILabel!
    @IBOutlet weak var registerUsernameErrorLabel: UILabel!
    @IBOutlet weak var passwordTextField: DesignableTextField!
    @IBOutlet weak var confirmPasswordTextField: DesignableTextField!
    @IBOutlet weak var passwordErrorLabel: UILabel!
    @IBOutlet weak var usernameTextField: DesignableTextField!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var chooseAPasswordLabel: UILabel!
    @IBOutlet weak var passwordInfoLabel: UILabel!
    @IBOutlet weak var enableNotificationsLabel: UILabel!
    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: CreateAccountViewModel!
    var registerUsernameHeightConstraintConstant: CGFloat = 0.0
    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false

    // MARK: functions
    override func viewDidLoad() {
        // L10n
        self.applyL10n()
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        configureWalkrhroughNavigationBar()

        // Style
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = true
        self.createAccountButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        createAccountButton.titleLabel?.ajustToTextSize()
        self.usernameTextField.becomeFirstResponder()
        self.usernameTextField.tintColor = UIColor.jamiSecondary
        self.passwordTextField.tintColor = UIColor.jamiSecondary
        self.confirmPasswordTextField.tintColor = UIColor.jamiSecondary

        // Bind ViewModel to View
        self.bindViewModelToView()

        // Bind Voew to ViewModel
        self.bindViewToViewModel()

        // handle keyboard
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.createAccountButton.updateGradientFrame()
                self?.configureWalkrhroughNavigationBar()
                if self?.registerPasswordView.isHidden ?? true {
                    return
                }
                guard let height = self?.passwordInfoLabel.frame.height else { return }
                self?.choosePasswordViewHeightConstraint.constant = 133 + height
                self?.view.layoutIfNeeded()
            })
            .disposed(by: self.disposeBag)
        adaptToSystemColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        scrollView.backgroundColor = UIColor.jamiBackgroundColor
        registerUsernameLabel.textColor = UIColor.jamiTextSecondary
        recommendedLabel.textColor = UIColor.jamiTextSecondary
        chooseAPasswordLabel.textColor = UIColor.jamiTextSecondary
        enableNotificationsLabel.textColor = UIColor.jamiTextSecondary
        passwordInfoLabel.textColor = UIColor.jamiTextBlue
        registerPasswordView.backgroundColor = UIColor.jamiBackgroundColor
        registerUsernameView.backgroundColor = UIColor.jamiBackgroundColor
        usernameTextField.backgroundColor = UIColor.jamiBackgroundColor
        passwordTextField.backgroundColor = UIColor.jamiBackgroundColor
        confirmPasswordTextField.backgroundColor = UIColor.jamiBackgroundColor
        usernameTextField.borderColor = UIColor.jamiTextBlue
        passwordTextField.borderColor = UIColor.jamiTextBlue
        confirmPasswordTextField.borderColor = UIColor.jamiTextBlue
        usernameSwitch.tintColor = UIColor.jamiTextBlue
        passwordSwitch.tintColor = UIColor.jamiTextBlue
        notificationsSwitch.tintColor = UIColor.jamiTextBlue
    }

    func setContentInset() {
        if !self.isKeyboardOpened {
            self.containerViewBottomConstraint.constant = -20
            return
        }
        let device = UIDevice.modelName
        switch device {
        case "iPhone X", "iPhone XS", "iPhone XS Max", "iPhone XR" :
            self.containerViewBottomConstraint.constant = 100
        default :
            self.containerViewBottomConstraint.constant = 70
        }
    }

    @objc
    func dismissKeyboard() {
        self.isKeyboardOpened = false
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc
    func keyboardWillAppear(withNotification: NSNotification) {
        self.isKeyboardOpened = true
        self.view.addGestureRecognizer(keyboardDismissTapRecognizer)
        self.setContentInset()

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
        self.createAccountButton
        .setTitle(self.viewModel.createAccountButton, for: .normal)
        self.usernameTextField.placeholder = self.viewModel.usernameTitle
        self.passwordTextField.placeholder = self.viewModel.passwordTitle
        self.confirmPasswordTextField.placeholder = self.viewModel.confirmPasswordTitle
        self.registerUsernameLabel.text = self.viewModel.registerAUserNameTitle
        self.chooseAPasswordLabel.text = self.viewModel.chooseAPasswordTitle
        self.passwordInfoLabel.text = self.viewModel.passwordInfoTitle
        self.enableNotificationsLabel.text = self.viewModel.enableNotificationsTitle
        self.recommendedLabel.text = self.viewModel.recommendedTitle
        self.navigationItem.title = self.viewModel.createAccountTitle
    }

    private func bindViewModelToView() {
        // handle username registration visibility
        self.viewModel.registerUsername.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (isOn) in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.3, animations: {
                    if isOn {
                        self.registerUsernameHeightConstraint.constant = self.registerUsernameHeightConstraintConstant
                        DispatchQueue.global(qos: .background).async {
                            usleep(300000)
                            DispatchQueue.main.async {
                                UIView.animate(withDuration: 0.3, animations: {
                                    self.registerUsernameView.alpha = 1.0
                                })
                            }
                        }
                    } else {
                        self.registerUsernameHeightConstraint.constant = 0
                        self.registerUsernameView.alpha = 0.0
                    }
                    self.setContentInset()
                    self.view.layoutIfNeeded()
                })
            })
            .disposed(by: self.disposeBag)

        self.viewModel.canAskForAccountCreation.bind(to: self.createAccountButton.rx.isEnabled)
            .disposed(by: self.disposeBag)

        // handle password error
        self.viewModel.passwordValidationState.map { $0.isValidated }
            .skipUntil(self.passwordTextField.rx.controlEvent(UIControl.Event.editingDidEnd))
            .bind(to: self.passwordErrorLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.passwordValidationState.map { $0.message }
            .skipUntil(self.passwordTextField.rx.controlEvent(UIControl.Event.editingDidEnd))
            .bind(to: self.passwordErrorLabel.rx.text)
            .disposed(by: self.disposeBag)

        // handle registration error
        self.viewModel.usernameValidationState.asObservable()
            .map { $0.isDefault }
            .skipUntil(self.usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .bind(to: self.registerUsernameErrorLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.usernameValidationState.asObservable()
            .map { $0.message }
            .skipUntil(self.usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .bind(to: self.registerUsernameErrorLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.viewModel.usernameValidationState.asObservable()
            .map { $0.isAvailable }
            .skipUntil(self.usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .observeOn(MainScheduler.instance)
            .subscribe { available in
                self.registerUsernameErrorLabel.textColor = available ? UIColor.jamiSuccess : UIColor.jamiFailure
            }
            .disposed(by: self.disposeBag)

        // handle creation state
        self.viewModel.createState
            .observeOn(MainScheduler.instance)
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

    private func managePasswordSwitch(isOn: Bool) {
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            if isOn {
                guard let height = self?.passwordInfoLabel.frame.height else { return }
                self?.registerPasswordView.isHidden = false
                self?.choosePasswordViewHeightConstraint.constant = 133 + height
                self?.view.layoutIfNeeded()
                DispatchQueue.global(qos: .background).async {
                    usleep(300000)
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.3, animations: {
                            self?.registerPasswordView.alpha = 1.0
                        })
                    }
                }
            } else {
                self?.choosePasswordViewHeightConstraint.constant = 0
                self?.registerPasswordView.alpha = 0.0
                self?.passwordTextField.text = ""
                self?.confirmPasswordTextField.text = ""
                self?.passwordErrorLabel.isHidden = true
                self?.registerPasswordView.isHidden = true
            }
            self?.setContentInset()
            self?.view.layoutIfNeeded()
        })
    }

    private func bindViewToViewModel() {
        // Bind View Outlets to ViewModel
        self.usernameSwitch.rx.isOn.bind(to: self.viewModel.registerUsername).disposed(by: self.disposeBag)
        self.passwordSwitch.rx.isOn
            .subscribe(onNext: { [weak self] isOn in
                self?.managePasswordSwitch(isOn: isOn)
            })
            .disposed(by: self.disposeBag)
        self.notificationsSwitch.rx.isOn.bind(to: self.viewModel.notificationSwitch).disposed(by: self.disposeBag)
        self.usernameTextField
            .rx
            .text
            .orEmpty
            .throttle(Durations.threeSeconds.toTimeInterval(),
                      scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: self.viewModel.username)
            .disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty.bind(to: self.viewModel.password).disposed(by: self.disposeBag)
        self.confirmPasswordTextField.rx.text.orEmpty.bind(to: self.viewModel.confirmPassword).disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
        self.createAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.showAccountCreationInProgress()
                }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.createAccount()
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func showAccountCreationInProgress() {
        HUD.show(.labeledProgress(title: L10n.CreateAccount.loading, subtitle: nil))
    }

    private func showAccountCreationSuccess() {
        HUD.flash(.labeledSuccess(title: L10n.Alerts.accountAddedTitle, subtitle: nil), delay: Durations.alertFlashDuration.value)
    }

    private func hideAccountCreationHud() {
        HUD.hide()
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
