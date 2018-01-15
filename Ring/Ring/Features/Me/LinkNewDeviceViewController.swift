/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

import Foundation
import Reusable
import RxSwift
import PKHUD

class LinkNewDeviceViewController: UIViewController, StoryboardBased, ViewModelBased {

    @IBOutlet weak var titleLable: UILabel!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var pinLabel: UILabel!
    @IBOutlet weak var explanationMessage: UILabel!
    @IBOutlet weak var errorMessage: UILabel!
    @IBOutlet weak var background: UIImageView!
    @IBOutlet weak var containerView: UIView!

    var viewModel: LinkNewDeviceViewModel!
    let disposeBag = DisposeBag()

    override func viewDidLoad() {

        self.background.image = self.view.convertViewToImage()
        self.applyL10n()

        // initial state
        self.viewModel.isInitialState
            .bind(to: self.titleLable.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.isInitialState.bind(to: self.passwordField.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.isInitialState.bind(to: self.cancelButton.rx.isHidden)
            .disposed(by: self.disposeBag)
        // error state
        self.viewModel.isErrorState.bind(to: self.errorMessage.rx.isVisible)
            .disposed(by: self.disposeBag)
        // success state
        self.viewModel.isSuccessState
            .bind(to: self.explanationMessage.rx.isVisible)
            .disposed(by: self.disposeBag)
        self.viewModel.isSuccessState
            .bind(to: self.pinLabel.rx.isVisible)
            .disposed(by: self.disposeBag)

        self.viewModel.observableState
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .generatingPin:
                    self?.showProgress()
                case .success(let pin):
                    self?.pinLabel.text = pin
                    self?.hideHud()
                case .error(let pinError):
                    self?.errorMessage.text = pinError.description
                    self?.hideHud()
                default:
                    break
                }
            }).disposed(by: self.disposeBag)

        cancelButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }).disposed(by: disposeBag)

        okButton.rx.tap.subscribe(onNext: { [unowned self] in
            if !self.passwordField.isHidden {
                self.viewModel.linkDevice(with: self.passwordField.text)
                self.passwordField.text = ""
            } else if !self.errorMessage.isHidden {
                self.viewModel.refresh()
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }).disposed(by: disposeBag)

        super.viewDidLoad()
    }

    private func showProgress() {
        HUD.show(.labeledProgress(title: L10n.Linkdevice.hudMessage, subtitle: nil), onView: self.containerView)
    }
    private func hideHud() {
        HUD.hide(animated: true)
    }

    private func applyL10n() {
        self.titleLable.text = self.viewModel.linkDeviceTitleTitle
        self.explanationMessage.text = self.viewModel.explanationMessage
        self.okButton.setTitle(self.viewModel.okButtonTitle, for: .normal)
        self.cancelButton.setTitle(self.viewModel.cancelButtonTitle, for: .normal)
        self.passwordField.placeholder = self.viewModel.passwordFieldPlaceholder
    }
}
