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

class SmartlistViewController: UIViewController, UITableViewDelegate {

    @IBOutlet weak var conversationsTableView: UITableView!
    @IBOutlet weak var searchResultsTableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    fileprivate let viewModel = SmartlistViewModel(withMessagesService: AppDelegate.messagesService)
    fileprivate let disposeBag = DisposeBag()

    //ConverationViewModel to be passed to the Messages screen
    fileprivate var selectedItem: ConversationViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupDataSources()
        self.setupTableViews()
        self.setupSearchBar()
    }

    func setupDataSources() {

        //Create a common DataSource for conversations and filtered conversations
        let dataSource = RxTableViewSectionedReloadDataSource<ConversationSection>()

        //Configure cells for this DataSource
        dataSource.configureCell = { (ds: TableViewSectionedDataSource, tv: UITableView, ip: IndexPath, item: ConversationViewModel) in
            let cell = tv.dequeueReusableCell(withIdentifier:conversationCellIdentifier, for: ip) as! ConversationCell
            item.userName.bindTo(cell.nameLabel.rx.text).addDisposableTo(self.disposeBag)
            cell.newMessagesLabel.text = item.unreadMessages
            cell.lastMessageDateLabel.text = item.lastMessageReceivedDate
            return cell
        }

        /* Projects each element of observable ConversationViewModels sequence into a ConversationSection sequence
         to be consumable by the RxDataSource for conversations and filtered conversation tableviews
         */

        self.viewModel.conversationsViewModels.asObservable().map({ conversationsViewModels in
            return [ConversationSection(header: "", items: conversationsViewModels)]
        }).bindTo(self.conversationsTableView.rx.items(dataSource: dataSource)).addDisposableTo(disposeBag)

        self.viewModel.searchResultsViewModels.asObservable().map({ conversationsViewModels in
            return [ConversationSection(header: "", items: conversationsViewModels)]
        }).bindTo(self.searchResultsTableView.rx.items(dataSource: dataSource)).addDisposableTo(disposeBag)
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
        
        //Show the Messages screens and pass the viewModel
        self.conversationsTableView.rx.modelSelected(ConversationViewModel.self).subscribe(onNext: { item in
            self.selectedItem = item
            self.performSegue(withIdentifier: "ShowMessages", sender: nil)
        }).addDisposableTo(disposeBag)

        //Show the Messages screens and pass the viewModel
        self.searchResultsTableView.rx.modelSelected(ConversationViewModel.self).subscribe(onNext: { item in
            self.selectedItem = item
            self.performSegue(withIdentifier: "ShowMessages", sender: nil)
        }).addDisposableTo(disposeBag)
    }

    func setupSearchBar() {

        //Bind the SearchBar to the ViewModel
        self.searchBar.rx.text.orEmpty.bindTo(self.viewModel.searchBarText).addDisposableTo(disposeBag)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let msgVC = segue.destination as? MessagesViewController {
            msgVC.viewModel = self.selectedItem
        }
    }
}
