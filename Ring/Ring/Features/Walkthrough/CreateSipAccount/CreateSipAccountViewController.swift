/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
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

class CreateSipAccountViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: CreateSipAccountViewModel!

    @IBOutlet weak var createAccountButton: DesignableButton!
    @IBOutlet weak var passwordTextField: DesignableTextField!
    @IBOutlet weak var userNameTextField: DesignableTextField!
    @IBOutlet weak var serverTextField: DesignableTextField!
    @IBOutlet weak var portTextField: DesignableTextField!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var createAccountLabel: UILabel!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var serverLabel: UILabel!
    @IBOutlet weak var portLabel: UILabel!
    @IBOutlet weak var backgroundView: UIView!

    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    var disposeBag = DisposeBag()

    override func viewDidLoad() {
        self.applyL10n()
        super.viewDidLoad()
        self.buindViewToViewModel()
        self.userNameTextField.becomeFirstResponder()
        self.configurePasswordField()
        self.createAccountButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        // handle keyboard
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        adaptToSystemColor()
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        backgroundView.backgroundColor = UIColor.jamiBackgroundColor
        scrollView.backgroundColor = UIColor.jamiBackgroundColor
        createAccountLabel.textColor = UIColor.jamiTextSecondary
        userNameLabel.textColor = UIColor.jamiTextSecondary
        passwordLabel.textColor = UIColor.jamiTextSecondary
        serverLabel.textColor = UIColor.jamiTextSecondary
        portLabel.textColor = UIColor.jamiTextSecondary
        userNameTextField.backgroundColor = UIColor.jamiBackgroundColor
        passwordTextField.backgroundColor = UIColor.jamiBackgroundColor
        serverTextField.backgroundColor = UIColor.jamiBackgroundColor
        portTextField.backgroundColor = UIColor.jamiBackgroundColor
        userNameTextField.borderColor = UIColor.jamiTextBlue
        passwordTextField.borderColor = UIColor.jamiTextBlue
        serverTextField.borderColor = UIColor.jamiTextBlue
        portTextField.borderColor = UIColor.jamiTextBlue
    }

    @objc func dismissKeyboard() {
        self.isKeyboardOpened = false
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    func configurePasswordField() {
        let isSecureTextEntry = PublishSubject<Bool>()
        let rightButton  = UIButton(type: .custom)
        rightButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        rightButton.setImage(UIImage(asset: Asset.icHideInput), for: .normal)
        passwordTextField.rx.text.orEmpty.distinctUntilChanged().bind { text in
            rightButton.isHidden = text.isEmpty
            rightButton.isEnabled = !text.isEmpty
        }.disposed(by: self.disposeBag)
        passwordTextField.rightViewMode = .always
        let rightView = UIView(frame: CGRect( x: 0, y: 0, width: 50, height: 30))
        rightView.addSubview(rightButton)
        passwordTextField.rightView = rightView
        passwordTextField.leftViewMode = .always
        let leftView = UIView(frame: CGRect( x: 0, y: 0, width: 50, height: 30))
        rightButton.tintColor = UIColor.darkGray
        passwordTextField.leftView = leftView
        rightButton.rx.tap
            .subscribe(onNext: { [unowned self, isSecureTextEntry] _ in
                self.passwordTextField.isSecureTextEntry.toggle()
                isSecureTextEntry
                    .onNext(self.passwordTextField.isSecureTextEntry)
            }).disposed(by: self.disposeBag)
        isSecureTextEntry.asObservable()
            .subscribe(onNext: { [weak rightButton] secure in
                let image = secure ?
                    UIImage(asset: Asset.icHideInput) :
                    UIImage(asset: Asset.icShowInput)
                rightButton?.setImage(image, for: .normal)
            }).disposed(by: self.disposeBag)
    }

    func buindViewToViewModel() {
        self.userNameTextField.rx.text.orEmpty.throttle(3, scheduler: MainScheduler.instance).distinctUntilChanged().bind(to: self.viewModel.userName).disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty.bind(to: self.viewModel.password).disposed(by: self.disposeBag)
        self.serverTextField.rx.text.orEmpty.bind(to: self.viewModel.sipServer).disposed(by: self.disposeBag)
        self.portTextField.rx.text.orEmpty
            .bind(to: self.viewModel.port)
            .disposed(by: self.disposeBag)
        self.createAccountButton.rx.tap
            .subscribe(onNext: { [unowned self] in
            DispatchQueue.global(qos: .background).async {
                self.viewModel.createSipaccount()
            }
        }).disposed(by: self.disposeBag)
    }

    func applyL10n() {
        self.createAccountButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        self.createAccountLabel.text = L10n.Account.createSipAccount
        self.userNameLabel.text = L10n.Account.usernameLabel
        self.passwordLabel.text = L10n.Account.passwordLabel
        self.serverLabel.text = L10n.Account.serverLabel
        self.portLabel.text = L10n.Account.portLabel
        self.passwordTextField.placeholder = L10n.Account.sipPassword
        self.userNameTextField.placeholder = L10n.Account.sipUsername
        self.serverTextField.placeholder = L10n.Account.sipServer
        self.portTextField.placeholder = L10n.Account.port
    }
}
