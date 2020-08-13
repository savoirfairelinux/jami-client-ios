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
    @IBOutlet weak var boothSwitch: UIButton!
    @IBOutlet weak var networkAlertLabel: UILabel!
    @IBOutlet weak var networkAlertView: UIView!
    @IBOutlet weak var searchBarShadow: UIView!

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
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: {[weak self](_) in
                self?.placeVideoCall.updateGradientFrame()
                self?.placeAudioCall.updateGradientFrame()
            }).disposed(by: self.disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func applyL10n() {
        self.navigationItem.title = ""
        self.networkAlertLabel.text = L10n.Smartlist.noNetworkConnectivity
        boothSwitch.setTitle(L10n.AccountPage.disableBoothMode, for: .normal)
        placeAudioCall.setTitle(L10n.Actions.startAudioCall, for: .normal)
        placeVideoCall.setTitle(L10n.Actions.startVideoCall, for: .normal)
    }

    func setupUI() {
        view.backgroundColor = UIColor.jamiBackgroundSecondaryColor
        self.placeVideoCall.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.placeAudioCall.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        placeVideoCall.titleLabel?.ajustToTextSize()
        placeAudioCall.titleLabel?.ajustToTextSize()
        self.boothSwitch.setTitleColor(.jamiTextSecondary, for: .normal)
        self.searchView.editSearch
            .subscribe(onNext: {[weak self] (editing) in
                self?.logoView.isHidden = editing
                self?.boothSwitch.isHidden = editing
            }).disposed(by: disposeBag)

        self.placeVideoCall.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.startCall(audioOnly: false)
        }).disposed(by: self.disposeBag)

        self.placeAudioCall.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.startCall(audioOnly: true)
        }).disposed(by: self.disposeBag)
        self.boothSwitch.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.confirmBoothModeAlert()
            }).disposed(by: self.disposeBag)
        let isHidden = self.viewModel.networkConnectionState() == .none ? false : true
        self.networkAlertView.isHidden = isHidden
        self.viewModel.connectionState
            .subscribe(onNext: { [weak self] connectionState in
                let isHidden = connectionState == .none ? false : true
                self?.networkAlertView.isHidden = isHidden
            })
            .disposed(by: self.disposeBag)
    }

    @objc func keyboardWillShow(withNotification notification: Notification) {
        guard let userInfo: Dictionary = notification.userInfo else { return }
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
        searchBarShadow.backgroundColor = UIColor.jamiBackgroundSecondaryColor
        searchBarShadow.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
        searchBarShadow.layer.shadowOffset = CGSize(width: 0.0, height: 1.5)
        searchBarShadow.layer.shadowOpacity = 0.2
        searchBarShadow.layer.shadowRadius = 3
        searchBarShadow.layer.masksToBounds = false
        searchBarShadow.superview?.bringSubviewToFront(searchBarShadow)

        if #available(iOS 13.0, *) {
            let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
            visualEffectView.frame = searchBarShadow.bounds
            visualEffectView.isUserInteractionEnabled = false
            searchBarShadow.insertSubview(visualEffectView, at: 0)
            visualEffectView.translatesAutoresizingMaskIntoConstraints = false
            visualEffectView.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: 0).isActive = true
            visualEffectView.trailingAnchor.constraint(equalTo: searchBarShadow.trailingAnchor, constant: 0).isActive = true
            visualEffectView.leadingAnchor.constraint(equalTo: searchBarShadow.leadingAnchor, constant: 0).isActive = true
            visualEffectView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
            visualEffectView.bottomAnchor.constraint(equalTo: searchBarShadow.bottomAnchor, constant: 0).isActive = true
        } else {
            let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            visualEffectView.frame = searchBarShadow.bounds
            visualEffectView.isUserInteractionEnabled = false
            let background = UIView()
            background.frame = searchBarShadow.bounds
            background.backgroundColor = UIColor(red: 245, green: 245, blue: 245, alpha: 1.0)
            background.alpha = 0.7
            searchBarShadow.insertSubview(background, at: 0)
            searchBarShadow.insertSubview(visualEffectView, at: 0)
            background.translatesAutoresizingMaskIntoConstraints = false
            visualEffectView.translatesAutoresizingMaskIntoConstraints = false
            visualEffectView.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: 0).isActive = true
            background.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: 0).isActive = true
            visualEffectView.trailingAnchor.constraint(equalTo: searchBarShadow.trailingAnchor, constant: 0).isActive = true
            background.trailingAnchor.constraint(equalTo: searchBarShadow.trailingAnchor, constant: 0).isActive = true
            visualEffectView.leadingAnchor.constraint(equalTo: searchBarShadow.leadingAnchor, constant: 0).isActive = true
            background.leadingAnchor.constraint(equalTo: searchBarShadow.leadingAnchor, constant: 0).isActive = true
            visualEffectView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
            background.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
            visualEffectView.bottomAnchor.constraint(equalTo: searchBarShadow.bottomAnchor, constant: 0).isActive = true
            background.bottomAnchor.constraint(equalTo: searchBarShadow.bottomAnchor, constant: 0).isActive = true
        }
        logoView.superview?.bringSubviewToFront(logoView)
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
      }

      internal func stopLoadingView() {
          HUD.hide(animated: false)
      }

      internal func showLoadingViewWithoutText() {
          HUD.show(.labeledProgress(title: "", subtitle: nil))
      }
}
