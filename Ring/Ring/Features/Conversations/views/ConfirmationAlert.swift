/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

import RxSwift

protocol BoothModeConfirmationPresenter: UIViewController {
    func showLoadingViewWithoutText()
    func stopLoadingView()
    func enableBoothMode(enable: Bool, password: String) -> Bool
    func switchBoothModeState(state: Bool)
}

class ConfirmationAlert {
    var alert = UIAlertController()

    func configure(title: String,
                   msg: String,
                   enable: Bool,
                   presenter: BoothModeConfirmationPresenter,
                   disposeBag: DisposeBag) {
        alert = UIAlertController(title: title,
                                  message: msg,
                                  preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
                                         style: .cancel) { [weak presenter] _ in
                                            presenter?.switchBoothModeState(state: !enable)
        }
        let actionConfirm = UIAlertAction(title: L10n.Actions.doneAction,
                                          style: .default) { [weak presenter, weak self] _ in
                                            presenter?.showLoadingViewWithoutText()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                presenter?.stopLoadingView()
                                                if let textFields = self?.alert.textFields,
                                                    !textFields.isEmpty,
                                                    let text = textFields[0].text,
                                                    !text.isEmpty {
                                                    let result = presenter?.enableBoothMode(enable: enable, password: text)
                                                    if result ?? true {
                                                        return
                                                    }
                                                    presenter?.switchBoothModeState(state: !enable)
                                                    guard let self = self else {
                                                        return
                                                    }
                                                    presenter?.present(self.alert, animated: true, completion: nil)
                                                    textFields[1].text = L10n.AccountPage.changePasswordError
                                                    textFields[1].textColor = UIColor.red
                                                }
                                            }
        }
        alert.addAction(actionCancel)
        alert.addAction(actionConfirm)
        alert.addTextField {(textField) in
            textField.placeholder = L10n.Account.passwordLabel
            textField.isSecureTextEntry = true
        }
        alert.addTextField {(textField) in
            textField.text = ""
            textField.isUserInteractionEnabled = false
            textField.textColor = UIColor.jamiLabelColor
            textField.textAlignment = .center
            textField.borderStyle = .none
            textField.backgroundColor = UIColor.clear
            textField.font = UIFont.systemFont(ofSize: 11, weight: .thin)
            textField.text = L10n.AccountPage.passwordPlaceholder
        }

        if let textFields = alert.textFields {
            textFields[0].rx.text.map({text in
                if let text = text {
                    return !text.isEmpty
                }
                return false
            }).bind(to: actionConfirm.rx.isEnabled)
                .disposed(by: disposeBag)
        }
        presenter.present(alert, animated: true, completion: nil)
        alert.textFields?[1].superview?.backgroundColor = .clear
        alert.textFields?[1].superview?.superview?.subviews[0].removeFromSuperview()
    }
}
