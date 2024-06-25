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
import RxCocoa
import RxSwift
import UIKit

class MigrateAccountViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: MigrateAccountViewModel!
    let disposeBag = DisposeBag()

    @IBOutlet var migrateButton: DesignableButton!
    @IBOutlet var cancelButton: DesignableButton!
    @IBOutlet var migrateOtherAccountButton: DesignableButton!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var removeAccountButton: DesignableButton!
    @IBOutlet var displayNameLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var jamiIdLabel: UILabel!
    @IBOutlet var registeredNameLabel: UILabel!
    @IBOutlet var explanationLabel: UILabel!
    @IBOutlet var avatarImage: UIImageView!
    @IBOutlet var passwordContainer: UIStackView!
    @IBOutlet var passwordField: DesignableTextField!
    @IBOutlet var passwordExplanationLabel: UILabel!
    var loadingViewPresenter = LoadingViewPresenter()

    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = true
        migrateButton.applyGradient(
            with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark],
            gradient: .horizontal
        )
        cancelButton.applyGradient(
            with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark],
            gradient: .horizontal
        )
        migrateOtherAccountButton.applyGradient(
            with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark],
            gradient: .horizontal
        )
        bindViewToViewModel()
        applyL10n()

        // handle keyboard
        adaptToKeyboardState(for: scrollView, with: disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else {
                    return
                }
                self?.migrateButton.updateGradientFrame()
                self?.cancelButton.updateGradientFrame()
                self?.migrateOtherAccountButton.updateGradientFrame()
            })
            .disposed(by: disposeBag)
        explanationLabel.textColor = UIColor.jamiLabelColor
        titleLabel.textColor = UIColor.jamiTextSecondary
        passwordExplanationLabel.textColor = UIColor.jamiLabelColor
        registeredNameLabel.textColor = UIColor.jamiLabelColor
        jamiIdLabel.textColor = UIColor.jamiTextSecondary
        displayNameLabel.textColor = UIColor.jamiLabelColor
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
    }

    @objc
    func keyboardWillAppear(withNotification _: NSNotification) {
        view.addGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc
    func keyboardWillDisappear(withNotification _: NSNotification) {
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    @objc
    func dismissKeyboard() {
        isKeyboardOpened = false
        becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    func bindViewToViewModel() {
        viewModel.profileImage
            .bind(to: avatarImage.rx.image)
            .disposed(by: disposeBag)

        viewModel.profileName
            .bind(to: displayNameLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.profileName
            .map { name -> Bool in
                name.isEmpty
            }
            .bind(to: displayNameLabel.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.jamiId
            .bind(to: jamiIdLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.jamiId
            .map { jamiId -> Bool in
                jamiId.isEmpty
            }
            .bind(to: jamiIdLabel.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.username
            .bind(to: registeredNameLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.hideMigrateAnotherAccountButton
            .bind(to: migrateOtherAccountButton.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.notCancelable
            .bind(to: cancelButton.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.username
            .map { name -> Bool in
                name.isEmpty
            }
            .bind(to: registeredNameLabel.rx.isHidden)
            .disposed(by: disposeBag)
        passwordContainer.isHidden = !viewModel.accountHasPassword()

        if viewModel.accountHasPassword() {
            passwordField.rx.text.orEmpty
                .bind(to: viewModel.password)
                .disposed(by: disposeBag)

            passwordField.rx.text.map { !($0?.isEmpty ?? true) }
                .bind(to: migrateButton.rx.isEnabled)
                .disposed(by: disposeBag)
        }

        viewModel.migrationState.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] action in
                switch action {
                case .unknown:
                    break
                case .started:
                    self?.showLoadingView()
                case .success:
                    self?.stopLoadingView()
                case .error:
                    self?.showMigrationError()
                case .finished:
                    self?.dismiss(animated: false, completion: nil)
                }
            })
            .disposed(by: disposeBag)

        // Bind View Actions to ViewModel
        migrateButton.rx.tap
            .subscribe(onNext: { [weak self] in
                DispatchQueue.main.async {
                    self?.showLoadingView()
                }
                DispatchQueue.global(qos: .background).async {
                    self?.viewModel.migrateAccount()
                }
            })
            .disposed(by: disposeBag)

        removeAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.removeAccount()
            })
            .disposed(by: disposeBag)

        cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.finishWithoutMigration()
            })
            .disposed(by: disposeBag)

        migrateOtherAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.migrateAnotherAccount()
            })
            .disposed(by: disposeBag)
    }

    func applyL10n() {
        titleLabel.text = L10n.MigrateAccount.title
        migrateButton.setTitle(L10n.MigrateAccount.migrateButton, for: .normal)
        removeAccountButton.setTitle(L10n.Global.removeAccount, for: .normal)
        explanationLabel.text = L10n.MigrateAccount.explanation
        passwordField.placeholder = L10n.Global.enterPassword
        passwordExplanationLabel.text = L10n.MigrateAccount.passwordExplanation
        cancelButton.setTitle(L10n.Global.cancel, for: .normal)
        migrateOtherAccountButton.setTitle(L10n.MigrateAccount.migrateAnother, for: .normal)
    }

    // MARK: - alerts

    private func stopLoadingView() {
        loadingViewPresenter.hide(animated: false)
    }

    private func showLoadingView() {
        loadingViewPresenter.presentWithMessage(
            message: L10n.MigrateAccount.migrating,
            presentingVC: self,
            animated: true
        )
    }

    private func showMigrationError() {
        loadingViewPresenter.hide(animated: true) { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: L10n.MigrateAccount.error,
                                          message: nil,
                                          preferredStyle: .alert)
            let action = UIAlertAction(title: "OK",
                                       style: .cancel)
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }
}
