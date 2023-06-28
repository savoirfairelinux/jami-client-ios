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
        self.viewModel = ShareViewModel()
        self.setupDataSources()
        self.setupSearchBar()
        self.setUPBlurBackground()
        self.updateViewForCurrentMode()
        self.setupTableViews()
        self.handleSharedFile()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.viewModel.stopDaemon()
    }

    private func handleSharedFile() {
        // extracting the path to the URL that is being shared
        let attachments = (self.extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []
        let types: [String] = [UTType.data.identifier, UTType.audio.identifier, UTType.movie.identifier, UTType.item.identifier, UTType.url.identifier]
        for provider in attachments {
            for type in types {
                // Check if the content type is the same as we expected
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadItem(forTypeIdentifier: type, options: nil) { [unowned self] (data, error) in
                        // Handle the error here if you want
                        guard error == nil else { return }

                        if let url = data as? URL,
                           let fileData = try? Data(contentsOf: url) {
                            // Use a switch statement to handle each type of file differently
                            switch type {
                            case UTType.data.identifier:
                                print("Received data file with size \(fileData.count) bytes")
                            // Handle data file here
                            case UTType.audio.identifier:
                                print("Received audio file with size \(fileData.count) bytes")
                            // Handle audio file here
                            case UTType.movie.identifier:
                                print("Received video file with size \(fileData.count) bytes")
                            // Handle video file here
                            case UTType.item.identifier:
                                print("Received generic file with size \(fileData.count) bytes")
                            // Handle generic file here
                            default:
                                break
                            }
                        } else {
                            // TODO: - Handle URLs
                            // Handle this situation as you prefer
                            print("Impossible to save file")
                        }
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
            if contactItem.contacts.count < 1 {
                return cell
            }
            cell.avatarView.isHidden = contactItem.contacts.count > 1
            let contacts = contactItem.contacts
            contacts.forEach { contact in
                contact.firstLine.asObservable()
                    .startWith(contact.firstLine.value)
                    .observe(on: MainScheduler.instance)
                    .subscribe(onNext: { [weak self, weak cell] _ in
                        self?.updateCell(cell: cell, contacts: contacts)
                    }, onError: { (_) in
                    })
                    .disposed(by: cell.disposeBag)
            }
            return cell
        }
        let contactDataSource = RxTableViewSectionedReloadDataSource<ShareContactPickerSection>(configureCell: configureCell)
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
                var contacts = [ShareConferencableItem]()
                paths?.forEach({ (path) in
                    guard let self = self else { return }
                    if let contactToAdd: ShareConferencableItem = try? self.tableView.rx.model(at: path) {
                        contacts.append(contactToAdd)
                    }
                })
                self?.viewModel.contactSelected(contacts: contacts)
                self?.removeView()
            })
            .disposed(by: self.disposeBag)
        self.rowSelectionHandler = { [weak self] row in
            guard let cell = self?.tableView.cellForRow(at: row) as? ConversationTableViewCell else { return }
            self?.updateButtonsOnSelectionChange(cell: cell, indexPath: row)
        }
    }

    func updateCell(cell: ConversationTableViewCell?, contacts: [ShareContact]) {
        guard let cell = cell else { return }
        if contacts.count > 1 {
            var name = ""
            contacts.forEach { contact in
                name += contact.firstLine.value
                if contacts.last! == contact {
                    return
                }
                name += " ,"
            }
            cell.nameLabel.text = name
            return
        }

        guard let contact = contacts.first else { return }
        cell.nameLabel.text = contact.firstLine.value

        var imageData: Data?
        if let contactProfile = contact.profile, let photo = contactProfile.photo,
           let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
            imageData = data
        }
        cell.avatarView
            .addSubview(
                AvatarView(profileImageData: imageData,
                           username: contact.firstLine.value, size: 40))
    }
}
