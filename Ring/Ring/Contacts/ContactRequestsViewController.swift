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
import RxCocoa
import SwiftyBeaver

class ContactRequestsViewController: UITableViewController {

    fileprivate let viewModel = ContactRequestsViewModel(withContactsService: AppDelegate.contactsService,
                                           accountsService: AppDelegate.accountService,
                                           nameService: AppDelegate.nameService)

    fileprivate let disposeBag = DisposeBag()
    fileprivate let cellIdentifier = "ContactRequestCell"
    fileprivate let log = SwiftyBeaver.self

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupTableView()
    }

    func setupTableView() {
        self.tableView.estimatedRowHeight = 100.0
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.allowsSelection = false

        //Register cell
        self.tableView.register(cellType: ContactRequestCell.self)

        //Bind the TableView to the ViewModel
        self.viewModel
            .contactRequestItems
            .observeOn(MainScheduler.instance)
            .bind(to: tableView.rx.items(cellIdentifier: cellIdentifier, cellType: ContactRequestCell.self)) { [unowned self] _, item, cell in
                item.userName
                    .observeOn(MainScheduler.instance)
                    .bind(to: cell.nameLabel.rx.text)
                    .disposed(by: cell.disposeBag)

                //Accept button
                cell.acceptButton.rx.tap.subscribe(onNext: {
                    self.acceptButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)

                //Discard button
                cell.discardButton.rx.tap.subscribe(onNext: {
                    self.discardButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)

                //Ban button
                cell.banButton.rx.tap.subscribe(onNext: {
                    self.banButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func acceptButtonTapped(withItem item: ContactRequestItem) {
        item.accept().subscribe(onError: { error in
            self.log.error("Accept trust request failed")
        }, onCompleted: {
            self.log.info("Accept trust request done")
        }).disposed(by: self.disposeBag)
    }

    func discardButtonTapped(withItem item: ContactRequestItem) {
        item.discard().subscribe(onCompleted: {
            self.log.info("Discard trust request done")
        }, onError: { [unowned self] error in
            self.log.error("Discard trust request failed")
        }).disposed(by: self.disposeBag)
    }

    func banButtonTapped(withItem item: ContactRequestItem) {
        item.ban().subscribe(onError: { [unowned self] error in
            self.log.error("Ban trust request failed")
        }, onCompleted: {
            self.log.info("Ban trust request done")
        }).disposed(by: self.disposeBag)
    }
}
