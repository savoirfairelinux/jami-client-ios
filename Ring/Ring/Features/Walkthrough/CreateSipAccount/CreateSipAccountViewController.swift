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

import Reusable
import RxSwift
import UIKit

class CreateSipAccountViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: CreateSipAccountViewModel!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var cancelButton: DesignableButton!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var contentView: UIView!
    @IBOutlet var createAccountButton: DesignableButton!
    @IBOutlet var containerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var userNameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var serverTextField: UITextField!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var passwordLabel: UILabel!
    @IBOutlet var serverLabel: UILabel!

    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    var disposeBag = DisposeBag()
    weak var containerViewHeightConstraint: NSLayoutConstraint?
    let formHeight: CGFloat = 258

    override func viewDidLoad() {
        applyL10n()
        super.viewDidLoad()
        setupUI()
        buindViewToViewModel()
        userNameTextField.becomeFirstResponder()
        configurePasswordField()
        createAccountButton.titleLabel?.ajustToTextSize()
        adaptToSystemColor()

        adaptToWelcomeFormKeyboardState(for: scrollView, with: disposeBag)
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }

    func adaptToSystemColor() {
        view.backgroundColor = .clear
        userNameTextField.tintColor = UIColor.jamiSecondary
        passwordTextField.tintColor = UIColor.jamiSecondary
        serverTextField.tintColor = UIColor.jamiSecondary
        createAccountButton.tintColor = .jamiButtonDark
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
        if ScreenHelper.welcomeFormPresentationStyle() == .fullScreen || UIDevice.current
            .userInterfaceIdiom == .pad {
            newConstraint = contentView.heightAnchor
                .constraint(equalToConstant: UIScreen.main.bounds.size.height)
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

    func buindViewToViewModel() {
        userNameTextField
            .rx
            .text
            .orEmpty
            .throttle(Durations.threeSeconds.toTimeInterval(),
                      scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: viewModel.userName)
            .disposed(by: disposeBag)
        passwordTextField.rx.text.orEmpty.bind(to: viewModel.password).disposed(by: disposeBag)
        serverTextField.rx.text.orEmpty.bind(to: viewModel.sipServer).disposed(by: disposeBag)
        createAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.createSipaccount()
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

    func applyL10n() {
        createAccountButton.setTitle(L10n.Account.configure, for: .normal)
        titleLabel.text = L10n.Account.sipAccount
        userNameLabel.text = L10n.Global.enterUsername
        passwordLabel.text = L10n.Global.enterPassword
        serverLabel.text = L10n.Account.serverLabel
        passwordTextField.placeholder = L10n.Global.password
        userNameTextField.placeholder = L10n.Account.sipUsername
        serverTextField.placeholder = L10n.Account.sipServer
    }
}
