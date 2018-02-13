/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
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
        self.navigationItem.title = L10n.Accountpage.blockedContacts
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupTableView()

        self.viewModel.contactListNotEmpty
            .observeOn(MainScheduler.instance)
            .bind(to: self.noBlockedContactLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
    }

    func setupTableView() {
        self.tableView.rowHeight = 64.0
        self.tableView.allowsSelection = false

        //Register cell
        self.tableView.register(cellType: BannedContactCell.self)
        self.viewModel
            .blockedContactsItems
            .observeOn(MainScheduler.instance)
            .bind(to: tableView.rx.items(cellIdentifier: cellIdentifier,
                                         cellType: BannedContactCell.self))
            { [unowned self] _, item, cell in

                if let displayName = item.displayName {
                    cell.displayNameLabel.text = displayName
                }

                if let name = item.contact.userName {
                    cell.userNameLabel.text = name
                } else {
                    cell.userNameLabel.text = item.contact.ringId
                }

                cell.fallbackAvatar.text = nil
                cell.fallbackAvatarImage.isHidden = true
                if let name = item.contact.userName {
                    let scanner = Scanner(string: name.toMD5HexString().prefixString())
                    var index: UInt64 = 0
                    if scanner.scanHexInt64(&index) {
                        cell.fallbackAvatar.isHidden = false
                        cell.fallbackAvatar.backgroundColor = avatarColors[Int(index)]
                        if item.contact.ringId != name {
                            cell.fallbackAvatar.text = name.prefixString().capitalized
                        } else {
                            cell.fallbackAvatarImage.isHidden = false
                        }
                    }
                }
                cell.fallbackAvatar.isHidden = false
                cell.profileImageView.image = nil

                if let imageData = item.image, let image = UIImage(data: imageData) {
                    cell.profileImageView.image = image
                    cell.fallbackAvatar.isHidden = true
                }
                cell.unblockButton.titleLabel?.text = L10n.Accountpage.unblockContact
                cell.unblockButton.rx.tap
                    .subscribe(onNext: { [unowned self] in
                        self.unbanContactTapped(withItem: item)
                    }).disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func unbanContactTapped(withItem item: BannedContactItem) {
        self.viewModel.unbanContact(contact: item.contact)
    }
}
