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

import AMPopTip
import Reusable
import RxSwift
import SwiftyBeaver
import UIKit

class LinkDeviceViewController: UIViewController, StoryboardBased, ViewModelBased {
    // MARK: outlets

    @IBOutlet var messageLabel: UILabel!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var contentView: UIView!
    @IBOutlet var cancelButton: DesignableButton!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var linkButton: DesignableButton!
    @IBOutlet var containerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var pinTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var pinLabel: UILabel!
    @IBOutlet var passwordLabel: UILabel!

    // MARK: members

    private let disposeBag = DisposeBag()
    var viewModel: LinkDeviceViewModel!
    var isKeyboardOpened: Bool = false
    let popTip = PopTip()
    var loadingViewPresenter = LoadingViewPresenter()
    weak var containerViewTopConstraint: NSLayoutConstraint?
    let formHeight: CGFloat = 214
    let messageLabelBottomPadding: CGFloat = 12 // The padding between the label and the fields

    let log = SwiftyBeaver.self

    // MARK: functions

    override func viewDidLoad() {
        super.viewDidLoad()
        // Style
        linkButton.titleLabel?.ajustToTextSize()

        adaptToSystemColor()
        configurePasswordField()

        applyL10n()
        setupUI()
        pinTextField.becomeFirstResponder()

        // bind view model to view

        linkButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                self?.viewModel.linkDevice()
            })
            .disposed(by: disposeBag)

        cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        // handle linking state
        viewModel.createState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                switch state {
                case .started:
                    self?.showCreationHUD()
                case .success:
                    self?.hideHud()
                    self?.showLinkedSuccess()
                case let .error(error):
                    self?.hideHud()
                    self?.showAccountCreationError(error: error)
                default:
                    self?.hideHud()
                }
            }, onError: { [weak self] error in
                self?.hideHud()

                if let error = error as? AccountCreationError {
                    self?.showAccountCreationError(error: error)
                }
            })
            .disposed(by: disposeBag)

        viewModel.linkButtonEnabledState
            .subscribe(onNext: { [weak self] isEnabled in
                DispatchQueue.main.async { [weak self] in
                    self?.linkButton.setTitleColor(
                        isEnabled ? .jamiButtonDark : .systemGray,
                        for: .normal
                    )
                }
            })
            .disposed(by: disposeBag)

        viewModel.linkButtonEnabledState.bind(to: linkButton.rx.isEnabled)
            .disposed(by: disposeBag)

        // bind view to view model
        pinTextField.rx.text.orEmpty.bind(to: viewModel.pin).disposed(by: disposeBag)
        passwordTextField.rx.text.orEmpty.bind(to: viewModel.password).disposed(by: disposeBag)

        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.setupUI()
            })
            .disposed(by: disposeBag)
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

    func setupUI() {
        let welcomeFormPresentationStyle = ScreenHelper.welcomeFormPresentationStyle()
        if welcomeFormPresentationStyle == .fullScreen {
            contentView.removeCorners()
            view.backgroundColor = .secondarySystemBackground
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.contentView.roundTopCorners(radius: 12)
            }
            view.backgroundColor = .clear
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setupConstraint()
            // Mark the view as needing layout and then force the layout immediately
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
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
            var scrollViewHeight: CGFloat = formHeight
            scrollViewHeight +=
                messageLabelBottomPadding // The padding between the label and the fields
            scrollViewHeight += messageLabel.frame.height

            newConstraint = contentView.heightAnchor.constraint(equalToConstant: scrollViewHeight)
        }

        // Activate the constraint
        newConstraint.isActive = true

        // Assign it to the property for later reference
        containerViewTopConstraint = newConstraint
    }

    func adaptToSystemColor() {
        pinTextField.tintColor = UIColor.jamiSecondary
        passwordTextField.tintColor = UIColor.jamiSecondary
        view.backgroundColor = .clear
    }

    func setContentInset(keyboardHeight: CGFloat = 0) {
        containerViewBottomConstraint.constant = keyboardHeight
    }

    func configurePasswordField() {
        passwordTextField.isSecureTextEntry = true
        let isSecureTextEntry = PublishSubject<Bool>()
        let rightButton = UIButton(type: .custom)
        rightButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        rightButton.setImage(UIImage(asset: Asset.icHideInput), for: .normal)
        passwordTextField.rx.text.orEmpty.distinctUntilChanged()
            .bind { [weak rightButton] text in
                rightButton?.isHidden = text.isEmpty
                rightButton?.isEnabled = !text.isEmpty
            }
            .disposed(by: disposeBag)
        passwordTextField.rightViewMode = .always
        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        rightView.addSubview(rightButton)
        passwordTextField.rightView = rightView
        rightButton.rx.tap
            .subscribe(onNext: { [weak self, weak isSecureTextEntry] _ in
                guard let self = self else { return }
                self.passwordTextField.isSecureTextEntry.toggle()
                isSecureTextEntry?
                    .onNext(self.passwordTextField.isSecureTextEntry)
            })
            .disposed(by: disposeBag)
        isSecureTextEntry.asObservable()
            .subscribe(onNext: { [weak rightButton] secure in
                let image = secure ?
                    UIImage(asset: Asset.icHideInput) :
                    UIImage(asset: Asset.icShowInput)
                rightButton?.setImage(image, for: .normal)
            })
            .disposed(by: disposeBag)
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

    override var canBecomeFirstResponder: Bool {
        return true
    }

    private func applyL10n() {
        linkButton.setTitle(L10n.LinkToAccount.linkButtonTitle, for: .normal)
        pinLabel.text = L10n.LinkToAccount.pinLabel
        passwordLabel.text = L10n.Global.enterPassword
        pinTextField.placeholder = L10n.LinkToAccount.pinPlaceholder
        passwordTextField.placeholder = L10n.Global.password
        titleLabel.text = L10n.LinkToAccount.linkDeviceTitle
        messageLabel.text = L10n.LinkToAccount.linkDeviceMessage
    }

    private func showCreationHUD() {
        loadingViewPresenter.presentWithMessage(
            message: L10n.CreateAccount.loading,
            presentingVC: self,
            animated: false,
            modalPresentationStyle: .overFullScreen
        )
    }

    private func showLinkedSuccess() {
        loadingViewPresenter.showSuccessAllert(
            message: L10n.Alerts.accountLinkedTitle,
            presentingVC: self,
            animated: true
        )
    }

    private func hideHud() {
        loadingViewPresenter.hide(animated: false)
    }

    private func showAccountCreationError(error: AccountCreationError) {
        let alert = UIAlertController(title: error.title,
                                      message: error.message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
