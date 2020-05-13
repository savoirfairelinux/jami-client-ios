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

import UIKit
import RxSwift
import RxDataSources
import RxCocoa
import Reusable
import PKHUD

class IncognitoSmartListViewController: UIViewController, StoryboardBased, ViewModelBased {

    @IBOutlet weak var searchView: JamiSearchView!

    @IBOutlet weak var placeVideoCall: UIButton!
    @IBOutlet weak var placeAudioCall: UIButton!
    @IBOutlet weak var logoView: UIStackView!
    @IBOutlet weak var boothSwitch: UISwitch!

    var viewModel: IncognitoSmartListViewModel!
    fileprivate let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        let searchBar = UISearchBar()
               searchBar.sizeToFit()
               searchBar.placeholder = ""
               self.navigationController?.navigationBar.topItem?.titleView = searchBar
               searchView.searchBar = searchBar
        searchView.configure(with: viewModel.injectionBag, source: viewModel, isIncognito: true)
        self.setupSearchBar()
        self.setupUI()
        self.applyL10n()
        self.configureRingNavigationBar()
        /*
         Register to keyboard notifications to adjust tableView insets when the keybaord appears
         or disappears
         */
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(withNotification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.tabBarController?.tabBar.isHidden = true
        self.tabBarController?.tabBar.layer.zPosition = -1
    }

    func applyL10n() {
        self.navigationItem.title = ""
    }

    func setupUI() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        self.searchView.editSearch
            .subscribe(onNext: {[weak self] (editing) in
                self?.logoView.isHidden = editing
            }).disposed(by: disposeBag)

        self.placeVideoCall.rx.tap.subscribe(onNext: { [weak self] in
            self?.viewModel.startVideoCall()
        }).disposed(by: self.disposeBag)

        self.placeAudioCall.rx.tap.subscribe(onNext: { [weak self] in
            self?.viewModel.startAudioCall()
        }).disposed(by: self.disposeBag)

        boothSwitch.rx
        .isOn.changed
        .subscribe(onNext: {[weak self] enable in
            if enable {
                return
            }
            self?.confirmBoothModeAlert()
            self?.boothSwitch.setOn(true, animated: false)
        }).disposed(by: self.disposeBag)
    }

    @objc func keyboardWillShow(withNotification notification: Notification) {
        guard let userInfo: Dictionary = notification.userInfo else {return}
        guard let keyboardFrame: NSValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        guard let tabBarHeight = (self.tabBarController?.tabBar.frame.size.height) else {
            return
        }
        self.searchView.searchResultsTableView.contentInset.bottom = keyboardHeight - tabBarHeight
        self.searchView.searchResultsTableView.scrollIndicatorInsets.bottom = keyboardHeight - tabBarHeight
    }

    @objc func keyboardWillHide(withNotification notification: Notification) {
        self.searchView.searchResultsTableView.contentInset.bottom = 0
        self.searchView.searchResultsTableView.scrollIndicatorInsets.bottom = 0
    }

    func setupSearchBar() {

    }

    func confirmBoothModeAlert() {
        let alert = UIAlertController(title: L10n.AccountPage.disableBoothMode,
                                      message: L10n.AccountPage.disableBoothModeExplanation,
                                      preferredStyle: .alert)
        let actionCancel = UIAlertAction(title: L10n.Actions.cancelAction,
                                         style: .cancel)
        let actionConfirm = UIAlertAction(title: L10n.Actions.doneAction,
                                          style: .default) { [weak self] _ in
                                            self?.showLoadingViewWithoutText()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                if let textFields = alert.textFields,
                                                    !textFields.isEmpty,
                                                    let text = textFields[0].text,
                                                    !text.isEmpty {
                                                    self?.stopLoadingView()
                                                    let result = self?.viewModel.enableBoothMode(enable: false, password: text)
                                                    if result ?? true {
                                                        self?.stopLoadingView()
                                                        return
                                                    }
                                                    self?.present(alert, animated: true, completion: nil)
                                                    textFields[1].text = L10n.AccountPage.changePasswordError
                                                    textFields[0].text = ""
                                                    self?.stopLoadingView()
                                                } else {
                                                    self?.stopLoadingView()
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
            textField.textColor = UIColor.red
            textField.textAlignment = .center
            textField.borderStyle = .none
            textField.backgroundColor = UIColor.clear
            textField.font =  UIFont.systemFont(ofSize: 11, weight: .thin)
        }

        if let textFields = alert.textFields {
            textFields[0].rx.text.map({text in
                if let text = text {
                    return !text.isEmpty
                }
                return false
            }).bind(to: actionConfirm.rx.isEnabled).disposed(by: self.disposeBag)
        }
        self.present(alert, animated: true, completion: nil)
        alert.textFields?[1].superview?.backgroundColor = .clear
        alert.textFields?[1].superview?.superview?.subviews[0].removeFromSuperview()
    }

    private func stopLoadingView() {
        HUD.hide(animated: false)
    }

    private func showLoadingViewWithoutText() {
        HUD.show(.labeledProgress(title: "", subtitle: nil))
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopLoadingView()
        super.viewWillDisappear(animated)
    }
}
