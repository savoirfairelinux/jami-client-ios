/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class ContactRequestsViewController: UIViewController, StoryboardBased, ViewModelBased {

    var viewModel: ContactRequestsViewModel!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noInvitationsPlaceholder: UIView!
    @IBOutlet weak var noRequestsLabel: UILabel!

    private let disposeBag = DisposeBag()
    private let cellIdentifier = "ContactRequestCell"
    private let log = SwiftyBeaver.self

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.jamiBackgroundColor
        self.tableView.backgroundColor = UIColor.jamiBackgroundColor
        noInvitationsPlaceholder.backgroundColor = UIColor.jamiBackgroundColor
        noRequestsLabel.backgroundColor = UIColor.jamiBackgroundColor
        noRequestsLabel.textColor = UIColor.jamiLabelColor
        self.configureRingNavigationBar()
        self.tableView.rx.modelSelected(ContactRequestItem.self)
            .subscribe({ [weak self] item in
                guard let self = self else { return }
                if let ringId = item.element?.contactRequest.ringId {
                    self.viewModel.showConversation(forRingId: ringId)
                }
            })
            .disposed(by: disposeBag)
        self.applyL10n()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupTableView()
        self.setupBindings()
        self.navigationController?.navigationBar
            .titleTextAttributes = [NSAttributedString.Key.font: UIFont(name: "HelveticaNeue-Light", size: 25)!,
                                    NSAttributedString.Key.foregroundColor: UIColor.jamiMain]
    }

    func applyL10n() {
        self.noRequestsLabel.text = L10n.Invitations.noInvitations
    }

    func setupTableView() {
        self.tableView.estimatedRowHeight = 100.0
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.allowsSelection = true
        self.tableView.tableFooterView = UIView()

        //Register cell
        self.tableView.register(cellType: ContactRequestCell.self)

        //Bind the TableView to the ViewModel
        self.viewModel
            .contactRequestItems
            .observeOn(MainScheduler.instance)
            .bind(to: tableView.rx.items(cellIdentifier: cellIdentifier, cellType: ContactRequestCell.self)) { [weak self] _, item, cell in
                cell.configureFromItem(item)

                //Accept button
                cell.acceptButton.backgroundColor = UIColor.clear
                cell.acceptButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.acceptButtonTapped(withItem: item)
                        if self?.tableView.numberOfRows(inSection: 0) ?? 0 <= 1 {
                            self?.view.isHidden = true
                        }
                    })
                    .disposed(by: cell.disposeBag)

                //Discard button
                cell.discardButton.backgroundColor = UIColor.clear
                cell.discardButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.discardButtonTapped(withItem: item)
                        self?.view.isHidden = true
                    })
                    .disposed(by: cell.disposeBag)

                //Ban button
                cell.banButton.backgroundColor = UIColor.clear
                cell.banButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.banButtonTapped(withItem: item)
                        self?.view.isHidden = true
                    })
                    .disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func setupBindings() {

        self.viewModel
            .hasInvitations
            .observeOn(MainScheduler.instance)
            .bind(to: self.noInvitationsPlaceholder.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel
            .hasInvitations
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: {[weak self] hasInvitation in
                if !hasInvitation {
                    self?.view.isHidden = true
                }
            })
            .disposed(by: self.disposeBag)
    }

    func acceptButtonTapped(withItem item: ContactRequestItem) {
        viewModel.accept(withItem: item)
            .subscribe(onError: { [weak self] error in
                self?.log.error("Accept trust request failed")
                }, onCompleted: { [weak self] in
                    self?.log.info("Accept trust request done")
            })
            .disposed(by: self.disposeBag)
    }

    func discardButtonTapped(withItem item: ContactRequestItem) {
        viewModel.discard(withItem: item)
            .subscribe(onError: { [weak self] error in
                self?.log.error("Discard trust request failed")
                }, onCompleted: { [weak self] in
                    self?.log.info("Discard trust request done")
            })
            .disposed(by: self.disposeBag)
    }

    func banButtonTapped(withItem item: ContactRequestItem) {
        viewModel.ban(withItem: item)
            .subscribe(onError: { [weak self] error in
                self?.log.error("Ban trust request failed")
                }, onCompleted: { [weak self] in
                    self?.log.info("Ban trust request done")
            })
            .disposed(by: self.disposeBag)
    }
}
