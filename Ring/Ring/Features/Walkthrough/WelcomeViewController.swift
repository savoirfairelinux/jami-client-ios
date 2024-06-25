/*
 *  Copyright (C) 2017-2023 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

class WelcomeViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: WelcomeViewModel!

    typealias VMType = WelcomeViewModel

    // MARK: outlets

    @IBOutlet var welcomeTextLabel: UILabel!
    @IBOutlet var containerView: UIView!
    @IBOutlet var joinJamiButton: DesignableButton!
    @IBOutlet var linkAccountButton: DesignableButton!
    @IBOutlet var importDeviceButton: DesignableButton!
    @IBOutlet var importBackupButton: DesignableButton!
    @IBOutlet var advancedFeaturesButton: DesignableButton!
    @IBOutlet var connectJamiAcountManagerButton: DesignableButton!
    @IBOutlet var configureSIPButton: DesignableButton!

    @IBOutlet var aboutJamiButton: DesignableButton!

    // MARK: members

    private let disposeBag = DisposeBag()

    // MARK: functions

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        containerView.accessibilityIdentifier = AccessibilityIdentifiers.welcomeWindow
        applyL10n()
        if viewModel.isAnimatable {
            initialAnimation()
        } else {
            welcomeTextLabel.alpha = 1
            joinJamiButton.alpha = 1
            linkAccountButton.alpha = 1
            advancedFeaturesButton.alpha = 1
        }

        adaptSystemStyles()

        // Bind ViewModel to View
        viewModel.welcomeText.bind(to: welcomeTextLabel.rx.text).disposed(by: disposeBag)
        viewModel.createAccount.bind(to: joinJamiButton.rx.title(for: .normal))
            .disposed(by: disposeBag)
        viewModel.linkDevice.bind(to: importDeviceButton.rx.title(for: .normal))
            .disposed(by: disposeBag)
        configureSIPButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        if !viewModel.notCancelable {
            let cancelButton = UIButton(type: .custom)
            cancelButton.setTitleColor(.jamiButtonDark, for: .normal)
            cancelButton.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 25)
            cancelButton.setTitle(L10n.Global.cancel, for: .normal)
            cancelButton.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
            let buttonItem = UIBarButtonItem(customView: cancelButton)
            cancelButton.rx.tap.throttle(
                Durations.halfSecond.toTimeInterval(),
                scheduler: MainScheduler.instance
            )
            .subscribe(onNext: { [weak self] in
                self?.viewModel.cancelWalkthrough()
            })
            .disposed(by: disposeBag)
            navigationItem.leftBarButtonItem = buttonItem
        }
        // Bind View Actions to ViewModel
        setupButtonActions()

        view.backgroundColor = UIColor.jamiBackgroundColor
        welcomeTextLabel.textColor = UIColor.jamiLabelColor
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.configureWalkrhroughNavigationBar()
            })
            .disposed(by: disposeBag)
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        presentedViewController?.modalPresentationStyle = ScreenHelper
            .welcomeFormPresentationStyle()
    }

    func applyL10n() {
        joinJamiButton.setTitle(L10n.CreateAccount.createAccountFormTitle, for: .normal)
        joinJamiButton.accessibilityIdentifier = AccessibilityIdentifiers.joinJamiButton
        linkAccountButton.setTitle(L10n.Welcome.haveAccount, for: .normal)
        importDeviceButton.setTitle(L10n.Welcome.linkDevice, for: .normal)
        importBackupButton.setTitle(L10n.Welcome.linkBackup, for: .normal)

        advancedFeaturesButton.setTitle(L10n.Account.advancedFeatures, for: .normal)
        connectJamiAcountManagerButton.setTitle(L10n.Welcome.connectToManager, for: .normal)
        configureSIPButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        welcomeTextLabel.text = L10n.Welcome.title

        aboutJamiButton.setTitle(L10n.Smartlist.aboutJami, for: [])
    }

    func adaptSystemStyles() {
        for button in [
            joinJamiButton,
            linkAccountButton,
            importDeviceButton,
            importBackupButton,
            advancedFeaturesButton,
            connectJamiAcountManagerButton,
            configureSIPButton
        ] {
            button?.titleLabel?.ajustToTextSize()

            // Set left and right padding
            let leftPadding: CGFloat = 5
            let rightPadding: CGFloat = 5
            button?.contentEdgeInsets = UIEdgeInsets(
                top: 0,
                left: leftPadding,
                bottom: 0,
                right: rightPadding
            )
        }
        joinJamiButton.backgroundColor = .jamiButtonDark
        linkAccountButton.backgroundColor = .jamiButtonDark
        aboutJamiButton.setTitleColor(.jamiButtonDark, for: [])

        if traitCollection.userInterfaceStyle == .dark {
            joinJamiButton.setTitleColor(.black, for: [])
            linkAccountButton.setTitleColor(.black, for: [])
        } else if traitCollection.userInterfaceStyle == .light {
            joinJamiButton.setTitleColor(.white, for: [])
            linkAccountButton.setTitleColor(.white, for: [])
        }

        for button in [
            importDeviceButton,
            importBackupButton,
            connectJamiAcountManagerButton,
            configureSIPButton
        ] {
            button?.borderWidth = 1
            button?.borderColor = .jamiButtonDark
            button?.backgroundColor = .jamiButtonWithOpacity
            button?.setTitleColor(UIColor.jamiButtonDark, for: [])
        }
        advancedFeaturesButton.setTitleColor(UIColor.jamiButtonDark, for: [])
    }

    private func aboutJamiButtonDidTap() {
        viewModel.openAboutJami()
    }

    func setupButtonActions() {
        joinJamiButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.proceedWithAccountCreation()
            })
            .disposed(by: disposeBag)

        importDeviceButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.proceedWithLinkDevice()
            })
            .disposed(by: disposeBag)

        aboutJamiButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.aboutJamiButtonDidTap()
            })
            .disposed(by: disposeBag)

        linkAccountButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                if self.importDeviceButton.isHidden {
                    self.importDeviceButton.isHidden = false
                    self.linkAccountButton.backgroundColor = .jamiButtonLight
                } else {
                    self.importDeviceButton.isHidden = true
                    self.linkAccountButton.backgroundColor = .jamiButtonDark
                }
            })
            .disposed(by: disposeBag)

        advancedFeaturesButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                if self.connectJamiAcountManagerButton.isHidden {
                    self.connectJamiAcountManagerButton.isHidden = false
                    self.configureSIPButton.isHidden = false
                } else {
                    self.connectJamiAcountManagerButton.isHidden = true
                    self.configureSIPButton.isHidden = true
                }
            })
            .disposed(by: disposeBag)

        connectJamiAcountManagerButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.linkToAccountManager()
            })
            .disposed(by: disposeBag)

        configureSIPButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.createSipAccount()
            })
            .disposed(by: disposeBag)
    }

    func initialAnimation() {
        DispatchQueue.global(qos: .background).async {
            sleep(1)
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.5, animations: {
                    self?.welcomeTextLabel.alpha = 1
                    self?.joinJamiButton.alpha = 1
                    self?.linkAccountButton.alpha = 1
                    self?.advancedFeaturesButton.alpha = 1
                    self?.view.layoutIfNeeded()
                })
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.tintColor = UIColor.jamiSecondary
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: nil,
            action: nil
        )
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        view.layoutIfNeeded()
    }
}
