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

class SmartlistViewController: UIViewController, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    fileprivate let viewModel = SmartlistViewModel(withMessagesService: AppDelegate.messagesService)
    fileprivate let disposeBag = DisposeBag()
    fileprivate let SmartlistRowHeight :CGFloat = 64.0

    var selectedItem: ConversationViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.setupTableView()
    }

    func setupUI() {
        self.title = NSLocalizedString("HomeTabBarTitle", tableName: "Global", comment: "")
    }

    func setupTableView() {

        //Set row height
        self.tableView.rowHeight = SmartlistRowHeight

        //Register Cell
        self.tableView.register(UINib.init(nibName: "ConversationCell", bundle: nil), forCellReuseIdentifier: "ConversationCellId")

        //Bind the TableView to the ViewModel
        self.viewModel.conversations.asObservable().bindTo(tableView.rx.items(cellIdentifier: "ConversationCellId", cellType: ConversationCell.self) ) { index, viewModel, cell in
            viewModel.userName.bindTo(cell.nameLabel.rx.text).addDisposableTo(self.disposeBag)
            cell.newMessagesLabel.text = viewModel.unreadMessages
            cell.lastMessageDateLabel.text = viewModel.lastMessageReceivedDate
            cell.hideNewMessagesLabel(viewModel.hideNewMessagesLabel)
        }.addDisposableTo(disposeBag)

        //Deselect the row
        self.tableView.rx.itemSelected.asObservable().subscribe(onNext: { indexPath in
            self.tableView.deselectRow(at: indexPath, animated: true)
        }).addDisposableTo(disposeBag)

        //Show the Messages screens and pass the viewModel
        self.tableView.rx.modelSelected(ConversationViewModel.self).subscribe(onNext: { item in
            self.selectedItem = item
            self.performSegue(withIdentifier: "ShowMessages", sender: nil)
        }).addDisposableTo(disposeBag)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let msgVC = segue.destination as? MessagesViewController {
            msgVC.viewModel = self.selectedItem
        }
    }

}
