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

import UIKit
import RxSwift
import RxDataSources
import RxCocoa
import Reusable
import SwiftyBeaver

class ContactPickerViewController: UIViewController, StoryboardBased, ViewModelBased, UITableViewDelegate, UIGestureRecognizerDelegate {

    private let log = SwiftyBeaver.self
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    var viewModel: ContactPickerViewModel!
    fileprivate let disposeBag = DisposeBag()

    var blurEffect: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupDataSources()
        self.setupTableViews()
        self.setupSearchBar()
        let dismissGR = UISwipeGestureRecognizer(target: self, action: #selector(remove(gesture:)))
        dismissGR.direction = UISwipeGestureRecognizer.Direction.down
        dismissGR.delegate = self
        self.searchBar.addGestureRecognizer(dismissGR)
        self.setUPBlurBackground()
    }

    func setUPBlurBackground() {
        if #available(iOS 13.0, *) {
            blurEffect =  UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        } else {
            blurEffect =  UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        }
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

    @objc func remove(gesture: UISwipeGestureRecognizer) {
        if gesture.direction != UISwipeGestureRecognizer.Direction.down { return }
        self.removeView()
    }

    func removeView() {
        let initialFrame = CGRect(x: 0, y: self.view.frame.size.height * 2, width: self.view.frame.size.width, height: self.view.frame.size.height * 0.7)
        UIView.animate(withDuration: 0.2, animations: { [unowned self] in
            self.view.frame = initialFrame
            self.view.layoutIfNeeded()
            }, completion: { [weak self] _ in
                if let parent = self?.parent as? CallViewController {
                    parent.addTapGesture()
                    self?.didMove(toParent: nil)
                }
                self?.view.removeFromSuperview()
                self?.removeFromParent()
        })

    }

    func setupDataSources() {
        let configureCell: (TableViewSectionedDataSource, UITableView, IndexPath, ContactPickerSection.Item)
            -> UITableViewCell = {
                (   dataSource: TableViewSectionedDataSource<ContactPickerSection>,
                tableView: UITableView,
                indexPath: IndexPath,
                contactItem: ContactPickerSection.Item) in

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ConversationCell.self)
                if contactItem.contacts.count < 1 {
                    return cell
                }
                cell.newMessagesIndicator.isHidden = true
                cell.newMessagesLabel.isHidden = true
                cell.lastMessageDateLabel.isHidden = true
                cell.presenceIndicator.isHidden = true
                if contactItem.contacts.count > 1 {
                    cell.avatarView.isHidden = true
                    var name = ""
                    contactItem.contacts.forEach { contact in
                        var mutableContact = contact
                        name += mutableContact.firstLine
                        if contactItem.contacts.last! == contact {
                            return
                        }
                        name += " ,"
                    }
                    cell.nameLabel.text = name
                    return cell
                }

                var contact = contactItem.contacts.first!
                cell.nameLabel.text = contact.firstLine
                cell.lastMessagePreviewLabel.text = contact.secondLine

                var imageData: Data?
                if let contactProfile = contact.profile, let photo = contactProfile.photo,
                    let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    imageData = data
                }
                cell.avatarView
                    .addSubview(
                        AvatarView(profileImageData: imageData,
                                   username: contact.firstLine, size: 40))
                guard let status = contact.presenceStatus else {
                    return cell
                }
                status
                    .asObservable()
                    .observeOn(MainScheduler.instance)
                    .startWith(status.value)
                    .subscribe(onNext: { precence in
                        cell.presenceIndicator.isHidden = !precence
                    })
                    .disposed(by: cell.disposeBag)
                return cell
        }
        let contactDataSource = RxTableViewSectionedReloadDataSource<ContactPickerSection>(configureCell: configureCell)
        self.viewModel.searchResultItems
            .bind(to: self.tableView.rx.items(dataSource: contactDataSource))
            .disposed(by: disposeBag)
        contactDataSource.titleForHeaderInSection = { dataSource, index in
            return dataSource.sectionModels[index].header
        }
    }

    func setupTableViews() {
        self.tableView.rowHeight = 64.0
        self.tableView.delegate = self
        self.tableView.register(cellType: ConversationCell.self)
        self.tableView.rx.itemSelected.subscribe(onNext: { [unowned self] indexPath in
            if let contactToAdd: ConferencableItem = try? self.tableView.rx.model(at: indexPath) {
                self.viewModel.addContactToConference(contact: contactToAdd)
                self.removeView()
            }
        }).disposed(by: disposeBag)
    }

    func setupSearchBar() {
        self.searchBar.returnKeyType = .done
        self.searchBar.autocapitalizationType = .none
        self.searchBar.tintColor = UIColor.jamiMain
        self.searchBar.barTintColor = UIColor.jamiBackgroundSecondaryColor
        self.searchBar.rx.text.orEmpty
            .throttle(0.5, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: self.viewModel.search)
            .disposed(by: disposeBag)
        self.searchBar.rx.searchButtonClicked.subscribe(onNext: { [unowned self] in
            self.searchBar.resignFirstResponder()
        }).disposed(by: disposeBag)
    }
}
