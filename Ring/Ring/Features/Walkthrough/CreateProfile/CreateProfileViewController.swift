//
//  CreateProfileViewController.swift
//  Ring
//
//  Created by Thibault Wittemberg on 2017-07-18.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit
import Reusable
import RxSwift
import AMPopTip

class CreateProfileViewController: EditProfileViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var arrow: UIImageView!
    @IBOutlet weak var enterNameLabel: UILabel!
    @IBOutlet weak var enterNameInfoButton: ButtonTransparentBackground!
    @IBOutlet weak var arrowYConstraint: NSLayoutConstraint!
    @IBOutlet weak var createProfilAccountTitle: UILabel!
    @IBOutlet weak var skipButton: DesignableButton!
    @IBOutlet weak var profileImageViewHeightConstraint: NSLayoutConstraint!

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

        // Style
        self.skipButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.profileImageView.layer.shadowColor = UIColor.gray.cgColor
        self.profileImageView.layer.shadowOpacity = 0.7
        self.profileImageView.layer.shadowOffset = CGSize.zero
        self.profileImageView.layer.shadowRadius = 10
        self.profileName.tintColor = UIColor.ringSecondary

        DispatchQueue.global(qos: .background).async {
            sleep(1)
            DispatchQueue.main.async {
                self.infoView.isHidden = false
                UIView.animate(withDuration: 0.3, animations: {
                    self.infoView.alpha = 1
                })
                self.arrow.tintColor = UIColor.white
                UIView.animate(withDuration: 5, animations: {
                    self.arrowYConstraint.constant = 65
                    self.view.layoutIfNeeded()
                })
                self.setShadowAnimation()
            }
            usleep(400000)
            DispatchQueue.main.async {
                self.setShadowAnimation()
            }
        }

        self.applyL10n()

        //bind view model to view
        self.enterNameInfoButton.rx.tap.subscribe(onNext: { [unowned self] (_) in
            self.showPinInfo()
        }).disposed(by: self.disposeBag)

        self.infoView.addGestureRecognizer(tapGesture)

        tapGesture.rx.event.bind(onNext: { recognizer in
            self.dismissInfoView()
        }).disposed(by: disposeBag)

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
        self.skipButton.rx.tap.subscribe(onNext: { [unowned self] in
            if let name = self.profileName.text {
                self.model.updateName(name)
            }
            self.viewModel.proceedWithAccountCreationOrDeviceLink()
        }).disposed(by: self.disposeBag)

        // handle keyboard
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    }

    func dismissInfoView() {
        UIView.animate(withDuration: 0.3, animations: {
            self.infoView.alpha = 0
        },completion: { _ in self.infoView.isHidden = true })
    }

    override func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        super.imageTapped(tapGestureRecognizer: tapGestureRecognizer)
        self.dismissInfoView()
    }

    @objc func dismissKeyboard() {
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc func keyboardWillAppear(withNotification: NSNotification){
        self.view.addGestureRecognizer(keyboardDismissTapRecognizer)

    }

    @objc func keyboardWillDisappear(withNotification: NSNotification){
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }


    func applyL10n() {
        self.createProfilAccountTitle.text = L10n.CreateProfile.title
        self.enterNameLabel.text = L10n.CreateProfile.enterNameLabel
        self.profileName.placeholder = L10n.CreateProfile.enterNamePlaceholder
    }

    private func showPinInfo() {
        if popTip.isVisible {
            popTip.hide()
        } else {
            popTip.shouldDismissOnTap = true
            popTip.entranceAnimation = .scale
            popTip.bubbleColor = UIColor.ringSecondary
            popTip.textColor = UIColor.white
            let offset: CGFloat = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad) ? 60.0 : 80.0
            popTip.show(text: L10n.CreateProfile.enterNameInfoButton, direction: .down,
                        maxWidth: 250, in: self.view, from: enterNameInfoButton.frame)
        }
    }

    func setShadowAnimation() {
        let shadow1Animation = CABasicAnimation(keyPath: "shadowOpacity")
        shadow1Animation.fromValue = 0.7
        shadow1Animation.toValue = 1
        shadow1Animation.duration = 0.2
        let shadow2Animation = CABasicAnimation(keyPath: "shadowOpacity")
        shadow2Animation.fromValue = 1
        shadow2Animation.toValue = 0.7
        shadow2Animation.duration = 0.2

        self.profileImageView.layer.add(shadow1Animation, forKey: shadow1Animation.keyPath)

        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                self.profileImageView.layer.shadowOpacity = 1
                UIView.animate(withDuration: 0.2, animations: {
                    self.profileImageViewHeightConstraint.constant = 114
                    self.view.layoutIfNeeded()
                })
            }
            usleep(200000)
            DispatchQueue.main.async {
                self.profileImageView.layer.removeAllAnimations()
                self.profileImageView.layer.add(shadow2Animation, forKey: shadow2Animation.keyPath)
                self.profileImageView.layer.shadowOpacity = 0.7
                UIView.animate(withDuration: 0.2, animations: {
                self.profileImageViewHeightConstraint.constant = 120
                self.view.layoutIfNeeded()
                })
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = true
        UIApplication.shared.statusBarStyle = .default
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
}
