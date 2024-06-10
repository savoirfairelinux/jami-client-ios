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

class CreateSipAccountViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: CreateSipAccountViewModel!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var cancelButton: DesignableButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var createAccountButton: DesignableButton!
    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var serverTextField: UITextField!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var serverLabel: UILabel!

    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    var disposeBag = DisposeBag()
    weak var containerViewHeightConstraint: NSLayoutConstraint?
    let formHeight: CGFloat = 258

    override func viewDidLoad() {
        self.applyL10n()
        super.viewDidLoad()
        setupUI()
        self.buindViewToViewModel()
        self.userNameTextField.becomeFirstResponder()
        self.configurePasswordField()
        createAccountButton.titleLabel?.ajustToTextSize()
        adaptToSystemColor()

        self.adaptToWelcomeFormKeyboardState(for: self.scrollView, with: self.disposeBag)
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.setupUI()
            })
            .disposed(by: self.disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func adaptToSystemColor() {
        view.backgroundColor = .clear
        userNameTextField.tintColor = UIColor.jamiSecondary
        passwordTextField.tintColor = UIColor.jamiSecondary
        serverTextField.tintColor = UIColor.jamiSecondary
        createAccountButton.tintColor = .jamiButtonDark
    }

    func setContentInset(keyboardHeight: CGFloat = 0) {
        self.containerViewBottomConstraint.constant = keyboardHeight
    }

    @objc
    func keyboardWillAppear(withNotification notification: NSNotification) {
        self.isKeyboardOpened = true

        if let userInfo = notification.userInfo,
           let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           ScreenHelper.welcomeFormPresentationStyle() != .fullScreen {
            let keyboardHeight = keyboardFrame.size.height
            self.setContentInset(keyboardHeight: keyboardHeight)
        }
    }

    @objc
    func keyboardWillDisappear(withNotification: NSNotification) {
        self.setContentInset()
    }

    func setupUI() {
        let welcomeFormPresentationStyle = ScreenHelper.welcomeFormPresentationStyle()
        if welcomeFormPresentationStyle == .fullScreen {
            contentView.removeCorners()
            view.backgroundColor = .secondarySystemBackground
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.contentView.roundTopCorners(radius: 12)
            }
            view.backgroundColor = .clear
        }

        DispatchQueue.main.async { [weak self] in
            self?.setupConstraint()
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        }
    }

    func setupConstraint() {
        // Remove the existing top constraint (if it exists)
        containerViewHeightConstraint?.isActive = false
        containerViewHeightConstraint = nil

        // Create a new constraint with the desired relationship
        let newConstraint: NSLayoutConstraint
        if ScreenHelper.welcomeFormPresentationStyle() == .fullScreen || UIDevice.current.userInterfaceIdiom == .pad {
            newConstraint = contentView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.size.height)
        } else {
            newConstraint = contentView.heightAnchor.constraint(equalToConstant: formHeight)
        }

        // Activate the constraint
        newConstraint.isActive = true

        // Assign it to the property for later reference
        containerViewHeightConstraint = newConstraint
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
            .disposed(by: self.disposeBag)
        passwordTextField.rightViewMode = .always
        let rightView = UIView(frame: CGRect( x: 0, y: 0, width: 50, height: 30))
        rightView.addSubview(rightButton)
        passwordTextField.rightView = rightView
        rightButton.rx.tap
            .subscribe(onNext: { [weak self, weak isSecureTextEntry] _ in
                guard let self = self else { return }
                self.passwordTextField.isSecureTextEntry.toggle()
                isSecureTextEntry?
                    .onNext(self.passwordTextField.isSecureTextEntry)
            })
            .disposed(by: self.disposeBag)
        isSecureTextEntry.asObservable()
            .subscribe(onNext: { [weak rightButton] secure in
                let image = secure ?
                    UIImage(asset: Asset.icHideInput) :
                    UIImage(asset: Asset.icShowInput)
                rightButton?.setImage(image, for: .normal)
            })
            .disposed(by: self.disposeBag)
    }

    func buindViewToViewModel() {
        self.userNameTextField
            .rx
            .text
            .orEmpty
            .throttle(Durations.threeSeconds.toTimeInterval(),
                      scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: self.viewModel.userName)
            .disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty.bind(to: self.viewModel.password).disposed(by: self.disposeBag)
        self.serverTextField.rx.text.orEmpty.bind(to: self.viewModel.sipServer).disposed(by: self.disposeBag)
        self.createAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.createSipaccount()
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

    func applyL10n() {
        self.createAccountButton.setTitle(L10n.Account.configure, for: .normal)
        titleLabel.text = L10n.Account.sipAccount
        self.userNameLabel.text = L10n.Global.enterUsername
        self.passwordLabel.text = L10n.Global.enterPassword
        self.serverLabel.text = L10n.Account.serverLabel
        self.passwordTextField.placeholder = L10n.Global.password
        self.userNameTextField.placeholder = L10n.Global.username
        self.serverTextField.placeholder = L10n.Account.sipServer
    }
}
