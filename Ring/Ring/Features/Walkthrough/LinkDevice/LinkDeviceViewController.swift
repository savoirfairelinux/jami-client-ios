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
import AMPopTip
import SwiftyBeaver

class LinkDeviceViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var dismissView: UIView!
    @IBOutlet weak var cancelButton: DesignableButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var linkButton: DesignableButton!
    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var pinLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: LinkDeviceViewModel!
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    let popTip = PopTip()
    var loadingViewPresenter = LoadingViewPresenter()

    let log = SwiftyBeaver.self

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Style
        self.pinTextField.becomeFirstResponder()
        self.configureWalkrhroughNavigationBar()
        self.view.layoutIfNeeded()
        linkButton.titleLabel?.ajustToTextSize()

        self.pinTextField.tintColor = UIColor.jamiSecondary
        self.passwordTextField.tintColor = UIColor.jamiSecondary
        adaptToSystemColor()

        self.applyL10n()

        // bind view model to view

        self.linkButton.rx.tap
            .subscribe(onNext: { [weak self] (_) in
                self?.viewModel.linkDevice()
            })
            .disposed(by: self.disposeBag)

        self.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            })
            .disposed(by: self.disposeBag)

        // handle linking state
        self.viewModel.createState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .started:
                    self?.showCreationHUD()
                case .success:
                    self?.hideHud()
                    self?.showLinkedSuccess()
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

        self.viewModel.linkButtonEnabledState.bind(to: self.linkButton.rx.isEnabled)
            .disposed(by: self.disposeBag)

        // bind view to view model
        self.pinTextField.rx.text.orEmpty.bind(to: self.viewModel.pin).disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty.bind(to: self.viewModel.password).disposed(by: self.disposeBag)

        // handle keyboard
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.configureWalkrhroughNavigationBar()
            })
            .disposed(by: self.disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.5) {
            self.dismissView.alpha = 1
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissView.alpha = 0
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        pinLabel.textColor = UIColor.jamiTextSecondary
        passwordLabel.textColor = UIColor.jamiTextSecondary
        linkButton.tintColor = .jamiButtonDark
    }

    func setContentInset() {
        if !self.isKeyboardOpened {
            self.containerViewBottomConstraint.constant = -20
            return
        }
        let device = UIDevice.modelName
        switch device {
        case "iPhone X", "iPhone XS", "iPhone XS Max", "iPhone XR":
            self.containerViewBottomConstraint.constant = -40
        default:
            self.containerViewBottomConstraint.constant = -65
        }
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

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func applyL10n() {
        self.linkButton.setTitle(L10n.LinkToAccount.linkButtonTitle, for: .normal)
        self.pinLabel.text = L10n.LinkToAccount.pinLabel
        self.passwordLabel.text = L10n.Global.enterPassword
        self.pinTextField.placeholder = L10n.LinkToAccount.pinPlaceholder
        self.passwordTextField.placeholder = L10n.Global.password
        self.titleLabel.text = L10n.LinkToAccount.linkDeviceTitle
    }

    private func showCreationHUD() {
        loadingViewPresenter.presentWithMessage(message: L10n.LinkToAccount.waitLinkToAccountTitle, presentingVC: self, animated: true)
    }

    private func showLinkedSuccess() {
        loadingViewPresenter.showSuccessAllert(message: L10n.Alerts.accountLinkedTitle, presentingVC: self, animated: true)
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
}
