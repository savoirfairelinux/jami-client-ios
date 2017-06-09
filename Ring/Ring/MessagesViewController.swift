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

class MessagesViewController: UITableViewController, UITextFieldDelegate {

    let disposeBag = DisposeBag()

    var viewModel: ConversationViewModel?

    var textFieldShouldEndEditing = false

    var bottomOffset :CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupUI()
        self.setupTableView()
        self.setupBindings()

        self.messageAccessoryView.messageTextField.delegate = self
    }

    func setupUI() {
        self.viewModel?.userName.bind(to: self.navigationItem.rx.title).addDisposableTo(disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.messageAccessoryView.messageTextField.becomeFirstResponder()
        self.viewModel?.setMessagesAsRead()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.textFieldShouldEndEditing = true
    }

    func setupTableView() {
        self.tableView.estimatedRowHeight = 50
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.separatorStyle = .none

        //Register cell
        self.tableView.register(UINib.init(nibName: "MessageCell", bundle: nil),
                                forCellReuseIdentifier: "MessageCellId")

        //Bind the TableView to the ViewModel
        self.viewModel?.messages.asObservable()
            .bind(to: tableView.rx.items(cellIdentifier: "MessageCellId", cellType: MessageCell.self))
            { index, messageViewModel, cell in
                cell.messageLabel.text = messageViewModel.content
                cell.bubblePosition = messageViewModel.bubblePosition()
            }.addDisposableTo(disposeBag)

        //Scroll to bottom when reloaded
        self.tableView.rx.methodInvoked(#selector(UITableView.reloadData)).subscribe(onNext: { element in
            self.scrollToBottomIfNeed()

            //Update the bottomOffset of the tableView
            self.bottomOffset = self.tableView.contentSize.height - ( self.tableView.frame.size.height - self.tableView.contentInset.top - self.tableView.contentInset.bottom )
        }).addDisposableTo(disposeBag)
    }

    fileprivate func scrollToBottomIfNeed() {
        if self.isBottomContentOffset {
            let last = IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1, section: 0)

            if last.row >= 0 {
                self.tableView.scrollToRow(at: last, at: .bottom, animated: true)
            }
        }
    }

    fileprivate var isBottomContentOffset: Bool {
        return self.tableView.contentOffset.y + self.tableView.contentInset.top >= bottomOffset
    }

    override var inputAccessoryView: UIView {
        return self.messageAccessoryView
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    lazy var messageAccessoryView: MessageAccessoryView = {
        return MessageAccessoryView.instanceFromNib()
    }()

    func setupBindings() {

        //Binds the keyboard Send button action to the ViewModel
        _ = self.messageAccessoryView.messageTextField.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: { event in
            self.viewModel?.sendMessage(withContent: self.messageAccessoryView.messageTextField.text!)
            self.messageAccessoryView.messageTextField.text = ""
        }).addDisposableTo(disposeBag)
    }

    // Avoid the keyboard to be hidden when the Send button is touched
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return textFieldShouldEndEditing
    }

}
