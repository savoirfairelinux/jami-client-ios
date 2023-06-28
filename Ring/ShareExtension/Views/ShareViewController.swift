/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import RxSwift
import RxDataSources
import RxCocoa
import Reusable
import SwiftyBeaver

@objc(ShareExtensionViewController)
class ShareViewController: UIViewController, StoryboardBased, UITableViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var topViewContainer: UIView!
    @IBOutlet weak var topSpace: NSLayoutConstraint!

    private let log = SwiftyBeaver.self
    var viewModel: ShareViewModel!
    private let disposeBag = DisposeBag()
    var rowSelectionHandler: ((_ row: IndexPath) -> Void)?

    var blurEffect: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel = ShareViewModel()
        self.setupDataSources()
        self.setupSearchBar()
        self.setUPBlurBackground()
        self.updateViewForCurrentMode()
        self.setupTableViews()

        viewModel.contactSelectedCB = { [weak self] swarms in
            self?.handleSharedFile(swarms: swarms)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.viewModel.stopDaemon()
    }

    private func handleSharedFile(swarms: [ShareSwarmInfo]) {
        // extracting the path to the URL that is being shared
        let attachments = (self.extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []
        let types: [String] = [UTType.item.identifier, UTType.audio.identifier, UTType.movie.identifier, UTType.url.identifier, UTType.data.identifier]
        for provider in attachments {
            var isMessageSent = false
            for type in types {
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadItem(forTypeIdentifier: type, options: nil) { [unowned self] (data, error) in
                        guard error == nil, let url = data as? URL, !isMessageSent else { return }

                        var messageModel: ShareMessageModel = ShareMessageModel(withId: "", content: "", receivedDate: Date())
                        if type == kUTTypeURL as String {
                            print("**** url => \(url)")
                            messageModel.content = url.absoluteString
                        } else {
                            messageModel.url = url
                        }

                        // Set the flag here to avoid resending
                        isMessageSent = true
                        print("**** \(type)")
                        viewModel.shareMessage(message: messageModel, with: swarms)
                    }

                    // If message sent, break the loop
                    if isMessageSent {
                        break
                    }
                }
            }
        }
    }

    private func setUPBlurBackground() {
        blurEffect = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        if blurEffect != nil {
            blurEffect!.frame = self.view.bounds
            self.view.insertSubview(blurEffect!, at: 0)
            blurEffect!.topAnchor.constraint(equalTo: searchBar.topAnchor, constant: 0).isActive = true
            blurEffect!.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
            blurEffect!.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0).isActive = true
            blurEffect!.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 0).isActive = true
            blurEffect!.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    @objc
    private func remove(gesture: UISwipeGestureRecognizer) {
        if gesture.direction != UISwipeGestureRecognizer.Direction.down { return }
        self.removeView()
    }

    func removeView() {
        let initialFrame = CGRect(x: 0, y: self.view.frame.size.height * 2, width: self.view.frame.size.width, height: self.view.frame.size.height * 0.7)
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self = self else { return }
            self.view.frame = initialFrame
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            //            if let parent = self?.parent as? ContactPickerDelegate {
            //                parent.contactPickerDismissed()
            //            }
            self?.didMove(toParent: nil)
            self?.view.removeFromSuperview()
            self?.removeFromParent()
        })
    }

    private func setupDataSources() {
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, ShareContactPickerSection.Item) -> UITableViewCell = {
            (   _: TableViewSectionedDataSource<ShareContactPickerSection>,
                tableView: UITableView,
                indexPath: IndexPath,
                contactItem: ShareContactPickerSection.Item) in

            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ConversationTableViewCell.self)
            cell.selectionContainer?.isHidden = false
            cell.selectionIndicator?.backgroundColor = UIColor.clear
            cell.selectionIndicator?.layer.borderColor = UIColor.jamiTextBlue.cgColor
            if contactItem.participants.value.count < 1 {
                return cell
            }
            cell.avatarView.isHidden = false
            contactItem.finalAvatar.share()
                .observe(on: MainScheduler.instance)
                .subscribe { [weak self] image in
                    self?.updateCell(cell: cell, avatarImage: image, name: nil, username: contactItem.title.value)
                } onError: { _ in
                }
                .disposed(by: self.disposeBag)
            contactItem.finalTitle.share()
                .observe(on: MainScheduler.instance)
                .subscribe { [weak self] name in
                    self?.updateCell(cell: cell, avatarImage: nil, name: name, username: contactItem.title.value)
                } onError: { _ in
                }
                .disposed(by: self.disposeBag)
            return cell
        }
        let contactDataSource = RxTableViewSectionedReloadDataSource<ShareContactPickerSection>(
            configureCell: configureCell,
            titleForHeaderInSection: { dataSource, sectionIndex in
                return dataSource[sectionIndex].header
            }
        )
        self.viewModel.searchResultItems
            .bind(to: self.tableView.rx.items(dataSource: contactDataSource))
            .disposed(by: disposeBag)
    }

    private func setupTableViews() {
        self.tableView.rowHeight = 64.0
        self.tableView.delegate = self
        self.tableView.register(cellType: ConversationTableViewCell.self)
        self.tableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                guard let self = self,
                      let rowSelectionHandler = self.rowSelectionHandler else { return }
                rowSelectionHandler(indexPath)
            })
            .disposed(by: disposeBag)
    }

    private func setupSearchBar() {
        self.searchBar.returnKeyType = .done
        self.searchBar.autocapitalizationType = .none
        self.searchBar.tintColor = UIColor.jamiMain
        self.searchBar.placeholder = L10n.Smartlist.searchBarPlaceholder
        self.searchBar.rx.text.orEmpty
            .throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: self.viewModel.search)
            .disposed(by: disposeBag)
        self.searchBar.rx.searchButtonClicked
            .subscribe(onNext: { [weak self] in
                self?.searchBar.resignFirstResponder()
            })
            .disposed(by: disposeBag)
    }

    private func updateButtonsOnSelectionChange(cell: ConversationTableViewCell, indexPath: IndexPath) {
        if cell.selectionIndicator?.backgroundColor == UIColor.jamiTextBlue {
            cell.selectionIndicator?.backgroundColor = UIColor.clear
            self.tableView.deselectRow(at: indexPath, animated: false)
        } else {
            cell.selectionIndicator?.backgroundColor = UIColor.jamiTextBlue
        }
        let title = self.tableView.indexPathsForSelectedRows?.isEmpty ?? true ? L10n.Global.cancel : L10n.DataTransfer.sendMessage
        self.doneButton.setTitle(title, for: .normal)
    }

    private func updateViewForCurrentMode() {
        self.topViewContainer.isHidden = false
        self.tableView.allowsMultipleSelection = true
        self.searchBar.backgroundImage = UIImage()
        self.searchBar.backgroundColor = UIColor.clear
        self.doneButton.setTitle(L10n.Global.cancel, for: .normal)
        self.doneButton.setTitleColor(UIColor.jamiTextBlue, for: .normal)
        topSpace.constant = 50
        self.doneButton.rx.tap
            .subscribe(onNext: { [weak self] in
                let paths = self?.tableView.indexPathsForSelectedRows
                var contacts = [ShareSwarmInfo]()
                paths?.forEach({ (path) in
                    guard let self = self else { return }
                    if let contactToAdd: ShareSwarmInfo = try? self.tableView.rx.model(at: path) {
                        contacts.append(contactToAdd)
                    }
                })
                if !contacts.isEmpty {
                    self?.viewModel.contactSelected(contacts: contacts)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            })
            .disposed(by: self.disposeBag)
        self.rowSelectionHandler = { [weak self] row in
            guard let cell = self?.tableView.cellForRow(at: row) as? ConversationTableViewCell else { return }
            self?.updateButtonsOnSelectionChange(cell: cell, indexPath: row)
        }
    }

    func updateCell(cell: ConversationTableViewCell?, avatarImage: UIImage?, name: String?, username: String) {
        guard let cell = cell else { return }
        if let name {
            cell.nameLabel.text = name
        }
        if let avatarImage,
           !cell.avatarView.subviews.contains(where: { $0 is AvatarView }) {
            cell.avatarView
                .addSubview(
                    AvatarView(profileImageData: avatarImage.pngData(),
                               username: username, size: 40))
        }
    }
}
