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

import Reusable
import RxCocoa
import RxDataSources
import RxSwift
import UIKit

class IncognitoSmartListViewController: UIViewController, StoryboardBased, ViewModelBased {
    @IBOutlet var searchView: JamiSearchView!

    @IBOutlet var placeVideoCall: DesignableButton!
    @IBOutlet var placeAudioCall: DesignableButton!
    @IBOutlet var logoView: UIStackView!
    @IBOutlet var boothSwitch: UIButton!
    @IBOutlet var networkAlertLabel: UILabel!
    @IBOutlet var networkAlertView: UIView!
    @IBOutlet var searchBarShadow: UIView!
    var loadingViewPresenter = LoadingViewPresenter()

    var viewModel: IncognitoSmartListViewModel!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        setupSearchBar()
        searchView.configure(
            with: viewModel.injectionBag,
            source: viewModel,
            isIncognito: true,
            delegate: viewModel
        )
        setupUI()
        applyL10n()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(withNotification:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(withNotification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        tabBarController?.tabBar.isHidden = true
        tabBarController?.tabBar.layer.zPosition = -1
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.placeVideoCall.updateGradientFrame()
                self?.placeAudioCall.updateGradientFrame()
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func applyL10n() {
        navigationItem.title = ""
        networkAlertLabel.text = L10n.Smartlist.noNetworkConnectivity
        boothSwitch.setTitle(L10n.AccountPage.disableBoothMode, for: .normal)
        placeAudioCall.setTitle(L10n.Actions.startAudioCall, for: .normal)
        placeVideoCall.setTitle(L10n.Actions.startVideoCall, for: .normal)
    }

    func setupUI() {
        view.backgroundColor = UIColor.jamiBackgroundSecondaryColor
        placeVideoCall.applyGradient(
            with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark],
            gradient: .horizontal
        )
        placeAudioCall.applyGradient(
            with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark],
            gradient: .horizontal
        )
        placeVideoCall.titleLabel?.ajustToTextSize()
        placeAudioCall.titleLabel?.ajustToTextSize()
        boothSwitch.setTitleColor(.jamiTextSecondary, for: .normal)
        searchView.editSearch
            .subscribe(onNext: { [weak self] editing in
                self?.logoView.isHidden = editing
                self?.boothSwitch.isHidden = editing
            })
            .disposed(by: disposeBag)

        placeVideoCall.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.startCall(audioOnly: false)
            })
            .disposed(by: disposeBag)

        placeAudioCall.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.startCall(audioOnly: true)
            })
            .disposed(by: disposeBag)
        boothSwitch.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.confirmBoothModeAlert()
            })
            .disposed(by: disposeBag)
        let isHidden = viewModel.networkConnectionState() == .none ? false : true
        networkAlertView.isHidden = isHidden
        viewModel.connectionState
            .subscribe(onNext: { [weak self] connectionState in
                let isHidden = connectionState == .none ? false : true
                self?.networkAlertView.isHidden = isHidden
            })
            .disposed(by: disposeBag)
    }

    @objc
    func keyboardWillShow(withNotification notification: Notification) {
        guard let userInfo: Dictionary = notification.userInfo else { return }
        guard let keyboardFrame: NSValue =
                userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        guard let tabBarHeight = (tabBarController?.tabBar.frame.size.height) else {
            return
        }
        searchView.searchResultsTableView.contentInset.bottom = keyboardHeight - tabBarHeight
        searchView.searchResultsTableView.scrollIndicatorInsets
            .bottom = keyboardHeight - tabBarHeight
    }

    @objc
    func keyboardWillHide(withNotification _: Notification) {
        searchView.searchResultsTableView.contentInset.bottom = 0
        searchView.searchResultsTableView.scrollIndicatorInsets.bottom = 0
    }

    func setupSearchBar() {
        searchBarShadow.backgroundColor = UIColor.jamiBackgroundSecondaryColor
        searchBarShadow.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
        searchBarShadow.layer.shadowOffset = CGSize(width: 0.0, height: 1.5)
        searchBarShadow.layer.shadowOpacity = 0.2
        searchBarShadow.layer.shadowRadius = 3
        searchBarShadow.layer.masksToBounds = false
        searchBarShadow.superview?.bringSubviewToFront(searchBarShadow)

        let visualEffectView =
            UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        visualEffectView.frame = searchBarShadow.bounds
        visualEffectView.isUserInteractionEnabled = false
        searchBarShadow.insertSubview(visualEffectView, at: 0)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: 0)
            .isActive = true
        visualEffectView.trailingAnchor.constraint(
            equalTo: searchBarShadow.trailingAnchor,
            constant: 0
        ).isActive = true
        visualEffectView.leadingAnchor.constraint(
            equalTo: searchBarShadow.leadingAnchor,
            constant: 0
        ).isActive = true
        visualEffectView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        visualEffectView.bottomAnchor.constraint(equalTo: searchBarShadow.bottomAnchor, constant: 0)
            .isActive = true
        logoView.superview?.bringSubviewToFront(logoView)
    }

    let boothConfirmation = ConfirmationAlert()

    func confirmBoothModeAlert() {
        boothConfirmation.configure(title: L10n.AccountPage.disableBoothMode,
                                    msg: "",
                                    enable: false, presenter: self,
                                    disposeBag: disposeBag)
    }
}

extension IncognitoSmartListViewController: BoothModeConfirmationPresenter {
    func enableBoothMode(enable: Bool, password: String) -> Bool {
        return viewModel.enableBoothMode(enable: enable, password: password)
    }

    func switchBoothModeState(state _: Bool) {}

    func stopLoadingView() {
        loadingViewPresenter.hide(animated: false)
    }

    func showLoadingViewWithoutText() {
        loadingViewPresenter.presentWithMessage(message: "", presentingVC: self, animated: true)
    }
}
