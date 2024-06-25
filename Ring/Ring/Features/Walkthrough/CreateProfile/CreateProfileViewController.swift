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

import AMPopTip
import Reusable
import RxSwift
import UIKit

class CreateProfileViewController: EditProfileViewController, StoryboardBased, ViewModelBased {
    // MARK: outlets

    @IBOutlet var createYourAvatarLabel: UILabel!
    @IBOutlet var infoView: UIView!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var arrow: UIImageView!
    @IBOutlet var arrowHeightConstraint: NSLayoutConstraint!
    @IBOutlet var enterNameLabel: UILabel!
    @IBOutlet var arrowYConstraint: NSLayoutConstraint!
    @IBOutlet var skipButton: DesignableButton!
    @IBOutlet var profileImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var infoProfileImage: UIImageView!
    @IBOutlet var backgroundView: UIView!

    // MARK: members

    private let disposeBag = DisposeBag()
    var viewModel: CreateProfileViewModel!
    let popTip = PopTip()
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    let tapGesture = UITapGestureRecognizer()

    // MARK: functions

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        configureWalkrhroughNavigationBar()

        // Style
        skipButton.applyGradient(
            with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark],
            gradient: .horizontal
        )
        skipButton.titleLabel?.ajustToTextSize()
        profileImageView.layer.shadowColor = UIColor.gray.cgColor
        profileImageView.layer.shadowOpacity = 0.5
        profileImageView.layer.shadowOffset = CGSize.zero
        profileImageView.layer.shadowRadius = 4
        infoProfileImage.layer.shadowColor = UIColor.gray.cgColor
        infoProfileImage.layer.shadowOpacity = 0.5
        infoProfileImage.layer.shadowOffset = CGSize.zero
        infoProfileImage.layer.shadowRadius = 4
        adaptToSystemColor()

        // Animations
        DispatchQueue.global(qos: .background).async {
            sleep(1)
            DispatchQueue.main.async { [weak self] in
                self?.infoView.isHidden = false
                UIView.animate(withDuration: 0.3, animations: {
                    self?.infoView.alpha = 1
                    self?.arrowHeightConstraint.constant = 100
                })
                self?.arrow.tintColor = UIColor.white
                UIView.animate(withDuration: 1, animations: {
                    self?.arrowYConstraint.constant = 70
                    self?.view.layoutIfNeeded()
                })
                self?.setShadowAnimation()
            }
            usleep(400_000)
            DispatchQueue.main.async {
                self.setShadowAnimation()
            }
        }
        infoView.addGestureRecognizer(tapGesture)

        applyL10n()

        // bind view model to view
        tapGesture.rx.event
            .bind(onNext: { [weak self] _ in
                self?.dismissInfoView()
            })
            .disposed(by: disposeBag)

        // Bind ViewModel to View
        viewModel.skipButtonTitle.asObservable().bind(to: skipButton.rx.title(for: .normal))
            .disposed(by: disposeBag)

        // Bind View to ViewModel
        profileName.rx.text.orEmpty.bind(to: viewModel.profileName).disposed(by: disposeBag)

        if profileImageView.image != nil {
            let imageObs: Observable<UIImage?> = profileImageView
                .rx.observe(UIImage.self, "image")
            imageObs.bind(to: viewModel.profilePhoto).disposed(by: disposeBag)
        }

        // Bind View Actions to ViewModel
        skipButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                if let name = self.profileName.text {
                    self.model.updateName(name)
                }
                self.viewModel.proceedWithAccountCreationOrDeviceLink()
            })
            .disposed(by: disposeBag)

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(imageTapped(tapGestureRecognizer:))
        )
        infoProfileImage.isUserInteractionEnabled = true
        infoProfileImage.addGestureRecognizer(tapGestureRecognizer)

        // handle keyboard
        adaptToKeyboardState(for: scrollView, with: disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.skipButton.updateGradientFrame()
                self?.self.configureWalkrhroughNavigationBar()
            })
            .disposed(by: disposeBag)
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        backgroundView.backgroundColor = UIColor.jamiBackgroundColor
        profileName.tintColor = UIColor.jamiSecondary
        scrollView.backgroundColor = UIColor.jamiBackgroundColor
        subtitle.textColor = UIColor.jamiTextSecondary
        enterNameLabel.textColor = UIColor.jamiTextSecondary
        profileName.backgroundColor = UIColor.jamiBackgroundColor
        profileName.borderColor = UIColor.jamiTextBlue
    }

    func dismissInfoView() {
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.infoView.alpha = 0
        }, completion: { _ in self.infoView.isHidden = true })
    }

    override func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        super.imageTapped(tapGestureRecognizer: tapGestureRecognizer)
        dismissInfoView()
    }

    @objc
    func dismissKeyboard() {
        becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
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

    func applyL10n() {
        navigationItem.title = L10n.CreateProfile.title
        enterNameLabel.text = L10n.CreateProfile.enterNameLabel
        profileName.placeholder = L10n.CreateProfile.enterNamePlaceholder
        subtitle.text = L10n.CreateProfile.subtitle
        createYourAvatarLabel.text = L10n.CreateProfile.createYourAvatar
    }

    func setShadowAnimation() {
        let shadow1Animation = CABasicAnimation(keyPath: "shadowOpacity")
        shadow1Animation.fromValue = 0.5
        shadow1Animation.toValue = 1
        shadow1Animation.duration = 0.2
        let shadow2Animation = CABasicAnimation(keyPath: "shadowOpacity")
        shadow2Animation.fromValue = 1
        shadow2Animation.toValue = 0.5
        shadow2Animation.duration = 0.2

        infoProfileImage.layer.add(shadow1Animation, forKey: shadow1Animation.keyPath)

        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async { [weak self] in
                self?.profileImageView.layer.shadowOpacity = 1
                UIView.animate(withDuration: 0.2, animations: {
                    self?.profileImageViewHeightConstraint.constant = 114
                    self?.view.layoutIfNeeded()
                })
            }
            usleep(200_000)
            DispatchQueue.main.async {
                self.infoProfileImage.layer.removeAllAnimations()
                self.infoProfileImage.layer.add(shadow2Animation, forKey: shadow2Animation.keyPath)
                self.infoProfileImage.layer.shadowOpacity = 0.5
                UIView.animate(withDuration: 0.2, animations: {
                    self.profileImageViewHeightConstraint.constant = 120
                    self.view.layoutIfNeeded()
                })
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.setHidesBackButton(true, animated: true)
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
}
