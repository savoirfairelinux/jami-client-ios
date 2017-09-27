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
import Reusable

class ContactRequestsViewController: UIViewController, StoryboardBased, ViewModelBased {

    var viewModel: ContactRequestsViewModel!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noInvitationsPlaceholder: UIView!

    fileprivate let disposeBag = DisposeBag()
    fileprivate let cellIdentifier = "ContactRequestCell"
    fileprivate let log = SwiftyBeaver.self

    fileprivate var backgroundColorObservable: Observable<UIColor>!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L10n.Global.contactRequestsTabBarTitle
        self.navigationItem.title = L10n.Global.contactRequestsTabBarTitle
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupTableView()
        self.setupBindings()
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
                    .asObservable()
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
                    .map { name in
                        let scanner = Scanner(string: name.toMD5HexString().prefixString())
                        var index: UInt64 = 0
                        if scanner.scanHexInt64(&index) {
                            return avatarColors[Int(index)]!
                        }
                        return defaultAvatarColor!
                    }

                // Set placeholder avatar to backgroundColorObservable
                self.backgroundColorObservable
                    .subscribe(onNext: { backgroundColor in
                        cell.fallbackAvatar.backgroundColor = backgroundColor
                    })
                    .disposed(by: cell.disposeBag)

                if let imageData = item.profileImageData {
                    cell.profileImageView.image = UIImage(data: imageData)
                    if !imageData.isEmpty {
                        cell.fallbackAvatar.isHidden = true
                    }
                }

                //Accept button
                cell.acceptButton.rx.tap.subscribe(onNext: { [unowned self] in
                    self.acceptButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)

                //Discard button
                cell.discardButton.rx.tap.subscribe(onNext: { [unowned self] in
                    self.discardButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)

                //Ban button
                cell.banButton.rx.tap.subscribe(onNext: { [unowned self] in
                    self.banButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func setupBindings() {

        self.viewModel
            .hasInvitations
            .observeOn(MainScheduler.instance)
            .bind(to: self.noInvitationsPlaceholder.rx.isHidden)
            .disposed(by: self.disposeBag)
    }

    func acceptButtonTapped(withItem item: ContactRequestItem) {
        viewModel.accept(withItem: item).subscribe(onError: { [unowned self] error in
            self.log.error("Accept trust request failed")
            }, onCompleted: { [unowned self] in
                self.log.info("Accept trust request done")
        }).disposed(by: self.disposeBag)
    }

    func discardButtonTapped(withItem item: ContactRequestItem) {
        viewModel.discard(withItem: item).subscribe(onError: { [unowned self] error in
            self.log.error("Discard trust request failed")
            }, onCompleted: { [unowned self] in
                self.log.info("Discard trust request done")
        }).disposed(by: self.disposeBag)
    }

    func banButtonTapped(withItem item: ContactRequestItem) {
        viewModel.ban(withItem: item).subscribe(onError: { [unowned self] error in
            self.log.error("Ban trust request failed")
            }, onCompleted: { [unowned self] in
                self.log.info("Ban trust request done")
        }).disposed(by: self.disposeBag)
    }
}
