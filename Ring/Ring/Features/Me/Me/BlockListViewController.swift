/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import RxCocoa
import SwiftyBeaver
import Reusable

class BlockListViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: BlockListViewModel!
    let disposeBag = DisposeBag()
    let cellIdentifier = "BannedContactCell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noBlockedContactLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureRingNavigationBar()
        self.navigationItem.title = L10n.AccountPage.blockedContacts
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        UIApplication.shared.statusBarStyle = .default

        self.setupTableView()

        self.viewModel.contactListNotEmpty
            .observeOn(MainScheduler.instance)
            .bind(to: self.noBlockedContactLabel.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont(name: "HelveticaNeue-Light", size: 25)!,NSAttributedStringKey.foregroundColor : UIColor.jamiMain]
    }

    func setupTableView() {
        self.tableView.rowHeight = 64.0
        self.tableView.allowsSelection = false

        //Register cell
        self.tableView.register(cellType: BannedContactCell.self)
        self.viewModel
            .blockedContactsItems
            .observeOn(MainScheduler.instance)
            .bind(to: tableView.rx.items(cellIdentifier: cellIdentifier, cellType: BannedContactCell.self)) { [unowned self] _, item, cell in
                cell.configureFromItem(item)
                cell.unblockButton.rx.tap
                    .subscribe(onNext: { [weak self, weak item] in
                        if item == nil {return}
                        self?.unbanContactTapped(withItem: item!)
                    }).disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func unbanContactTapped(withItem item: BannedContactItem) {
        self.viewModel.unbanContact(contact: item.contact)
    }
}
