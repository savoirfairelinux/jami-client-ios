/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import SwiftyBeaver

//Constants
private struct SmartlistConstants {
    static let smartlistRowHeight: CGFloat = 64.0
    static let tableHeaderViewHeight: CGFloat = 24.0
    static let firstSectionHeightForHeader: CGFloat = 31.0 //Compensate the offset due to the label on the top of the tableView
    static let defaultSectionHeightForHeader: CGFloat = 55.0
}

class SmartlistViewController: UIViewController, StoryboardBased, ViewModelBased {

    private let log = SwiftyBeaver.self

    // MARK: outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var conversationsTableView: UITableView!
    @IBOutlet weak var searchResultsTableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var noConversationsView: UIView!
    @IBOutlet weak var searchTableViewLabel: UILabel!
    @IBOutlet weak var networkAlertLabel: UILabel!
    @IBOutlet weak var cellularAlertLabel: UILabel!
    @IBOutlet weak var networkAlertViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var settingsButton: UIButton!

    // MARK: members
    var viewModel: SmartlistViewModel!
    fileprivate let disposeBag = DisposeBag()

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupDataSources()
        self.setupTableViews()
        self.setupSearchBar()
        self.setupUI()
        self.applyShadow()

        /*
         Register to keyboard notifications to adjust tableView insets when the keybaord appears
         or disappears
         */
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(withNotification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .default
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.clear.cgColor
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
    }

    func setupUI() {
        self.navigationItem.title = L10n.Global.homeTabBarTitle

        self.viewModel.hideNoConversationsMessage
            .bind(to: self.noConversationsView.rx.isHidden)
            .disposed(by: disposeBag)

        self.networkAlertViewTopConstraint.constant = self.viewModel.networkConnectionState() == .none ? 0.0 : -56.0
        self.networkAlertLabel.text = L10n.Smartlist.noNetworkConnectivity
        self.cellularAlertLabel.text = L10n.Smartlist.cellularAccess

        self.viewModel.connectionState
            .subscribe(onNext: { connectionState in
                let newAlertHeight = connectionState == .none ? 0.0 : -56.0
                UIView.animate(withDuration: 0.25) {
                    self.networkAlertViewTopConstraint.constant = CGFloat(newAlertHeight)
                    self.view.layoutIfNeeded()
                }
            })
            .disposed(by: self.disposeBag)

        self.settingsButton.backgroundColor = nil
        self.settingsButton.rx.tap.subscribe(onNext: { _ in
            if let url = URL(string: UIApplicationOpenSettingsURLString) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }).disposed(by: self.disposeBag)

        self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.conversationsTableView.setEditing(editing, animated: true)
    }

    @objc func keyboardWillShow(withNotification notification: Notification) {
        let userInfo: Dictionary = notification.userInfo!
        guard let keyboardFrame: NSValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        let tabBarHeight = (self.tabBarController?.tabBar.frame.size.height)!

        self.conversationsTableView.contentInset.bottom = keyboardHeight - tabBarHeight
        self.searchResultsTableView.contentInset.bottom = keyboardHeight - tabBarHeight
        self.conversationsTableView.scrollIndicatorInsets.bottom = keyboardHeight - tabBarHeight
        self.searchResultsTableView.scrollIndicatorInsets.bottom = keyboardHeight - tabBarHeight
    }

    @objc func keyboardWillHide(withNotification notification: Notification) {
        self.conversationsTableView.contentInset.bottom = 0
        self.searchResultsTableView.contentInset.bottom = 0

        self.conversationsTableView.scrollIndicatorInsets.bottom = 0
        self.searchResultsTableView.scrollIndicatorInsets.bottom = 0
    }

    func setupDataSources() {
        //Configure cells closure for the datasources
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, ConversationSection.Item)
            -> UITableViewCell = {
                (   dataSource: TableViewSectionedDataSource<ConversationSection>,
                    tableView: UITableView,
                    indexPath: IndexPath,
                    conversationItem: ConversationSection.Item) in

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ConversationCell.self)
                cell.configureFromItem(conversationItem)
                return cell
        }

        //Create DataSources for conversations and filtered conversations
        let conversationsDataSource = RxTableViewSectionedReloadDataSource<ConversationSection>(configureCell: configureCell)
        let searchResultsDatasource = RxTableViewSectionedReloadDataSource<ConversationSection>(configureCell: configureCell)

        //Allows to delete
        conversationsDataSource.canEditRowAtIndexPath = { _, _  in
            return true
        }

        //Bind TableViews to DataSources
        self.viewModel.conversations
            .bind(to: self.conversationsTableView.rx.items(dataSource: conversationsDataSource))
            .disposed(by: disposeBag)

        self.viewModel.searchResults
            .bind(to: self.searchResultsTableView.rx.items(dataSource: searchResultsDatasource))
            .disposed(by: disposeBag)

        //Set header titles
        searchResultsDatasource.titleForHeaderInSection = { dataSource, index in
            return dataSource.sectionModels[index].header
        }
    }

    func setupTableViews() {

        //Set row height
        self.conversationsTableView.rowHeight = SmartlistConstants.smartlistRowHeight
        self.searchResultsTableView.rowHeight = SmartlistConstants.smartlistRowHeight

        //Register Cell
        self.conversationsTableView.register(cellType: ConversationCell.self)
        self.searchResultsTableView.register(cellType: ConversationCell.self)

        //Bind to ViewModel to show or hide the filtered results
        self.viewModel.isSearching.subscribe(onNext: { [unowned self] (isSearching) in
            self.searchResultsTableView.isHidden = !isSearching
        }).disposed(by: disposeBag)

        //Deselect the rows
        self.conversationsTableView.rx.itemSelected.subscribe(onNext: { [unowned self] indexPath in
            self.conversationsTableView.deselectRow(at: indexPath, animated: true)
        }).disposed(by: disposeBag)

        self.searchResultsTableView.rx.itemSelected.subscribe(onNext: { [unowned self] indexPath in
            self.searchResultsTableView.deselectRow(at: indexPath, animated: true)
        }).disposed(by: disposeBag)

        //Bind the search status label
        self.viewModel.searchStatus
            .observeOn(MainScheduler.instance)
            .bind(to: self.searchTableViewLabel.rx.text)
            .disposed(by: disposeBag)

        self.searchResultsTableView.rx.setDelegate(self).disposed(by: disposeBag)
        self.conversationsTableView.rx.setDelegate(self).disposed(by: disposeBag)
    }

    func setupSearchBar() {

        self.searchBar.returnKeyType = .done
        self.searchBar.autocapitalizationType = .none
        self.searchBar.tintColor = UIColor.ringMain

        self.view.bringSubview(toFront: self.searchBar)

        self.searchBar.layer.shadowColor = UIColor.black.cgColor
        self.searchBar.layer.shadowOffset = CGSize(width: 0.0, height: 2.5)
        self.searchBar.layer.shadowOpacity = 0.2
        self.searchBar.layer.shadowRadius = 3
        self.searchBar.layer.masksToBounds = false

        //Bind the SearchBar to the ViewModel
        self.searchBar.rx.text.orEmpty
            .debounce(Durations.textFieldThrottlingDuration.value, scheduler: MainScheduler.instance)
            .bind(to: self.viewModel.searchBarText)
            .disposed(by: disposeBag)

        //Show Cancel button
        self.searchBar.rx.textDidBeginEditing.subscribe(onNext: { [unowned self] in
            self.searchBar.setShowsCancelButton(true, animated: true)
        }).disposed(by: disposeBag)

        //Hide Cancel button
        self.searchBar.rx.textDidEndEditing.subscribe(onNext: { [unowned self] in
            self.searchBar.setShowsCancelButton(false, animated: true)
        }).disposed(by: disposeBag)

        //Cancel button event
        self.searchBar.rx.cancelButtonClicked.subscribe(onNext: { [unowned self] in
            self.cancelSearch()
        }).disposed(by: disposeBag)

        //Search button event
        self.searchBar.rx.searchButtonClicked.subscribe(onNext: { [unowned self] in
            self.searchBar.resignFirstResponder()
        }).disposed(by: disposeBag)
    }

    func cancelSearch() {
        self.searchBar.resignFirstResponder()
        self.searchBar.text = ""
        self.searchResultsTableView.isHidden = true
    }

    private func showDeleteConversationConfirmation(atIndex: IndexPath) {
        let alert = UIAlertController(title: L10n.Alerts.confirmDeleteConversationTitle, message: L10n.Alerts.confirmDeleteConversation, preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: L10n.Actions.deleteAction, style: .destructive) { (_: UIAlertAction!) -> Void in
            if let convToDelete: ConversationViewModel = try? self.conversationsTableView.rx.model(at: atIndex) {
                self.viewModel.delete(conversationViewModel: convToDelete)
            }
        }
        let cancelAction = UIAlertAction(title: L10n.Actions.cancelAction, style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }

    private func showBlockContactConfirmation(atIndex: IndexPath) {
        let alert = UIAlertController(title: L10n.Alerts.confirmBlockContactTitle, message: L10n.Alerts.confirmBlockContact, preferredStyle: .alert)
        let blockAction = UIAlertAction(title: L10n.Actions.blockAction, style: .destructive) { (_: UIAlertAction!) -> Void in
            if let conversation: ConversationViewModel = try? self.conversationsTableView.rx.model(at: atIndex) {
                self.viewModel.blockConversationsContact(conversationViewModel: conversation)
            }
        }
        let cancelAction = UIAlertAction(title: L10n.Actions.cancelAction, style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(blockAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
}

extension SmartlistViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            if tableView == self.conversationsTableView {
                return 0
            }
            return SmartlistConstants.firstSectionHeightForHeader
        } else {
            return SmartlistConstants.defaultSectionHeightForHeader
        }
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        let block = UITableViewRowAction(style: .normal, title: "Block") { _, index in
            self.showBlockContactConfirmation(atIndex: index)
        }
        block.backgroundColor = .orange

        let delete = UITableViewRowAction(style: .normal, title: "Clear") { _, index in
            self.showDeleteConversationConfirmation(atIndex: index)
        }
        delete.backgroundColor = .red

        return [delete, block]
    }

    private func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.cancelSearch()
        if let convToShow: ConversationViewModel = try? tableView.rx.model(at: indexPath) {
            self.viewModel.showConversation(withConversationViewModel: convToShow)
        }
    }
}
