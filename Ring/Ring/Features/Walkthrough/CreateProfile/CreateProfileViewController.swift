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

class CreateProfileViewController: EditProfileViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var skipButton: DesignableButton!
    @IBOutlet weak var profileImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideo: UIImageView!

    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: CreateProfileViewModel!

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layoutIfNeeded()
        self.setupBindings()

        // Style
        self.skipButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.profileImageView.layer.shadowColor = UIColor.gray.cgColor
        self.profileImageView.layer.shadowOpacity = 0.7
        self.profileImageView.layer.shadowOffset = CGSize.zero
        self.profileImageView.layer.shadowRadius = 10

        DispatchQueue.global(qos: .background).async {
            sleep(1)
            DispatchQueue.main.async {
                self.setShadowAnimation()
            }
            usleep(400000)
            DispatchQueue.main.async {
                self.setShadowAnimation()
            }
        }

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
    }

    func setupBindings() {
        self.viewModel.capturedFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.capturedVideo.image = image
                    }
                }
            }).disposed(by: self.disposeBag)
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
    }
}
