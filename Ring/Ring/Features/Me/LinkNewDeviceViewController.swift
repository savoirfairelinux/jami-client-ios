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

    var viewModel: LinkNewDeviceViewModel!
    let disposeBag = DisposeBag()

    override func viewDidLoad() {

        self.view.backgroundColor = UIColor.white.withAlphaComponent(0.0)
        super.viewDidLoad()
        self.showInitiaAlert()

        self.viewModel.observableState
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                switch state {
                case .generatingPin:
                    self?.showProgress()
                case .success(let pin):
                    self?.hideHud()
                    self?.showSuccessAlert(pin: pin)
                case .error(let pinError):
                    self?.showErrorAlert(error: pinError.description)
                    self?.hideHud()
                default:
                    break
                }
            }).disposed(by: self.disposeBag)
    }

    private func showProgress() {
        HUD.show(.labeledProgress(title: L10n.Linkdevice.hudMessage, subtitle: nil))
    }
    private func hideHud() {
        HUD.hide(animated: false)
    }

    func showSuccessAlert(pin: String) {
        let alert = UIAlertController(title: pin,
                                      message: self.viewModel.explanationMessage,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: L10n.Global.ok, style: .default) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }

    func showInitiaAlert() {
        let alert = UIAlertController(title: self.viewModel.linkDeviceTitleTitle,
                                      message: nil,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: "cancel", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }

        alert.addTextField { (textField) in
            textField.isSecureTextEntry = true
            textField.placeholder = "Enter password"
        }
        let action1 = UIAlertAction(title: "ok", style: .`default`) { _ in
            let textField = alert.textFields![0] as UITextField
            alert.dismiss(animated: false, completion: nil)
            self.viewModel.linkDevice(with: textField.text)
        }
        alert.addAction(action)
        alert.addAction(action1)
        self.present(alert, animated: true, completion: nil)

    }

    func showErrorAlert(error: String) {
        let alert = UIAlertController(title: Error,
                                      message: error,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: "ok", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
}
