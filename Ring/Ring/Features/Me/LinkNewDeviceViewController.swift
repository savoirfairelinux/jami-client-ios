/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

class LinkNewDeviceViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: LinkNewDeviceViewModel!
    let disposeBag = DisposeBag()
    var loadingViewPresenter = LoadingViewPresenter()

    override func viewDidLoad() {
        view.backgroundColor = UIColor.white.withAlphaComponent(0.0)
        super.viewDidLoad()

        viewModel.observableState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                switch state {
                case .generatingPin:
                    self?.showProgress()
                case let .success(pin):
                    self?.hideHud()
                    self?.showSuccessAlert(pin: pin)
                case let .error(pinError):
                    self?.hideHud()
                    self?.showErrorAlert(error: pinError.description)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showInitialAlert()
    }

    private func showProgress() {
        loadingViewPresenter.presentWithMessage(
            message: L10n.LinkDevice.hudMessage,
            presentingVC: self,
            animated: true
        )
    }

    private func hideHud() {
        loadingViewPresenter.hide(animated: false)
    }

    func showSuccessAlert(pin: String) {
        let alert = UIAlertController(title: pin,
                                      message: viewModel.explanationMessage,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: L10n.Global.ok,
                                   style: .default) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    func showInitialAlert() {
        let alert = UIAlertController(title: viewModel.linkDeviceTitleTitle,
                                      message: nil,
                                      preferredStyle: .alert)
        let actionCancel =
            UIAlertAction(title: L10n.Global.cancel,
                          style: .cancel) { [weak self] _ in
                self?.dismiss(animated: true, completion: nil)
            }
        let actionLink =
            UIAlertAction(title: L10n.Global.ok,
                          style: .default) { [weak self] _ in
                guard let self = self else { return }
                if !self.viewModel.hasPassord {
                    self.viewModel.linkDevice(with: "")
                    return
                }
                if let textFields = alert.textFields {
                    self.viewModel.linkDevice(with: textFields[0].text)
                }
            }
        alert.addAction(actionCancel)
        alert.addAction(actionLink)

        if viewModel.hasPassord {
            alert.addTextField { textField in
                textField.isSecureTextEntry = true
                textField.placeholder = L10n.Global.enterPassword
            }
        }
        present(alert, animated: true, completion: nil)
    }

    func showErrorAlert(error: String) {
        let alert = UIAlertController(title: Error,
                                      message: error,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: L10n.Global.ok,
                                   style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
}
