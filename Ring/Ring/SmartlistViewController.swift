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

//Constants
fileprivate let conversationCellIdentifier = "ConversationCellId"
fileprivate let conversationCellNibName = "ConversationCell"
fileprivate let smartlistRowHeight :CGFloat = 64.0
fileprivate let showMessages = "ShowMessages"

class SmartlistViewController: UIViewController {

    @IBOutlet weak var conversationsTableView: UITableView!
    @IBOutlet weak var searchResultsTableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var noConversationsView: UIView!
    @IBOutlet weak var searchTableViewLabel: UILabel!

    fileprivate let viewModel = SmartlistViewModel(withMessagesService: AppDelegate.messagesService,
                                                   nameService: AppDelegate.nameService)
    fileprivate let disposeBag = DisposeBag()
    fileprivate let tableHeaderViewHeight :CGFloat = 24.0

    //ConverationViewModel to be passed to the Messages screen
    fileprivate var selectedItem: ConversationViewModel?

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

        let title = NSLocalizedString("HomeTabBarTitle", tableName: "Global", comment: "")

        self.title = title
        self.navigationItem.title = title

        self.viewModel.hideNoConversationsMessage
            .bind(to: self.noConversationsView.rx.isHidden)
            .addDisposableTo(disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    func keyboardWillShow(withNotification notification: Notification) {
        let userInfo: Dictionary = notification.userInfo!
        let keyboardFrame: NSValue = userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue
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
            (ds: TableViewSectionedDataSource<ConversationSection>, tv: UITableView, ip: IndexPath, item: ConversationSection.Item) in
            let cell = tv.dequeueReusableCell(withIdentifier:conversationCellIdentifier, for: ip) as! ConversationCell
            item.userName.bind(to: cell.nameLabel.rx.text).addDisposableTo(self.disposeBag)
            cell.newMessagesLabel.text = item.unreadMessages
            cell.lastMessageDateLabel.text = item.lastMessageReceivedDate
            cell.hideNewMessagesLabel(item.hideNewMessagesLabel)
            return cell
        }

        conversationsDataSource.configureCell = configureCell
        searchResultsDatasource.configureCell = configureCell

        self.viewModel.conversations
            .bind(to: self.conversationsTableView.rx.items(dataSource: conversationsDataSource))
            .addDisposableTo(disposeBag)

        self.viewModel.searchResults
            .bind(to: self.searchResultsTableView.rx.items(dataSource: searchResultsDatasource))
            .addDisposableTo(disposeBag)

        searchResultsDatasource.titleForHeaderInSection = { ds, index in
            return ds.sectionModels[index].header
        }
    }

    func setupTableViews() {

        //Set row height
        self.conversationsTableView.rowHeight = smartlistRowHeight
        self.searchResultsTableView.rowHeight = smartlistRowHeight

        //Register Cell
        self.conversationsTableView.register(UINib.init(nibName: conversationCellNibName, bundle: nil), forCellReuseIdentifier: conversationCellIdentifier)
        self.searchResultsTableView.register(UINib.init(nibName: conversationCellNibName, bundle: nil), forCellReuseIdentifier: conversationCellIdentifier)

        //Bind to ViewModel to show or hide the filtered results
        self.viewModel.isSearching.subscribe(onNext: { isSearching in
            self.searchResultsTableView.isHidden = !isSearching
        }).addDisposableTo(disposeBag)

        //Show the Messages screens and pass the viewModel for Conversations
        self.conversationsTableView.rx.modelSelected(ConversationViewModel.self).subscribe(onNext: { item in
            self.selectedItem = item
            self.performSegue(withIdentifier: showMessages, sender: nil)
        }).addDisposableTo(disposeBag)

        //Show the Messages screens and pass the viewModel for Search Results
        self.searchResultsTableView.rx.modelSelected(ConversationViewModel.self).subscribe(onNext: { item in
            self.selectedItem = item
            self.performSegue(withIdentifier: showMessages, sender: nil)
        }).addDisposableTo(disposeBag)

        //Deselect the rows
        self.conversationsTableView.rx.itemSelected.asObservable().subscribe(onNext: { indexPath in
            self.conversationsTableView.deselectRow(at: indexPath, animated: true)
        }).addDisposableTo(disposeBag)

        self.searchResultsTableView.rx.itemSelected.asObservable().subscribe(onNext: { indexPath in
            self.searchResultsTableView.deselectRow(at: indexPath, animated: true)
        }).addDisposableTo(disposeBag)

        //Bind the search status label
        self.viewModel.searchStatus
            .observeOn(MainScheduler.instance)
            .bind(to: self.searchTableViewLabel.rx.text)
            .addDisposableTo(disposeBag)
    }

    func setupSearchBar() {

        self.searchBar.returnKeyType = .done

        //Bind the SearchBar to the ViewModel
        self.searchBar.rx.text.orEmpty
            .debounce(textFieldThrottlingDuration, scheduler: MainScheduler.instance)
            .bind(to: self.viewModel.searchBarText)
            .addDisposableTo(disposeBag)

        //Cancel button event
        self.searchBar.rx.cancelButtonClicked.subscribe(onNext: {
            self.cancelSearch()
        }).addDisposableTo(disposeBag)

        //Search button event
        self.searchBar.rx.searchButtonClicked.subscribe(onNext: {
            self.searchBar.resignFirstResponder()
        }).addDisposableTo(disposeBag)
    }

    func cancelSearch() {
        self.searchBar.resignFirstResponder()
        self.searchBar.text = ""
        self.searchResultsTableView.isHidden = true
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        self.cancelSearch()

        if let msgVC = segue.destination as? MessagesViewController {
            self.viewModel.selected(item: self.selectedItem!)
            msgVC.viewModel = self.selectedItem
        }
    }

}
