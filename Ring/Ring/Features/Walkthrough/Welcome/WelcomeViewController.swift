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
import RxSwift
import RxCocoa
import Reusable

class WelcomeViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: WelcomeViewModel!

    typealias VMType = WelcomeViewModel
    // MARK: outlets
    @IBOutlet weak var welcomeTextLabel: UILabel!
    @IBOutlet weak var joinJamiButton: DesignableButton!
    @IBOutlet weak var linkAccountButton: DesignableButton!
    @IBOutlet weak var importDeviceButton: DesignableButton!
    @IBOutlet weak var importBackupButton: DesignableButton!
    @IBOutlet weak var advancedFeaturesButton: DesignableButton!
    @IBOutlet weak var connectJamiAcountManagerButton: DesignableButton!
    @IBOutlet weak var configureSIPButton: DesignableButton!

    @IBOutlet weak var aboutJamiButton: DesignableButton!

    // MARK: constraints
    //    @IBOutlet weak var ringLogoBottomConstraint: NSLayoutConstraint!

    // MARK: members
    private let disposeBag = DisposeBag()

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        self.applyL10n()
        if self.viewModel.isAnimatable {
            self.initialAnimation()
        } else {
            //            self.ringLogoBottomConstraint.constant = -220
            self.welcomeTextLabel.alpha = 1
            self.joinJamiButton.alpha = 1
            self.linkAccountButton.alpha = 1
            self.advancedFeaturesButton.alpha = 1
        }
        for button in [joinJamiButton, linkAccountButton, importDeviceButton, importBackupButton, advancedFeaturesButton, connectJamiAcountManagerButton, configureSIPButton] {
            button?.titleLabel?.ajustToTextSize()
        }
        self.joinJamiButton.backgroundColor = .jamiButtonDark
        self.linkAccountButton.backgroundColor = .jamiButtonDark

        for button in [importDeviceButton, importBackupButton, connectJamiAcountManagerButton, configureSIPButton] {
            button?.borderWidth = 1
            button?.borderColor = .jamiButtonDark
            button?.backgroundColor = .jamiButtonWithOpacity
            button?.setTitleColor(UIColor.jamiButtonDark, for: [])
        }
        advancedFeaturesButton.setTitleColor(UIColor.jamiButtonDark, for: [])

        // Bind ViewModel to View
        self.viewModel.welcomeText.bind(to: self.welcomeTextLabel.rx.text).disposed(by: self.disposeBag)
        self.viewModel.createAccount.bind(to: self.joinJamiButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        self.viewModel.linkDevice.bind(to: self.importDeviceButton.rx.title(for: .normal)).disposed(by: self.disposeBag)
        configureSIPButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        if !self.viewModel.notCancelable {
            let cancelButton = UIButton(type: .custom)
            cancelButton.setTitleColor(.jamiMain, for: .normal)
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

    func applyL10n() {
        joinJamiButton.setTitle(L10n.Welcome.createAccount, for: .normal)
        linkAccountButton.setTitle(L10n.Welcome.haveAccount, for: .normal)
        importDeviceButton.setTitle(L10n.Welcome.linkDevice, for: .normal)
        importBackupButton.setTitle(L10n.Welcome.linkBackup, for: .normal)

        advancedFeaturesButton.setTitle(L10n.Account.advancedFeatures, for: .normal)
        connectJamiAcountManagerButton.setTitle(L10n.Welcome.connectToManager, for: .normal)
        configureSIPButton.setTitle(L10n.Account.createSipAccount, for: .normal)
        welcomeTextLabel.text = L10n.Welcome.title

        aboutJamiButton.setTitle(L10n.Smartlist.aboutJami, for: [])
    }

    private func aboutJamiButtonDidTap() {
        var compileDate: String {
            let dateDefault = ""
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
            if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
               let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
               let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date {
                return dateFormatter.string(from: infoDate)
            }
            return dateDefault
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let versionName = "Világfa"
        let alert = UIAlertController(title: "\nJami\nversion: \(appVersion)(\(compileDate))\n\(versionName)", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
        let image = UIImageView(image: UIImage(asset: Asset.jamiIcon))
        alert.view.addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerX, relatedBy: .equal, toItem: alert.view, attribute: .centerX, multiplier: 1, constant: 0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .centerY, relatedBy: .equal, toItem: alert.view, attribute: .top, multiplier: 1, constant: 0.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        alert.view.addConstraint(NSLayoutConstraint(item: image, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 64.0))
        self.present(alert, animated: true, completion: nil)
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
                //                self?.ringLogoBottomConstraint.constant = -72
                UIView.animate(withDuration: 0.5, animations: {
                    //                    self?.ringLogoBottomConstraint.constant = -220
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
