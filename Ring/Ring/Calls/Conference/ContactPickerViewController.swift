/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import Reusable
import RxCocoa
import RxDataSources
import RxSwift
import SwiftyBeaver
import UIKit

enum ContactPickerType {
    case forConversation
    case forCall
}

protocol ContactPickerViewControllerDelegate: AnyObject {
    func contactPickerDismissed()
}

class ContactPickerViewController: UIViewController, StoryboardBased, ViewModelBased,
                                   UITableViewDelegate, UIGestureRecognizerDelegate {
    private let log = SwiftyBeaver.self
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var topViewContainer: UIView!
    @IBOutlet var topSpace: NSLayoutConstraint!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!

    var viewModel: ContactPickerViewModel!
    private let disposeBag = DisposeBag()
    var type: ContactPickerType = .forConversation
    var rowSelectionHandler: ((_ row: IndexPath) -> Void)?

    var blurEffect: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSources()
        setupSearchBar()
        setUPBlurBackground()
        updateViewForCurrentMode()
        setupTableViews()
        viewModel
            .loading
            .observe(on: MainScheduler.instance)
            .bind(to: loadingIndicator.rx.isAnimating)
            .disposed(by: disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setUPBlurBackground() {
        blurEffect = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        if blurEffect != nil {
            blurEffect!.frame = view.bounds
            view.insertSubview(blurEffect!, at: 0)
            blurEffect!.topAnchor.constraint(equalTo: searchBar.topAnchor, constant: 0)
                .isActive = true
            blurEffect!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
                .isActive = true
            blurEffect!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
                .isActive = true
            blurEffect!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0)
                .isActive = true
            blurEffect!.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    @objc
    private func remove(gesture: UISwipeGestureRecognizer) {
        if gesture.direction != UISwipeGestureRecognizer.Direction.down { return }
        removeView()
    }

    func removeView() {
        let initialFrame = CGRect(
            x: 0,
            y: view.frame.size.height * 2,
            width: view.frame.size.width,
            height: view.frame.size.height * 0.7
        )
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self = self else { return }
            self.view.frame = initialFrame
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            self.didMove(toParent: nil)
            self.view.removeFromSuperview()
            if let parent = self.parent as? ContactPickerViewControllerDelegate {
                parent.contactPickerDismissed()
            }
            self.removeFromParent()
        })
    }

    private func setupDataSources() {
        switch type {
        case .forCall:
            let configureCell: (
                TableViewSectionedDataSource,
                UITableView,
                IndexPath,
                ContactPickerSection.Item
            )
            -> UITableViewCell = { [weak self]
                (_: TableViewSectionedDataSource<ContactPickerSection>,
                 tableView: UITableView,
                 indexPath: IndexPath,
                 item: ContactPickerSection.Item) in

                let cell = tableView.dequeueReusableCell(
                    for: indexPath,
                    cellType: SmartListCell.self
                )
                guard let self = self else { return cell }
                self.configureContactCell(cell: cell, contactItem: item)
                return cell
            }
            let contactDataSource =
                RxTableViewSectionedReloadDataSource<ContactPickerSection>(
                    configureCell: configureCell
                )
            viewModel.searchResultItems
                .bind(to: tableView.rx.items(dataSource: contactDataSource))
                .disposed(by: disposeBag)
            contactDataSource.titleForHeaderInSection = { dataSource, index in
                dataSource.sectionModels[index].header
            }
        case .forConversation:
            let configureCell: (
                TableViewSectionedDataSource,
                UITableView,
                IndexPath,
                ConversationPickerSection.Item
            )
            -> UITableViewCell = { [weak self]
                (_: TableViewSectionedDataSource<ConversationPickerSection>,
                 tableView: UITableView,
                 indexPath: IndexPath,
                 conversationItem: ConversationPickerSection.Item) in

                let cell = tableView.dequeueReusableCell(
                    for: indexPath,
                    cellType: SmartListCell.self
                )
                guard let self = self else { return cell }
                self.configureConversationCell(cell: cell, info: conversationItem)
                return cell
            }
            let conversationsDataSource =
                RxTableViewSectionedReloadDataSource<ConversationPickerSection>(
                    configureCell: configureCell
                )
            viewModel.conversationsSearchResultItems
                .bind(to: tableView.rx.items(dataSource: conversationsDataSource))
                .disposed(by: disposeBag)
        }
    }

    private func setupTableViews() {
        tableView.rowHeight = 64.0
        tableView.delegate = self
        tableView.register(cellType: SmartListCell.self)
        tableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                guard let self = self,
                      let rowSelectionHandler = self.rowSelectionHandler else { return }
                rowSelectionHandler(indexPath)
            })
            .disposed(by: disposeBag)
    }

    private func setupSearchBar() {
        searchBar.returnKeyType = .done
        searchBar.autocapitalizationType = .none
        searchBar.tintColor = UIColor.jamiMain
        searchBar.placeholder = L10n.Smartlist.searchBarPlaceholder
        searchBar.rx.text.orEmpty
            .throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: viewModel.search)
            .disposed(by: disposeBag)
        searchBar.rx.searchButtonClicked
            .subscribe(onNext: { [weak self] in
                self?.searchBar.resignFirstResponder()
            })
            .disposed(by: disposeBag)
    }

    private func updateButtonsOnSelectionChange(cell: SmartListCell, indexPath: IndexPath) {
        if cell.selectionIndicator?.backgroundColor == UIColor.jamiTextBlue {
            cell.selectionIndicator?.backgroundColor = UIColor.clear
            tableView.deselectRow(at: indexPath, animated: false)
        } else {
            cell.selectionIndicator?.backgroundColor = UIColor.jamiTextBlue
        }
        let title = tableView.indexPathsForSelectedRows?.isEmpty ?? true ? L10n.Global.cancel : L10n
            .DataTransfer.sendMessage
        doneButton.setTitle(title, for: .normal)
    }

    private func updateViewForCurrentMode() {
        topViewContainer.isHidden = type == .forCall
        tableView.allowsMultipleSelection = type == .forConversation
        switch type {
        case .forCall:
            searchBar.barTintColor = UIColor.jamiBackgroundSecondaryColor
            let dismissGR = UISwipeGestureRecognizer(
                target: self,
                action: #selector(remove(gesture:))
            )
            dismissGR.direction = UISwipeGestureRecognizer.Direction.down
            dismissGR.delegate = self
            topSpace.constant = 0
            searchBar.addGestureRecognizer(dismissGR)
            rowSelectionHandler = { [weak self] row in
                guard let self = self else { return }
                guard let contactToAdd: ConferencableItem = try? self.tableView.rx.model(at: row)
                else { return }
                self.viewModel.contactSelected(contacts: [contactToAdd])
                self.removeView()
            }
        case .forConversation:
            searchBar.backgroundImage = UIImage()
            searchBar.backgroundColor = UIColor.clear
            doneButton.setTitle(L10n.Global.cancel, for: .normal)
            doneButton.setTitleColor(UIColor.jamiTextBlue, for: .normal)
            topSpace.constant = 50
            doneButton.rx.tap
                .subscribe(onNext: { [weak self] in
                    let paths = self?.tableView.indexPathsForSelectedRows
                    var conversationIds = [String]()
                    paths?.forEach { path in
                        guard let self = self else { return }
                        if let conversationToAdd: SwarmInfo = try? self.tableView.rx
                            .model(at: path) {
                            conversationIds.append(conversationToAdd.id)
                        }
                    }
                    self?.viewModel.conversationSelected(conversaionIds: conversationIds)
                    self?.removeView()
                })
                .disposed(by: disposeBag)
            rowSelectionHandler = { [weak self] row in
                guard let cell = self?.tableView.cellForRow(at: row) as? SmartListCell
                else { return }
                self?.updateButtonsOnSelectionChange(cell: cell, indexPath: row)
            }
        }
    }

    func configureContactCell(cell: SmartListCell, contactItem:
                                ConferencableItem) {
        cell.selectionContainer?.isHidden = type == .forCall
        cell.selectionIndicator?.backgroundColor = UIColor.clear
        cell.selectionIndicator?.borderColor = UIColor.jamiTextBlue
        if contactItem.contacts.count < 1 {
            return
        }
        cell.newMessagesIndicator?.isHidden = true
        cell.newMessagesLabel?.isHidden = true
        cell.lastMessageDateLabel?.isHidden = true
        cell.presenceIndicator?.isHidden = true
        cell.avatarView.isHidden = contactItem.contacts.count > 1
        let contacts = contactItem.contacts
        for contact in contacts {
            contact.firstLine.asObservable()
                .startWith(contact.firstLine.value)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self, weak cell] _ in
                    self?.updateCell(cell: cell, contacts: contacts)
                }, onError: { _ in
                })
                .disposed(by: cell.disposeBag)
        }
        if contacts.count == 1, let contact = contacts.first {
            guard let status = contact.presenceStatus else {
                return
            }
            status
                .asObservable()
                .observe(on: MainScheduler.instance)
                .startWith(status.value)
                .subscribe(onNext: { presenceStatus in
                    cell.presenceIndicator?.isHidden = presenceStatus == .offline
                    if presenceStatus == .connected {
                        cell.presenceIndicator?.backgroundColor = .onlinePresenceColor
                    } else if presenceStatus == .available {
                        cell.presenceIndicator?.backgroundColor = .availablePresenceColor
                    }
                })
                .disposed(by: cell.disposeBag)
        }
    }

    func configureConversationCell(cell: SmartListCell, info:
                                    SwarmInfo) {
        cell.selectionContainer?.isHidden = false
        cell.selectionIndicator?.backgroundColor = UIColor.clear
        cell.selectionIndicator?.borderColor = UIColor.jamiTextBlue
        cell.newMessagesIndicator?.isHidden = true
        cell.newMessagesLabel?.isHidden = true
        cell.lastMessageDateLabel?.isHidden = true
        cell.presenceIndicator?.isHidden = true
        info.finalAvatar
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak cell] avatar in
                guard let cell = cell else { return }
                cell.avatarView
                    .addSubview(
                        AvatarView(image: avatar, size: 40)
                    )
            })
            .disposed(by: disposeBag)
        info.finalTitle
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak cell] title in
                guard let cell = cell else { return }
                cell.nameLabel.text = title
            })
            .disposed(by: disposeBag)
        cell.lastMessagePreviewLabel?.isHidden = true
    }

    func updateCell(cell: SmartListCell?, contacts: [Contact]) {
        guard let cell = cell else { return }
        if contacts.count > 1 {
            var name = ""
            for contact in contacts {
                name += contact.firstLine.value
                if contacts.last! == contact {
                    continue
                }
                name += " ,"
            }
            cell.nameLabel.text = name
            return
        }

        guard let contact = contacts.first else { return }
        cell.nameLabel.text = contact.firstLine.value
        cell.lastMessagePreviewLabel?.isHidden = true

        contact.imageData
            .asObservable()
            .subscribe(onNext: { [weak cell] imageData in
                cell?.avatarView
                    .addSubview(
                        AvatarView(profileImageData: imageData,
                                   username: contact.firstLine.value, size: 40)
                    )
            })
            .disposed(by: disposeBag)
    }
}
