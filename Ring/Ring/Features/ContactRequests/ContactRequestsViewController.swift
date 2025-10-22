/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
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
        self.configureNavigationBar()
        self.tableView.rx.modelSelected(RequestItem.self)
            .subscribe({ [weak self] item in
                guard let self = self else { return }
                if let request = item.element {
                    self.viewModel.showConversation(forItem: request)
                }
            })
            .disposed(by: disposeBag)
        self.applyL10n()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupTableView()
        self.setupBindings()
    }

    func applyL10n() {
        self.noRequestsLabel.text = L10n.Invitations.noInvitations
    }

    func setupTableView() {
        self.tableView.estimatedRowHeight = 100.0
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.allowsSelection = true
        self.tableView.tableFooterView = UIView()

        // Register cell
        self.tableView.register(cellType: ContactRequestCell.self)

        // Set delegate to remove unsynced contact request
        self.tableView.rx.setDelegate(self).disposed(by: disposeBag)
        // Bind the TableView to the ViewModel
        self.viewModel
            .contactRequestItems
            .observe(on: MainScheduler.instance)
            .bind(to: tableView.rx.items(cellIdentifier: cellIdentifier, cellType: ContactRequestCell.self)) { [weak self] _, item, cell in
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

                // Block button
                cell.blockButton.backgroundColor = UIColor.clear
                cell.blockButton.rx.tap
                    .subscribe(onNext: { [weak self] in
                        self?.blockButtonTapped(withItem: item)
                    })
                    .disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
    }

    func setupBindings() {

        self.viewModel
            .hasInvitations
            .observe(on: MainScheduler.instance)
            .bind(to: self.noInvitationsPlaceholder.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel
            .hasInvitations
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: {[weak self] hasInvitation in
                if !hasInvitation {
                    self?.view.isHidden = true
                }
            })
            .disposed(by: self.disposeBag)
    }

    func acceptButtonTapped(withItem item: RequestItem) {
        viewModel.accept(withItem: item)
            .subscribe(onError: { [weak self] _ in
                self?.log.error("Accept trust request failed")
            }, onCompleted: { [weak self] in
                self?.log.info("Accept trust request done")
            })
            .disposed(by: self.disposeBag)
    }

    func discardButtonTapped(withItem item: RequestItem) {
        viewModel.discard(withItem: item)
            .subscribe(onError: { [weak self] _ in
                self?.log.error("Discard trust request failed")
            }, onCompleted: { [weak self] in
                self?.log.info("Discard trust request done")
            })
            .disposed(by: self.disposeBag)
    }

    func blockButtonTapped(withItem item: RequestItem) {
        viewModel.block(withItem: item)
            .subscribe(onError: { [weak self] _ in
                self?.log.error("Block failed")
            }, onCompleted: { [weak self] in
                self?.log.info("Block done")
            })
            .disposed(by: self.disposeBag)
    }
    private func removeContactFromInvitationList(atIndex: IndexPath) {
        let alert = UIAlertController(title: L10n.Alerts.confirmDeleteConversationTitle, message: L10n.Alerts.confirmDeleteConversation, preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: L10n.Actions.deleteAction, style: .destructive) {[weak self] (_: UIAlertAction!) in
            guard let self = self else { return }
            if let reqToDelete: RequestItem = try? self.tableView.rx.model(at: atIndex) {
                self.viewModel.deleteRequest(item: reqToDelete)
                self.tableView.reloadData()
            }
        }
        let cancelAction = UIAlertAction(title: L10n.Global.cancel, style: .default) { (_: UIAlertAction!) in }
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
}
extension ContactRequestsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let cell = tableView.cellForRow(at: indexPath) as? ContactRequestCell {
            if cell.deletable {
                let delete = UIContextualAction(style: .normal, title: "Delete") { [weak self](_, _, _) in
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
