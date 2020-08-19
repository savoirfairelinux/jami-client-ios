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
import UIKit
import RxSwift
import RxCocoa
import PKHUD

class MigrateAccountViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: MigrateAccountViewModel!
    let disposeBag = DisposeBag()

    @IBOutlet weak var migrateButton: DesignableButton!
    @IBOutlet weak var cancelButton: DesignableButton!
    @IBOutlet weak var migrateOtherAccountButton: DesignableButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var removeAccountButton: DesignableButton!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var jamiIdLabel: UILabel!
    @IBOutlet weak var registeredNameLabel: UILabel!
    @IBOutlet weak var explanationLabel: UILabel!
    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var passwordContainer: UIStackView!
    @IBOutlet weak var passwordField: DesignableTextField!
    @IBOutlet weak var passwordExplanationLabel: UILabel!

    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = true
        self.migrateButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.cancelButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.migrateOtherAccountButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.bindViewToViewModel()
        self.applyL10n()

        // handle keyboard
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                self?.migrateButton.updateGradientFrame()
                self?.cancelButton.updateGradientFrame()
                self?.migrateOtherAccountButton.updateGradientFrame()
            })
            .disposed(by: self.disposeBag)
        explanationLabel.textColor = UIColor.jamiLabelColor
        titleLabel.textColor = UIColor.jamiTextSecondary
        passwordExplanationLabel.textColor = UIColor.jamiLabelColor
        registeredNameLabel.textColor = UIColor.jamiLabelColor
        jamiIdLabel.textColor = UIColor.jamiTextSecondary
        displayNameLabel.textColor = UIColor.jamiLabelColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc
    func keyboardWillAppear(withNotification: NSNotification) {
        self.view.addGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc
    func keyboardWillDisappear(withNotification: NSNotification) {
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    @objc
    func dismissKeyboard() {
        self.isKeyboardOpened = false
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    func bindViewToViewModel() {
        self.viewModel.profileImage
            .bind(to: self.avatarImage.rx.image)
            .disposed(by: disposeBag)

        self.viewModel.profileName
            .bind(to: self.displayNameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.profileName
            .map({ (name) -> Bool in
                return name.isEmpty
            })
            .bind(to: self.displayNameLabel.rx.isHidden)
            .disposed(by: disposeBag)

        self.viewModel.jamiId
            .bind(to: self.jamiIdLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.jamiId
            .map({ (jamiId) -> Bool in
                return jamiId.isEmpty
            })
            .bind(to: self.jamiIdLabel.rx.isHidden)
            .disposed(by: disposeBag)

        self.viewModel.username
            .bind(to: self.registeredNameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.hideMigrateAnotherAccountButton
            .bind(to: self.migrateOtherAccountButton.rx.isHidden)
            .disposed(by: disposeBag)

        self.viewModel.notCancelable
            .bind(to: self.cancelButton.rx.isHidden)
            .disposed(by: disposeBag)

        self.viewModel.username
            .map({ (name) -> Bool in
                return name.isEmpty
            })
            .bind(to: self.registeredNameLabel.rx.isHidden)
            .disposed(by: disposeBag)
        passwordContainer.isHidden = !viewModel.accountHasPassword()

        if viewModel.accountHasPassword() {
            self.passwordField.rx.text.orEmpty
                .bind(to: self.viewModel.password)
                .disposed(by: self.disposeBag)

            self.passwordField.rx.text.map({ !($0?.isEmpty ?? true) })
                .bind(to: self.migrateButton.rx.isEnabled)
                .disposed(by: self.disposeBag)
        }

        self.viewModel.migrationState.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self](action) in
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
            .disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
        self.migrateButton.rx.tap
            .subscribe(onNext: { [weak self] in
                DispatchQueue.main.async {
                    self?.showLoadingView()
                }
                DispatchQueue.global(qos: .background).async {
                    self?.viewModel.migrateAccount()
                }
            })
            .disposed(by: self.disposeBag)

        self.removeAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.removeAccount()
            })
            .disposed(by: self.disposeBag)

        self.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.finishWithoutMigration()
            })
            .disposed(by: self.disposeBag)

        self.migrateOtherAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.migrateAnotherAccount()
            })
            .disposed(by: self.disposeBag)
    }

    func applyL10n() {
        titleLabel.text = L10n.MigrateAccount.title
        migrateButton.setTitle(L10n.MigrateAccount.migrateButton, for: .normal)
        removeAccountButton.setTitle(L10n.MigrateAccount.removeAccount, for: .normal)
        explanationLabel.text = L10n.MigrateAccount.explanation
        passwordField.placeholder = L10n.MigrateAccount.passwordPlaceholder
        passwordExplanationLabel.text = L10n.MigrateAccount.passwordExplanation
        cancelButton.setTitle(L10n.MigrateAccount.cancel, for: .normal)
        migrateOtherAccountButton.setTitle(L10n.MigrateAccount.migrateAnother, for: .normal)
    }

// MARK: - alerts

    private func stopLoadingView() {
        HUD.hide(animated: false)
    }
    private func showLoadingView() {
        HUD.show(.labeledProgress(title: L10n.MigrateAccount.migrating,
                                  subtitle: nil))
    }

    private func showMigrationError() {
        HUD.hide(animated: true) { _ in
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
