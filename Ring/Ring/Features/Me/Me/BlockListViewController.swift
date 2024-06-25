/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
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

import Reusable
import RxCocoa
import RxSwift
import SwiftyBeaver
import UIKit

class BlockListViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: BlockListViewModel!
    let disposeBag = DisposeBag()
    let cellIdentifier = "BannedContactCell"
    @IBOutlet var tableView: UITableView!
    @IBOutlet var noBlockedContactLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = UIColor.jamiBackgroundColor
        noBlockedContactLabel.backgroundColor = UIColor.jamiBackgroundColor
        noBlockedContactLabel.textColor = UIColor.jamiLabelColor

        configureNavigationBar()
        navigationItem.title = L10n.AccountPage.blockedContacts
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupTableView()
        noBlockedContactLabel.text = L10n.BlockListPage.noBlockedContacts

        viewModel.contactListNotEmpty
            .observe(on: MainScheduler.instance)
            .bind(to: noBlockedContactLabel.rx.isHidden)
            .disposed(by: disposeBag)
        navigationController?.navigationBar
            .titleTextAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                NSAttributedString.Key.foregroundColor: UIColor.jamiLabelColor
            ]
    }

    func setupTableView() {
        tableView.rowHeight = 64.0
        tableView.allowsSelection = false

        // Register cell
        tableView.register(cellType: BannedContactCell.self)
        viewModel
            .blockedContactsItems
            .observe(on: MainScheduler.instance)
            .bind(to: tableView.rx.items(
                cellIdentifier: cellIdentifier,
                cellType: BannedContactCell.self
            )) { [weak self] _, item, cell in
                cell.configureFromItem(item)
                cell.unblockButton.rx.tap
                    .subscribe(onNext: { [weak self, weak item] in
                        guard let contact = item else { return }
                        self?.unbanContactTapped(withItem: contact)
                    })
                    .disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func unbanContactTapped(withItem item: BannedContactItem) {
        viewModel.unbanContact(contact: item.contact)
    }
}
