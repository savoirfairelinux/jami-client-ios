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
    @IBOutlet weak var linkButton: DesignableButton!
    @IBOutlet weak var pinTextField: DesignableTextField!
    @IBOutlet weak var passwordTextField: DesignableTextField!
    @IBOutlet weak var pinInfoButton: UIButton!
    @IBOutlet weak var pinLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    // MARK: members
    private let disposeBag = DisposeBag()
    var viewModel: LinkDeviceViewModel!
    let popTip = PopTip()

    let log = SwiftyBeaver.self

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .default
    }

    private func applyL10n() {
        self.linkButton.setTitle(L10n.Linktoaccount.linkButtonTitle, for: .normal)
        self.pinLabel.text = L10n.Linktoaccount.pinLabel
        self.passwordLabel.text = L10n.Linktoaccount.passwordLabel
        self.pinTextField.placeholder = L10n.Linktoaccount.pinPlaceholder
        self.passwordTextField.placeholder = L10n.Linktoaccount.passwordPlaceholder
    }

    private func showCreationHUD() {
        HUD.show(.labeledProgress(title: L10n.Linktoaccount.waitLinkToAccountTitle, subtitle: nil))
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
            popTip.bubbleColor = UIColor.ringSecondary
            popTip.textColor = UIColor.white
            let offset: CGFloat = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad) ? 60.0 : 80.0
            popTip.offset = offset - scrollView.contentOffset.y
            popTip.show(text: L10n.Linktoaccount.explanationPinMessage, direction: .down,
                        maxWidth: 250, in: self.view, from: pinInfoButton.frame)
        }
    }
}
