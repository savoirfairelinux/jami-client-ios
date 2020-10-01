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
import AMPopTip
import SwiftyBeaver

class LinkDeviceViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var linkButton: DesignableButton!
    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinTextField: DesignableTextField!
    @IBOutlet weak var passwordTextField: DesignableTextField!
    @IBOutlet weak var pinInfoButton: UIButton!
    @IBOutlet weak var pinLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var enableNotificationsLabel: UILabel!
    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: LinkDeviceViewModel!
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    let popTip = PopTip()

    let log = SwiftyBeaver.self

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Style
        self.pinTextField.becomeFirstResponder()
        self.configureWalkrhroughNavigationBar()
        self.view.layoutIfNeeded()
        self.linkButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        linkButton.titleLabel?.ajustToTextSize()

        self.pinTextField.tintColor = UIColor.jamiSecondary
        self.passwordTextField.tintColor = UIColor.jamiSecondary
        adaptToSystemColor()

        self.applyL10n()

        //bind view model to view
        self.pinInfoButton.rx.tap
            .subscribe(onNext: { [weak self] (_) in
                self?.showPinInfo()
            })
            .disposed(by: self.disposeBag)

        self.linkButton.rx.tap
            .subscribe(onNext: { [weak self] (_) in
                self?.viewModel.linkDevice()
            })
            .disposed(by: self.disposeBag)

        // handle linking state
        self.viewModel.createState
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .started:
                    self?.showCreationHUD()
                case .success:
                    self?.hideHud()
                    self?.showLinkedSuccess()
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
            })
            .disposed(by: self.disposeBag)

        self.viewModel.linkButtonEnabledState.bind(to: self.linkButton.rx.isEnabled)
            .disposed(by: self.disposeBag)

        // bind view to view model
        self.pinTextField.rx.text.orEmpty.bind(to: self.viewModel.pin).disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty.bind(to: self.viewModel.password).disposed(by: self.disposeBag)
        self.notificationsSwitch.rx.isOn.bind(to: self.viewModel.notificationSwitch).disposed(by: self.disposeBag)

        // handle keyboard
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
        .observeOn(MainScheduler.instance)
        .subscribe(onNext: { [weak self] (_) in
            guard UIDevice.current.portraitOrLandscape else { return }
            self?.linkButton.updateGradientFrame()
            self?.configureWalkrhroughNavigationBar()
        })
        .disposed(by: self.disposeBag)
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        scrollView.backgroundColor = UIColor.jamiBackgroundColor
        pinLabel.textColor = UIColor.jamiTextSecondary
        passwordLabel.textColor = UIColor.jamiTextSecondary
        enableNotificationsLabel.textColor = UIColor.jamiTextSecondary
        self.pinTextField.backgroundColor = UIColor.jamiBackgroundColor
        self.passwordTextField.backgroundColor = UIColor.jamiBackgroundColor
        self.pinTextField.borderColor = UIColor.jamiTextBlue
        self.passwordTextField.borderColor = UIColor.jamiTextBlue
        notificationsSwitch.tintColor = UIColor.jamiTextBlue
        pinInfoButton.tintColor = UIColor.jamiTextBlue
    }

    func setContentInset() {
        if !self.isKeyboardOpened {
            self.containerViewBottomConstraint.constant = -20
            return
        }
        let device = UIDevice.modelName
        switch device {
        case "iPhone X", "iPhone XS", "iPhone XS Max", "iPhone XR" :
            self.containerViewBottomConstraint.constant = -40
        default :
            self.containerViewBottomConstraint.constant = -65
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
        self.passwordLabel.text = L10n.LinkToAccount.passwordLabel
        self.pinTextField.placeholder = L10n.LinkToAccount.pinPlaceholder
        self.passwordTextField.placeholder = L10n.LinkToAccount.passwordPlaceholder
        self.navigationItem.title = L10n.LinkToAccount.linkButtonTitle
        self.enableNotificationsLabel.text = self.viewModel.enableNotificationsTitle
    }

    private func showCreationHUD() {
        HUD.show(.labeledProgress(title: L10n.LinkToAccount.waitLinkToAccountTitle, subtitle: nil))
    }

    private func showLinkedSuccess() {
        HUD.flash(.labeledSuccess(title: L10n.Alerts.accountLinkedTitle, subtitle: nil), delay: Durations.alertFlashDuration.value)
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

    private func showPinInfo() {
        if popTip.isVisible {
            popTip.hide()
        } else {
            popTip.shouldDismissOnTap = true
            popTip.entranceAnimation = .scale
            popTip.bubbleColor = UIColor.jamiSecondary
            popTip.textColor = UIColor.white
            let offset: CGFloat = 20.0
            popTip.offset = offset - scrollView.contentOffset.y
            popTip.show(text: L10n.LinkToAccount.explanationPinMessage, direction: .down,
                        maxWidth: 255, in: self.view, from: pinInfoButton.frame)
        }
    }
}
