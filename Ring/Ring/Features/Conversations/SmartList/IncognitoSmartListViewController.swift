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

    @IBOutlet weak var placeVideoCall: DesignableButton!
    @IBOutlet weak var placeAudioCall: DesignableButton!
    @IBOutlet weak var logoView: UIStackView!
    @IBOutlet weak var boothSwitch: UISwitch!
    @IBOutlet weak var boothSwitchLabel: UILabel!
    @IBOutlet weak var networkAlertLabel: UILabel!
    @IBOutlet weak var networkAlertView: UIView!

    var viewModel: IncognitoSmartListViewModel!
    fileprivate let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureRingNavigationBar()
        self.setupSearchBar()
        searchView.configure(with: viewModel.injectionBag, source: viewModel, isIncognito: true)
        self.setupUI()
        self.applyL10n()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(withNotification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.tabBarController?.tabBar.isHidden = true
        self.tabBarController?.tabBar.layer.zPosition = -1
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.setBackgroundImage(nil, for: UIBarMetrics.default)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
    }

    func applyL10n() {
        self.navigationItem.title = ""
        self.networkAlertLabel.text = L10n.Smartlist.noNetworkConnectivity
        boothSwitchLabel.text = L10n.AccountPage.disableBoothMode
        placeAudioCall.setTitle(L10n.Actions.startAudioCall, for: .normal)
        placeVideoCall.setTitle(L10n.Actions.startVideoCall, for: .normal)
    }

    func setupUI() {
        view.backgroundColor = UIColor.jamiBackgroundColor
        self.placeVideoCall.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.placeAudioCall.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.searchView.editSearch
            .subscribe(onNext: {[weak self] (editing) in
                self?.logoView.isHidden = editing
            }).disposed(by: disposeBag)

        self.placeVideoCall.rx.tap
            .subscribe(onNext: { [weak self] in
            self?.viewModel.startVideoCall()
        }).disposed(by: self.disposeBag)

        self.placeAudioCall.rx.tap
            .subscribe(onNext: { [weak self] in
            self?.viewModel.startAudioCall()
        }).disposed(by: self.disposeBag)

        self.viewModel.switchBoothModeState
            .observeOn(MainScheduler.instance)
            .bind(to: boothSwitch.rx.value)
            .disposed(by: self.disposeBag)
        boothSwitch.rx
        .isOn.changed
        .subscribe(onNext: {[weak self] enable in
            if enable {
                return
            }
            self?.viewModel.switchBoothModeState.onNext(enable)
            self?.confirmBoothModeAlert()
        }).disposed(by: self.disposeBag)
        let isHidden = self.viewModel.networkConnectionState() == .none ? false : true
        self.networkAlertView.isHidden = isHidden
        self.viewModel.connectionState
            .subscribe(onNext: { connectionState in
                let isHidden = connectionState == .none ? false : true
                self.networkAlertView.isHidden = isHidden
            })
            .disposed(by: self.disposeBag)
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
        let searchBar = UISearchBar()
        searchBar.sizeToFit()
        self.navigationController?.navigationBar.topItem?.titleView = searchBar
        searchView.searchBar = searchBar
    }

    let boothConfirmation = ConfirmationAlert()

    func confirmBoothModeAlert() {
        boothConfirmation.configure(title: L10n.AccountPage.disableBoothMode,
                                           msg: "",
                                           enable: false, presenter: self,
                                           disposeBag: self.disposeBag)
    }
}

extension IncognitoSmartListViewController: BoothModeConfirmationPresenter {
    func enableBoothMode(enable: Bool, password: String) -> Bool {
          return self.viewModel.enableBoothMode(enable: enable, password: password)
      }

      func switchBoothModeState(state: Bool) {
          self.viewModel.switchBoothModeState.onNext(state)
      }

      internal func stopLoadingView() {
          HUD.hide(animated: false)
      }

      internal func showLoadingViewWithoutText() {
          HUD.show(.labeledProgress(title: "", subtitle: nil))
      }
}
