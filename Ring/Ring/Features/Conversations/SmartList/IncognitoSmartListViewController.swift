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

class IncognitoSmartListViewController: UIViewController, StoryboardBased, ViewModelBased {

    @IBOutlet weak var searchView: JamiSearchView!
    
    @IBOutlet weak var placeVideoCall: UIButton!
    @IBOutlet weak var placeAudioCall: UIButton!
    @IBOutlet weak var logoView: UIStackView!

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
}
