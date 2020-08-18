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
import Reusable
import RxSwift
import AMPopTip

class CreateProfileViewController: EditProfileViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var createYourAvatarLabel: UILabel!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var arrow: UIImageView!
    @IBOutlet weak var arrowHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var enterNameLabel: UILabel!
    @IBOutlet weak var arrowYConstraint: NSLayoutConstraint!
    @IBOutlet weak var skipButton: DesignableButton!
    @IBOutlet weak var profileImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var infoProfileImage: UIImageView!
    @IBOutlet weak var backgroundView: UIView!

    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: CreateProfileViewModel!
    let popTip = PopTip()
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    let tapGesture = UITapGestureRecognizer()

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        self.configureWalkrhroughNavigationBar()

        // Style
        self.skipButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        skipButton.titleLabel?.ajustToTextSize()
        self.profileImageView.layer.shadowColor = UIColor.gray.cgColor
        self.profileImageView.layer.shadowOpacity = 0.5
        self.profileImageView.layer.shadowOffset = CGSize.zero
        self.profileImageView.layer.shadowRadius = 4
        self.infoProfileImage.layer.shadowColor = UIColor.gray.cgColor
        self.infoProfileImage.layer.shadowOpacity = 0.5
        self.infoProfileImage.layer.shadowOffset = CGSize.zero
        self.infoProfileImage.layer.shadowRadius = 4
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
            usleep(400000)
            DispatchQueue.main.async {
                self.setShadowAnimation()
            }
        }
        self.infoView.addGestureRecognizer(tapGesture)

        self.applyL10n()

        //bind view model to view
        tapGesture.rx.event
            .bind(onNext: { [weak self] _ in
                self?.dismissInfoView()
            })
            .disposed(by: disposeBag)

        // Bind ViewModel to View
        self.viewModel.skipButtonTitle.asObservable().bind(to: self.skipButton.rx.title(for: .normal)).disposed(by: self.disposeBag)

        // Bind View to ViewModel
        self.profileName.rx.text.orEmpty.bind(to: self.viewModel.profileName).disposed(by: self.disposeBag)

        if self.profileImageView.image != nil {
            let imageObs: Observable<UIImage?> = self.profileImageView
                .rx.observe(UIImage.self, "image")
            imageObs.bind(to: self.viewModel.profilePhoto).disposed(by: self.disposeBag)
        }

        // Bind View Actions to ViewModel
        self.skipButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                if let name = self.profileName.text {
                    self.model.updateName(name)
                }
                self.viewModel.proceedWithAccountCreationOrDeviceLink()
            })
            .disposed(by: self.disposeBag)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        infoProfileImage.isUserInteractionEnabled = true
        infoProfileImage.addGestureRecognizer(tapGestureRecognizer)

        // handle keyboard
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
        .observeOn(MainScheduler.instance)
        .subscribe(onNext: { [weak self] (_) in
            self?.skipButton.updateGradientFrame()
            self?.self.configureWalkrhroughNavigationBar()
        })
        .disposed(by: self.disposeBag)
    }

    func adaptToSystemColor() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        backgroundView.backgroundColor = UIColor.jamiBackgroundColor
        self.profileName.tintColor = UIColor.jamiSecondary
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
        self.dismissInfoView()
    }

    @objc func dismissKeyboard() {
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc func keyboardWillAppear(withNotification: NSNotification) {
        self.view.addGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc func keyboardWillDisappear(withNotification: NSNotification) {
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    func applyL10n() {
        self.navigationItem.title = L10n.CreateProfile.title
        self.enterNameLabel.text = L10n.CreateProfile.enterNameLabel
        self.profileName.placeholder = L10n.CreateProfile.enterNamePlaceholder
        self.subtitle.text = L10n.CreateProfile.subtitle
        self.createYourAvatarLabel.text = L10n.CreateProfile.createYourAvatar
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

        self.infoProfileImage.layer.add(shadow1Animation, forKey: shadow1Animation.keyPath)

        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async { [weak self] in
                self?.profileImageView.layer.shadowOpacity = 1
                UIView.animate(withDuration: 0.2, animations: {
                    self?.profileImageViewHeightConstraint.constant = 114
                    self?.view.layoutIfNeeded()
                })
            }
            usleep(200000)
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
        self.navigationItem.setHidesBackButton(true, animated: true)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}
