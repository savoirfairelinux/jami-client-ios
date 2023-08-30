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

import UIKit
import Reusable
import RxSwift

class LinkToAccountManagerViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: LinkToAccountManagerViewModel!

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var cancelButton: DesignableButton!
    @IBOutlet weak var signInButton: DesignableButton!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var accountManagerTextField: UITextField!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var accountManagerLabel: UILabel!

    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    var isKeyboardOpened: Bool = false
    var disposeBag = DisposeBag()
    var loadingViewPresenter = LoadingViewPresenter()
    weak var containerViewTopConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        self.bindViewToViewModel()
        self.applyL10()
        self.view.layoutIfNeeded()
        configurePasswordField()
        self.view.backgroundColor = .clear
        self.userNameTextField.becomeFirstResponder()
        signInButton.titleLabel?.ajustToTextSize()
        configureWalkrhroughNavigationBar()

        self.adaptToWelcomeFormKeyboardState(for: self.scrollView, with: self.disposeBag)
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.setupUI()
            })
            .disposed(by: self.disposeBag)
        adaptToSystemColor()
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

    func setupUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let welcomeFormPresentationStyle = ScreenHelper.welcomeFormPresentationStyle()
            self.setupConstraint()

            if welcomeFormPresentationStyle == .fullScreen {
                self.contentView.removeCorners()
                self.view.backgroundColor = .secondarySystemBackground
            } else {
                self.contentView.roundTopCorners(radius: 12)
                self.view.backgroundColor = .clear
            }

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
            .bind { text in
                rightButton.isHidden = text.isEmpty
                rightButton.isEnabled = !text.isEmpty
            }
            .disposed(by: self.disposeBag)
        passwordTextField.rightViewMode = .always
        let rightView = UIView(frame: CGRect( x: 0, y: 0, width: 50, height: 30))
        rightView.addSubview(rightButton)
        passwordTextField.rightView = rightView
        rightButton.rx.tap
            .subscribe(onNext: { [weak self, isSecureTextEntry] _ in
                guard let self = self else { return }
                self.passwordTextField.isSecureTextEntry.toggle()
                isSecureTextEntry
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

    func setupConstraint() {
        // Remove the existing top constraint (if it exists)
        containerViewTopConstraint?.isActive = false
        containerViewTopConstraint = nil

        // Create a new constraint with the desired relationship
        let newConstraint: NSLayoutConstraint
        if ScreenHelper.welcomeFormPresentationStyle() == .fullScreen || UIDevice.current.userInterfaceIdiom == .pad {
            newConstraint = contentView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.size.height)
        } else {
            newConstraint = contentView.heightAnchor.constraint(equalToConstant: 256)
        }

        // Activate the constraint
        newConstraint.isActive = true

        // Assign it to the property for later reference
        containerViewTopConstraint = newConstraint
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

    func bindViewToViewModel() {
        self.userNameTextField.rx.text.orEmpty
            .throttle(Durations.threeSeconds.toTimeInterval(), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: self.viewModel.userName)
            .disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty
            .bind(to: self.viewModel.password)
            .disposed(by: self.disposeBag)
        self.accountManagerTextField.rx.text.orEmpty
            .bind(to: self.viewModel.manager).disposed(by: self.disposeBag)
        self.signInButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.global(qos: .background).async {
                    self.viewModel.linkToAccountManager()
                }
            })
            .disposed(by: self.disposeBag)
        self.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismiss(animated: true)
            })
            .disposed(by: self.disposeBag)
        self.viewModel.createState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .started:
                    self?.showLinkHUD()
                case .success:
                    self?.hideHud()
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
        self.viewModel.canLink.bind(to: self.signInButton.rx.isEnabled)
            .disposed(by: self.disposeBag)
    }

    private func showLinkHUD() {
        loadingViewPresenter.presentWithMessage(message: L10n.LinkToAccountManager.signIn, presentingVC: self, animated: false)
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

    func applyL10() {
        signInButton.setTitle(L10n.LinkToAccountManager.signIn, for: .normal)
        titleLabel.text = L10n.LinkToAccountManager.signIn
        self.navigationItem.title = L10n.LinkToAccountManager.signIn
        passwordTextField.placeholder = L10n.Global.password
        userNameTextField.placeholder = L10n.Global.username
        accountManagerTextField.placeholder = L10n.LinkToAccountManager.accountManagerPlaceholder
        userNameLabel.text = L10n.Global.enterUsername
        passwordLabel.text = L10n.Global.enterPassword
        accountManagerLabel.text = L10n.LinkToAccountManager.accountManagerLabel
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        userNameLabel.textColor = UIColor.jamiTextSecondary
        passwordLabel.textColor = UIColor.jamiTextSecondary
        accountManagerLabel.textColor = UIColor.jamiTextSecondary
        userNameTextField.tintColor = UIColor.jamiSecondary
        passwordTextField.tintColor = UIColor.jamiSecondary
        accountManagerTextField.tintColor = UIColor.jamiSecondary

        signInButton.tintColor = UIColor.jamiButtonDark
    }
}
