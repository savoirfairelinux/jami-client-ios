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
        self.tableView.rx.modelSelected(ContactRequestItem.self)
            .subscribe({ [unowned self] item in
                if let ringId = item.element?.contactRequest.ringId {
                    self.viewModel.showConversation(forRingId: ringId)
                }
            }).disposed(by: disposeBag)
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
        self.tableView.allowsSelection = true

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
                cell.fallbackAvatar.text = nil
                cell.fallbackAvatarImage.isHidden = true
                let name = item.userName.value
                let scanner = Scanner(string: name.toMD5HexString().prefixString())
                var index: UInt64 = 0
                if scanner.scanHexInt64(&index) {
                    cell.fallbackAvatar.isHidden = false
                    cell.fallbackAvatar.backgroundColor = avatarColors[Int(index)]
                    if item.contactRequest.ringId != name {
                        cell.fallbackAvatar.text = name.prefixString().capitalized
                    } else {
                        cell.fallbackAvatarImage.isHidden = false
                    }
                }

                item.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .filter({ [weak item] userName in
                        return userName != item?.contactRequest.ringId
                    })
                    .map { value in value.prefixString().capitalized }
                    .bind(to: cell.fallbackAvatar.rx.text)
                    .disposed(by: cell.disposeBag)

                item.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .map { [weak item] userName in userName != item?.contactRequest.ringId }
                    .bind(to: cell.fallbackAvatarImage.rx.isHidden)
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
                cell.profileImageView.image = nil

                item.profileImageData.asObservable()
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { data in
                        if let imageData = data {
                            if let image = UIImage(data: imageData) {
                                cell.profileImageView.image = image
                                cell.fallbackAvatar.isHidden = true
                            }
                        } else {
                            cell.fallbackAvatar.isHidden = false
                            cell.profileImageView.image = nil
                        }
                    }).disposed(by: cell.disposeBag)

                //Accept button
                cell.acceptButton.backgroundColor = UIColor.clear
                cell.acceptButton.rx.tap.subscribe(onNext: { [unowned self] in
                    self.acceptButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)

                //Discard button
                cell.discardButton.backgroundColor = UIColor.clear
                cell.discardButton.rx.tap.subscribe(onNext: { [unowned self] in
                    self.discardButtonTapped(withItem: item)
                }).disposed(by: cell.disposeBag)

                //Ban button
                cell.banButton.backgroundColor = UIColor.clear
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
