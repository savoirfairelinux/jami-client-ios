/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

import Reusable
import RxSwift
import UIKit

class CreateAccountViewController: UIViewController, StoryboardBased, ViewModelBased {
    // MARK: outlets

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var contentView: UIView!
    @IBOutlet var dismissView: UIView!
    @IBOutlet var joinButton: DesignableButton!
    @IBOutlet var cancelButton: DesignableButton!
    @IBOutlet var userNameTitleLabel: UILabel!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var registerUsernameErrorLabel: UILabel!

    // MARK: members

    private let disposeBag = DisposeBag()
    var viewModel: CreateAccountViewModel!
    @IBOutlet var containerViewBottomConstraint: NSLayoutConstraint!
    var isKeyboardOpened: Bool = false
    var loadingViewPresenter = LoadingViewPresenter()
    weak var containerViewTopConstraint: NSLayoutConstraint?

    // MARK: functions

    override func viewDidLoad() {
        // L10n
        applyL10n()
        super.viewDidLoad()
        setupUI()
        contentView.roundTopCorners(radius: 12)
        view.layoutIfNeeded()
        configureWalkrhroughNavigationBar()
        setAccessibilityLabels()

        // Style
        joinButton.titleLabel?.ajustToTextSize()
        usernameTextField.accessibilityIdentifier = AccessibilityIdentifiers.usernameTextField
        usernameTextField.becomeFirstResponder()

        // Bind ViewModel to View
        bindViewModelToView()

        // Bind Voew to ViewModel
        bindViewToViewModel()

        adaptToSystemColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillAppear(withNotification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillDisappear(withNotification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        setupUI()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        setupUI()
    }

    private func setAccessibilityLabels() {
        joinButton.accessibilityIdentifier = AccessibilityIdentifiers.joinButton
        cancelButton.accessibilityIdentifier = AccessibilityIdentifiers.cancelCreatingAccount
        contentView.accessibilityIdentifier = AccessibilityIdentifiers.createAccountView
        titleLabel.accessibilityIdentifier = AccessibilityIdentifiers.createAccountTitle
        userNameTitleLabel.accessibilityIdentifier = AccessibilityIdentifiers
            .createAccountUserNameLabel
        registerUsernameErrorLabel.accessibilityIdentifier = AccessibilityIdentifiers
            .createAccountErrorLabel
    }

    func setupUI() {
        let welcomeFormPresentationStyle = ScreenHelper.welcomeFormPresentationStyle()
        setupConstraint()
        if welcomeFormPresentationStyle == .fullScreen {
            contentView.removeCorners()
            view.backgroundColor = .secondarySystemBackground
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.contentView.roundTopCorners(radius: 12)
            }
            view.backgroundColor = .clear
        }
        view.layoutIfNeeded()
    }

    func setupConstraint() {
        // Remove the existing top constraint (if it exists)
        containerViewTopConstraint?.isActive = false
        containerViewTopConstraint = nil

        // Create a new constraint with the desired relationship
        let newConstraint: NSLayoutConstraint
        if ScreenHelper.welcomeFormPresentationStyle() == .fullScreen || UIDevice.current
            .userInterfaceIdiom == .pad {
            newConstraint = contentView.heightAnchor
                .constraint(equalToConstant: UIScreen.main.bounds.size.height)
        } else {
            newConstraint = contentView.heightAnchor.constraint(equalToConstant: 200)
        }

        // Activate the constraint
        newConstraint.isActive = true

        // Assign it to the property for later reference
        containerViewTopConstraint = newConstraint
    }

    func adaptToSystemColor() {
        view.backgroundColor = .clear
        usernameTextField.tintColor = UIColor.jamiSecondary
        joinButton.tintColor = .jamiButtonDark
    }

    func setContentInset(keyboardHeight: CGFloat = 0) {
        containerViewBottomConstraint.constant = keyboardHeight
    }

    @objc
    func keyboardWillAppear(withNotification notification: NSNotification) {
        isKeyboardOpened = true

        if let userInfo = notification.userInfo,
           let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           ScreenHelper.welcomeFormPresentationStyle() != .fullScreen {
            let keyboardHeight = keyboardFrame.size.height
            setContentInset(keyboardHeight: keyboardHeight)
        }
    }

    @objc
    func keyboardWillDisappear(withNotification _: NSNotification) {
        setContentInset()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    private func applyL10n() {
        joinButton
            .setTitle(viewModel.createAccountButton, for: .normal)
        usernameTextField.placeholder = L10n.Global.recommended
        titleLabel.text = viewModel.createAccountTitle
        userNameTitleLabel.text = viewModel.usernameTitle
        navigationItem.title = viewModel.createAccountTitle
    }

    private func bindViewModelToView() {
        // handle registration error
        viewModel.usernameValidationState.asObservable()
            .map { $0.message }
            .skip(until: usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .bind(to: registerUsernameErrorLabel.rx.text)
            .disposed(by: disposeBag)
        viewModel.usernameValidationState.asObservable()
            .map { $0.isAvailable }
            .skip(until: usernameTextField.rx.controlEvent(UIControl.Event.editingDidBegin))
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] available in
                self?.registerUsernameErrorLabel.textColor = available ? UIColor
                    .jamiSuccess : UIColor.jamiFailure
            }
            .disposed(by: disposeBag)

        viewModel.canAskForAccountCreation
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] canAskForAccountCreation in
                self?.joinButton.tintColor = canAskForAccountCreation ? UIColor
                    .jamiButtonDark : .systemGray
            }
            .disposed(by: disposeBag)

        viewModel.canAskForAccountCreation.bind(to: joinButton.rx.isEnabled)
            .disposed(by: disposeBag)

        // handle creation state
        viewModel.createState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
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
            }, onError: { [weak self] error in
                self?.hideAccountCreationHud()

                if let error = error as? AccountCreationError {
                    self?.showAccountCreationError(error: error)
                }
            })
            .disposed(by: disposeBag)
    }

    private func bindViewToViewModel() {
        // Bind View Outlets to ViewModel

        usernameTextField
            .rx
            .text
            .orEmpty
            .observe(on: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: viewModel.username)
            .disposed(by: disposeBag)

        // Bind View Actions to ViewModel
        joinButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.createAccount()
                }
            })
            .disposed(by: disposeBag)

        cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }

    private func showAccountCreationInProgress() {
        loadingViewPresenter.presentWithMessage(
            message: L10n.CreateAccount.loading,
            presentingVC: self,
            animated: false,
            modalPresentationStyle: .overFullScreen
        )
    }

    private func hideAccountCreationHud() {
        loadingViewPresenter.hide(animated: false)
    }

    private func showAccountCreationError(error: AccountCreationError) {
        let alert = UIAlertController(title: error.title,
                                      message: error.message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func showNameNotRegistered() {
        let alert = UIAlertController
        (title: L10n.CreateAccount.usernameNotRegisteredTitle,
         message: L10n.CreateAccount.usernameNotRegisteredMessage,
         preferredStyle: .alert)
        let okAction =
            UIAlertAction(title: L10n.Global.ok,
                          style: .default) { [weak self] (_: UIAlertAction!) in
                self?.viewModel.finish()
            }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }

    private func showTimeOutAlert() {
        let alert = UIAlertController
        (title: L10n.CreateAccount.timeoutTitle,
         message: L10n.CreateAccount.timeoutMessage,
         preferredStyle: .alert)
        let okAction =
            UIAlertAction(title: L10n.Global.ok,
                          style: .default) { [weak self] (_: UIAlertAction!) in
                self?.viewModel.finish()
            }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
}
