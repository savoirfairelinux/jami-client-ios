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

import Reusable
import RxSwift
import UIKit

class LinkToAccountManagerViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: LinkToAccountManagerViewModel!

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var contentView: UIView!
    @IBOutlet var cancelButton: DesignableButton!
    @IBOutlet var signInButton: DesignableButton!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var userNameTextField: UITextField!
    @IBOutlet var accountManagerTextField: UITextField!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var passwordLabel: UILabel!
    @IBOutlet var accountManagerLabel: UILabel!

    @IBOutlet var containerViewBottomConstraint: NSLayoutConstraint!
    var isKeyboardOpened: Bool = false
    var disposeBag = DisposeBag()
    var loadingViewPresenter = LoadingViewPresenter()
    weak var containerViewTopConstraint: NSLayoutConstraint?
    let formHeight: CGFloat = 256

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewToViewModel()
        applyL10()
        view.layoutIfNeeded()
        configurePasswordField()
        userNameTextField.becomeFirstResponder()
        signInButton.titleLabel?.ajustToTextSize()

        adaptToWelcomeFormKeyboardState(for: scrollView, with: disposeBag)
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.setupUI()
            })
            .disposed(by: disposeBag)
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }

    func setupUI() {
        let welcomeFormPresentationStyle = ScreenHelper.welcomeFormPresentationStyle()

        if welcomeFormPresentationStyle == .fullScreen {
            contentView.removeCorners()
            view.backgroundColor = .secondarySystemBackground
        } else {
            contentView.roundTopCorners(radius: 12)
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
            newConstraint = contentView.heightAnchor.constraint(equalToConstant: formHeight)
        }

        // Activate the constraint
        newConstraint.isActive = true

        // Assign it to the property for later reference
        containerViewTopConstraint = newConstraint
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

    func bindViewToViewModel() {
        userNameTextField.rx.text.orEmpty
            .throttle(Durations.threeSeconds.toTimeInterval(), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: viewModel.userName)
            .disposed(by: disposeBag)
        passwordTextField.rx.text.orEmpty
            .bind(to: viewModel.password)
            .disposed(by: disposeBag)
        accountManagerTextField.rx.text.orEmpty
            .bind(to: viewModel.manager).disposed(by: disposeBag)
        signInButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.linkToAccountManager()
                }
            })
            .disposed(by: disposeBag)
        cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
        viewModel.createState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                switch state {
                case .started:
                    self?.showLinkHUD()
                case .success:
                    self?.hideHud()
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
        viewModel.canLink.bind(to: signInButton.rx.isEnabled)
            .disposed(by: disposeBag)
        viewModel.canLink
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isEnabled in
                self?.signInButton.setTitleColor(
                    isEnabled ? .jamiButtonDark : .systemGray,
                    for: .normal
                )
            })
            .disposed(by: disposeBag)
    }

    private func showLinkHUD() {
        loadingViewPresenter.presentWithMessage(
            message: L10n.LinkToAccountManager.signIn,
            presentingVC: self,
            animated: false,
            modalPresentationStyle: .overFullScreen
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

    func applyL10() {
        signInButton.setTitle(L10n.LinkToAccountManager.signIn, for: .normal)
        titleLabel.text = L10n.LinkToAccountManager.signIn
        navigationItem.title = L10n.LinkToAccountManager.signIn
        passwordTextField.placeholder = L10n.Global.password
        userNameTextField.placeholder = L10n.Global.username
        accountManagerTextField.placeholder = L10n.LinkToAccountManager.accountManagerPlaceholder
        userNameLabel.text = L10n.Global.enterUsername
        passwordLabel.text = L10n.Global.enterPassword
        accountManagerLabel.text = L10n.LinkToAccountManager.accountManagerLabel
    }

    func adaptToSystemColor() {
        view.backgroundColor = .clear
        userNameTextField.tintColor = UIColor.jamiSecondary
        passwordTextField.tintColor = UIColor.jamiSecondary
        accountManagerTextField.tintColor = UIColor.jamiSecondary

        signInButton.tintColor = UIColor.jamiButtonDark
    }
}
