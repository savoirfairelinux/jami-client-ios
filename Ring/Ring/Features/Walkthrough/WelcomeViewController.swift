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

import UIKit
import RxSwift
import RxCocoa
import Reusable

class WelcomeViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: WelcomeViewModel!

    typealias VMType = WelcomeViewModel
    // MARK: outlets
    @IBOutlet weak var welcomeTextLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var joinJamiButton: DesignableButton!
    @IBOutlet weak var linkAccountButton: DesignableButton!
    @IBOutlet weak var importDeviceButton: DesignableButton!
    @IBOutlet weak var importBackupButton: DesignableButton!
    @IBOutlet weak var advancedFeaturesButton: DesignableButton!
    @IBOutlet weak var connectJamiAcountManagerButton: DesignableButton!
    @IBOutlet weak var configureSIPButton: DesignableButton!

    @IBOutlet weak var aboutJamiButton: DesignableButton!

    // MARK: members
    private let disposeBag = DisposeBag()

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        containerView.accessibilityIdentifier = AccessibilityIdentifiers.welcomeWindow
        self.applyL10n()
        if self.viewModel.isAnimatable {
            self.initialAnimation()
        } else {
            self.welcomeTextLabel.alpha = 1
            self.joinJamiButton.alpha = 1
            self.linkAccountButton.alpha = 1
            self.advancedFeaturesButton.alpha = 1
        }

        adaptSystemStyles()

        // Bind ViewModel to View
        self.viewModel.welcomeText.bind(to: self.welcomeTextLabel.rx.text).disposed(by: self.disposeBag)
        self.viewModel.createAccount.bind(to: self.joinJamiButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        self.viewModel.linkDevice.bind(to: self.importDeviceButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        configureSIPButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        if !self.viewModel.notCancelable {
            let cancelButton = UIButton(type: .custom)
            cancelButton.setTitleColor(.jamiButtonDark, for: .normal)
            cancelButton.titleLabel?.font = UIFont(name: "HelveticaNeue-Light", size: 25)
            cancelButton.setTitle(L10n.Global.cancel, for: .normal)
            cancelButton.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
            let buttonItem = UIBarButtonItem(customView: cancelButton)
            cancelButton.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
                .subscribe(onNext: { [weak self] in
                    self?.viewModel.cancelWalkthrough()
                })
                .disposed(by: self.disposeBag)
            self.navigationItem.leftBarButtonItem = buttonItem
        }
        // Bind View Actions to ViewModel
        setupButtonActions()

        view.backgroundColor = UIColor.jamiBackgroundColor
        self.welcomeTextLabel.textColor = UIColor.jamiLabelColor
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.configureWalkrhroughNavigationBar()
            })
            .disposed(by: self.disposeBag)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.presentedViewController?.modalPresentationStyle = ScreenHelper.welcomeFormPresentationStyle()
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
        for button in [joinJamiButton, linkAccountButton, importDeviceButton, importBackupButton, advancedFeaturesButton, connectJamiAcountManagerButton, configureSIPButton] {
            button?.titleLabel?.ajustToTextSize()

            // Set left and right padding
            let leftPadding: CGFloat = 5
            let rightPadding: CGFloat = 5
            button?.contentEdgeInsets = UIEdgeInsets(top: 0, left: leftPadding, bottom: 0, right: rightPadding)
        }
        self.joinJamiButton.backgroundColor = .jamiButtonDark
        self.linkAccountButton.backgroundColor = .jamiButtonDark
        aboutJamiButton.setTitleColor(.jamiButtonDark, for: [])

        if traitCollection.userInterfaceStyle == .dark {
            self.joinJamiButton.setTitleColor(.black, for: [])
            self.linkAccountButton.setTitleColor(.black, for: [])
        } else if traitCollection.userInterfaceStyle == .light {
            self.joinJamiButton.setTitleColor(.white, for: [])
            self.linkAccountButton.setTitleColor(.white, for: [])
        }

        for button in [importDeviceButton, importBackupButton, connectJamiAcountManagerButton, configureSIPButton] {
            button?.borderWidth = 1
            button?.borderColor = .jamiButtonDark
            button?.backgroundColor = .jamiButtonWithOpacity
            button?.setTitleColor(UIColor.jamiButtonDark, for: [])
        }
        advancedFeaturesButton.setTitleColor(UIColor.jamiButtonDark, for: [])
    }

    private func aboutJamiButtonDidTap() {
        self.viewModel.openAboutJami()
    }

    func setupButtonActions() {
        self.joinJamiButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.proceedWithAccountCreation()
            })
            .disposed(by: self.disposeBag)

        self.importDeviceButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.proceedWithLinkDevice()
            })
            .disposed(by: self.disposeBag)

        self.aboutJamiButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.aboutJamiButtonDidTap()
            })
            .disposed(by: self.disposeBag)

        self.linkAccountButton.rx.tap
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
            .disposed(by: self.disposeBag)

        self.advancedFeaturesButton.rx.tap
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
            .disposed(by: self.disposeBag)

        self.connectJamiAcountManagerButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.linkToAccountManager()
            })
            .disposed(by: self.disposeBag)

        self.configureSIPButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.createSipAccount()
            })
            .disposed(by: self.disposeBag)
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
        self.navigationController?.navigationBar.tintColor = UIColor.jamiSecondary
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.view.layoutIfNeeded()
    }
}
