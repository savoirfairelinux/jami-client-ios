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
fileprivate struct SmartlistConstants {
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
    @IBOutlet weak var networkAlertLabelTopConstraint: NSLayoutConstraint!

    // MARK: members
    var viewModel: SmartlistViewModel!
    fileprivate let disposeBag = DisposeBag()

    fileprivate var backgroundColorObservable: Observable<UIColor>!

    // MARK: functions
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupDataSources()
        self.setupTableViews()
        self.setupSearchBar()
        self.setupUI()

        /*
         Register to keyboard notifications to adjust tableView insets when the keybaord appears
         or disappears
         */
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(withNotification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    func setupUI() {

        self.title = L10n.Global.homeTabBarTitle
        self.navigationItem.title = L10n.Global.homeTabBarTitle

        self.viewModel.hideNoConversationsMessage
            .bind(to: self.noConversationsView.rx.isHidden)
            .disposed(by: disposeBag)

        let connectionState = self.viewModel.networkConnectionState()
        self.networkAlertLabelTopConstraint.constant = connectionState == .none || connectionState == .cellular ? 0.0 : -44.0

        self.viewModel.networkStatus
            .subscribe(onNext: { connectionState in
                let newAlertHeight = connectionState == .none || connectionState == .cellular ? 0.0 : -44.0

                if connectionState == .none {

                } else if connectionState == .cellular {

                }
                UIView.animate(withDuration: 0.25) {
                    self.networkAlertLabelTopConstraint.constant = CGFloat(newAlertHeight)
                    self.view.layoutIfNeeded()
                }
            })
            .disposed(by: self.disposeBag)

        self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.conversationsTableView.setEditing(editing, animated: true)
    }

    func keyboardWillShow(withNotification notification: Notification) {
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

    func keyboardWillHide(withNotification notification: Notification) {
        self.conversationsTableView.contentInset.bottom = 0
        self.searchResultsTableView.contentInset.bottom = 0

        self.conversationsTableView.scrollIndicatorInsets.bottom = 0
        self.searchResultsTableView.scrollIndicatorInsets.bottom = 0
    }

    func setupDataSources() {

        //Create DataSources for conversations and filtered conversations
        let conversationsDataSource = RxTableViewSectionedReloadDataSource<ConversationSection>()
        let searchResultsDatasource = RxTableViewSectionedReloadDataSource<ConversationSection>()

        //Configure cells closure for the datasources
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, ConversationSection.Item)
            -> UITableViewCell = {
                (   dataSource: TableViewSectionedDataSource<ConversationSection>,
                    tableView: UITableView,
                    indexPath: IndexPath,
                    item: ConversationSection.Item) in

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ConversationCell.self)

                item.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .bind(to: cell.nameLabel.rx.text)
                    .disposed(by: cell.disposeBag)

                // Avatar placeholder initial
                item.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .map { value in value.prefixString().capitalized }
                    .bind(to: cell.fallbackAvatar.rx.text)
                    .disposed(by: cell.disposeBag)

                // UIColor that observes "best Id" prefix
                self.backgroundColorObservable = item.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .map { name in
                        let scanner = Scanner(string: name.toMD5HexString().prefixString())
                        var index: UInt64 = 0
                        if scanner.scanHexInt64(&index) {
                            return avatarColors[Int(index)]
                        }
                        return defaultAvatarColor
                    }

                // Set placeholder avatar to backgroundColorObservable
                self.backgroundColorObservable
                    .subscribe(onNext: { backgroundColor in
                        cell.fallbackAvatar.backgroundColor = backgroundColor
                    })
                    .disposed(by: cell.disposeBag)

                // Set image if any
                cell.fallbackAvatar.isHidden = false
                cell.profileImage.image = nil
                if let imageData = item.profileImageData {
                    if let image = UIImage(data: imageData) {
                        cell.profileImage.image = image
                        cell.fallbackAvatar.isHidden = true
                    }
                }

                cell.newMessagesLabel.text = item.unreadMessages
                cell.lastMessageDateLabel.text = item.lastMessageReceivedDate
                cell.newMessagesIndicator.isHidden = item.hideNewMessagesLabel
                cell.lastMessagePreviewLabel.text = item.lastMessage

                item.contactPresence.asObservable()
                    .observeOn(MainScheduler.instance)
                    .map { value in !value }
                    .bind(to: cell.presenceIndicator.rx.isHidden)
                    .disposed(by: cell.disposeBag)

                return cell
        }

        //Allows to delete
        conversationsDataSource.canEditRowAtIndexPath = { _ in
            return true
        }

        conversationsDataSource.configureCell = configureCell
        searchResultsDatasource.configureCell = configureCell

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

        //Show the Messages screens and pass the viewModel for Conversations
        self.conversationsTableView.rx.modelSelected(ConversationViewModel.self).subscribe(onNext: { [unowned self] item in
            self.cancelSearch()
            self.viewModel.showConversation(withConversationViewModel: item)
        }).disposed(by: disposeBag)

        //Show the Messages screens and pass the viewModel for Search Results
        self.searchResultsTableView.rx.modelSelected(ConversationViewModel.self).subscribe(onNext: { [unowned self] item in
            self.cancelSearch()
            self.viewModel.showConversation(withConversationViewModel: item)
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

        //Swipe to delete action
        self.conversationsTableView.rx.itemDeleted.subscribe(onNext: { [unowned self] indexPath in
            if let convToDelete: ConversationViewModel = try? self.conversationsTableView.rx.model(at: indexPath) {
                self.viewModel.delete(conversationViewModel: convToDelete)
            }
        }).disposed(by: disposeBag)
    }

    func setupSearchBar() {

        self.searchBar.returnKeyType = .done

        self.searchBar.layer.shadowColor = UIColor.black.cgColor
        self.searchBar.layer.shadowOpacity = 0.5
        self.searchBar.layer.shadowOffset = CGSize.zero
        self.searchBar.layer.shadowRadius = 2

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

}

extension SmartlistViewController : UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {

        if section == 0 {
            return SmartlistConstants.firstSectionHeightForHeader
        } else {
            return SmartlistConstants.defaultSectionHeightForHeader
        }
    }
}
