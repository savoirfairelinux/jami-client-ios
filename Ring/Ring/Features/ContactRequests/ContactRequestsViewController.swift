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

import Reusable
import RxCocoa
import RxSwift
import SwiftyBeaver
import UIKit

class ContactRequestsViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: ContactRequestsViewModel!

    @IBOutlet var tableView: UITableView!
    @IBOutlet var noInvitationsPlaceholder: UIView!
    @IBOutlet var noRequestsLabel: UILabel!

    private let disposeBag = DisposeBag()
    private let cellIdentifier = "ContactRequestCell"
    private let log = SwiftyBeaver.self

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.jamiBackgroundColor
        tableView.backgroundColor = UIColor.jamiBackgroundColor
        noInvitationsPlaceholder.backgroundColor = UIColor.jamiBackgroundColor
        noRequestsLabel.backgroundColor = UIColor.jamiBackgroundColor
        noRequestsLabel.textColor = UIColor.jamiLabelColor
        configureNavigationBar()
        tableView.rx.modelSelected(RequestItem.self)
            .subscribe { [weak self] item in
                guard let self = self else { return }
                if let request = item.element {
                    self.viewModel.showConversation(forItem: request)
                }
            }
            .disposed(by: disposeBag)
        applyL10n()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupTableView()
        setupBindings()
    }

    func applyL10n() {
        noRequestsLabel.text = L10n.Invitations.noInvitations
    }

    func setupTableView() {
        tableView.estimatedRowHeight = 100.0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = true
        tableView.tableFooterView = UIView()

        // Register cell
        tableView.register(cellType: ContactRequestCell.self)

        // Set delegate to remove unsynced contact request
        tableView.rx.setDelegate(self).disposed(by: disposeBag)
        // Bind the TableView to the ViewModel
        viewModel
            .contactRequestItems
            .observe(on: MainScheduler.instance)
            .bind(to: tableView.rx.items(
                cellIdentifier: cellIdentifier,
                cellType: ContactRequestCell.self
            )) { [weak self] _, item, cell in
                cell.configureFromItem(item)

                // Accept button
                cell.acceptButton.backgroundColor = UIColor.clear
                cell.acceptButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.acceptButtonTapped(withItem: item)
                    })
                    .disposed(by: cell.disposeBag)

                // Discard button
                cell.discardButton.backgroundColor = UIColor.clear
                cell.discardButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.discardButtonTapped(withItem: item)
                    })
                    .disposed(by: cell.disposeBag)

                // Ban button
                cell.banButton.backgroundColor = UIColor.clear
                cell.banButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.banButtonTapped(withItem: item)
                    })
                    .disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func setupBindings() {
        viewModel
            .hasInvitations
            .observe(on: MainScheduler.instance)
            .bind(to: noInvitationsPlaceholder.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel
            .hasInvitations
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] hasInvitation in
                if !hasInvitation {
                    self?.view.isHidden = true
                }
            })
            .disposed(by: disposeBag)
    }

    func acceptButtonTapped(withItem item: RequestItem) {
        viewModel.accept(withItem: item)
            .subscribe(onError: { [weak self] _ in
                self?.log.error("Accept trust request failed")
            }, onCompleted: { [weak self] in
                self?.log.info("Accept trust request done")
            })
            .disposed(by: disposeBag)
    }

    func discardButtonTapped(withItem item: RequestItem) {
        viewModel.discard(withItem: item)
            .subscribe(onError: { [weak self] _ in
                self?.log.error("Discard trust request failed")
            }, onCompleted: { [weak self] in
                self?.log.info("Discard trust request done")
            })
            .disposed(by: disposeBag)
    }

    func banButtonTapped(withItem item: RequestItem) {
        viewModel.ban(withItem: item)
            .subscribe(onError: { [weak self] _ in
                self?.log.error("Ban trust request failed")
            }, onCompleted: { [weak self] in
                self?.log.info("Ban trust request done")
            })
            .disposed(by: disposeBag)
    }

    private func removeContactFromInvitationList(atIndex: IndexPath) {
        let alert = UIAlertController(
            title: L10n.Alerts.confirmDeleteConversationTitle,
            message: L10n.Alerts.confirmDeleteConversation,
            preferredStyle: .alert
        )
        let deleteAction = UIAlertAction(title: L10n.Actions.deleteAction,
                                         style: .destructive) { [weak self] (_: UIAlertAction!) in
            guard let self = self else { return }
            if let reqToDelete: RequestItem = try? self.tableView.rx.model(at: atIndex) {
                self.viewModel.deleteRequest(item: reqToDelete)
                self.tableView.reloadData()
            }
        }
        let cancelAction = UIAlertAction(title: L10n.Global.cancel,
                                         style: .default) { (_: UIAlertAction!) in }
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

extension ContactRequestsViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        if let cell = tableView.cellForRow(at: indexPath) as? ContactRequestCell {
            if cell.deletable {
                let delete = UIContextualAction(style: .normal,
                                                title: "Delete") { [weak self] _, _, _ in
                    guard let self = self else { return }
                    self.removeContactFromInvitationList(atIndex: indexPath)
                }
                delete.backgroundColor = .red
                let swipeActions = UISwipeActionsConfiguration(actions: [delete])
                return swipeActions
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}
