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
import PKHUD
import AMPopTip
import SwiftyBeaver

class LinkDeviceViewController: UIViewController, StoryboardBased, ViewModelBased {

    // MARK: outlets
    @IBOutlet weak var linkDeviceTitle: UILabel!
    @IBOutlet weak var linkButton: DesignableButton!
    @IBOutlet weak var backgroundNavigationBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinTextField: DesignableTextField!
    @IBOutlet weak var passwordTextField: DesignableTextField!
    @IBOutlet weak var pinInfoButton: UIButton!
    @IBOutlet weak var pinLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: LinkDeviceViewModel!
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false
    let popTip = PopTip()

    let log = SwiftyBeaver.self

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        // Style
        self.pinTextField.becomeFirstResponder()
        self.view.layoutIfNeeded()
        self.linkButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.backgroundNavigationBarHeightConstraint.constant = UIApplication.shared.statusBarFrame.height
        self.pinTextField.tintColor = UIColor.jamiSecondary
        self.passwordTextField.tintColor = UIColor.jamiSecondary

        self.applyL10n()

        //bind view model to view
        self.pinInfoButton.rx.tap.subscribe(onNext: { [unowned self] (_) in
            self.showPinInfo()
        }).disposed(by: self.disposeBag)

        self.linkButton.rx.tap.subscribe(onNext: { [unowned self] (_) in
            self.viewModel.linkDevice()
        }).disposed(by: self.disposeBag)

        // handle linking state
        self.viewModel.createState
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .started:
                    self?.showCreationHUD()
                case .success:
                    self?.hideHud()
                    self?.showLinkedSuccess()
                case .error (let error):
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
            }).disposed(by: self.disposeBag)

        self.viewModel.linkButtonEnabledState.bind(to: self.linkButton.rx.isEnabled)
            .disposed(by: self.disposeBag)

        // bind view to view model
        self.pinTextField.rx.text.orEmpty.bind(to: self.viewModel.pin).disposed(by: self.disposeBag)
        self.passwordTextField.rx.text.orEmpty.bind(to: self.viewModel.password).disposed(by: self.disposeBag)

        // handle keyboard
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    }

    func setContentInset() {
        if !self.isKeyboardOpened {
            self.containerViewBottomConstraint.constant = -20
            return
        }
        let device = UIDevice.modelName
        switch device {
        case "iPhone X", "iPhone XS", "iPhone XS Max", "iPhone XR" :
            self.containerViewBottomConstraint.constant = -40
        default :
            self.containerViewBottomConstraint.constant = -65
        }
    }

    @objc func dismissKeyboard() {
        self.isKeyboardOpened = false
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc func keyboardWillAppear(withNotification: NSNotification){
        self.isKeyboardOpened = true
        self.view.addGestureRecognizer(keyboardDismissTapRecognizer)
        self.setContentInset()

    }

    @objc func keyboardWillDisappear(withNotification: NSNotification){
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
        self.setContentInset()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .default
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(withNotification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(withNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    private func applyL10n() {
        self.linkButton.setTitle(L10n.LinkToAccount.linkButtonTitle, for: .normal)
        self.pinLabel.text = L10n.LinkToAccount.pinLabel
        self.passwordLabel.text = L10n.LinkToAccount.passwordLabel
        self.pinTextField.placeholder = L10n.LinkToAccount.pinPlaceholder
        self.passwordTextField.placeholder = L10n.LinkToAccount.passwordPlaceholder
        self.linkDeviceTitle.text = L10n.LinkToAccount.linkButtonTitle
    }

    private func showCreationHUD() {
        HUD.show(.labeledProgress(title: L10n.LinkToAccount.waitLinkToAccountTitle, subtitle: nil))
    }

    private func showLinkedSuccess() {
        HUD.flash(.labeledSuccess(title: L10n.Alerts.accountLinkedTitle, subtitle: nil), delay: Durations.alertFlashDuration.value)
    }

    private func hideHud() {
        HUD.hide()
    }

    private func showAccountCreationError(error: AccountCreationError) {
        let alert = UIAlertController.init(title: error.title,
                                           message: error.message,
                                           preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: L10n.Global.ok, style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showPinInfo() {
        if popTip.isVisible {
            popTip.hide()
        } else {
            popTip.shouldDismissOnTap = true
            popTip.entranceAnimation = .scale
            popTip.bubbleColor = UIColor.jamiSecondary
            popTip.textColor = UIColor.white
            let offset: CGFloat = 20.0
            popTip.offset = offset - scrollView.contentOffset.y
            popTip.show(text: L10n.LinkToAccount.explanationPinMessage, direction: .down,
                        maxWidth: 255, in: self.view, from: pinInfoButton.frame)
        }
    }
}
