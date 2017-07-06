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

class ConversationViewController: UIViewController, UITextFieldDelegate {

    let disposeBag = DisposeBag()

    var viewModel: ConversationViewModel?
    var textFieldShouldEndEditing = false
    var bottomOffset: CGFloat = 0

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var spinnerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupUI()
        self.setupTableView()
        self.setupBindings()

        self.messageAccessoryView.messageTextField.delegate = self

        /*
         Register to keyboard notifications to adjust tableView insets when the keybaord appears
         or disappears
         */
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(withNotification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    func keyboardWillShow(withNotification notification: Notification) {

        let userInfo: Dictionary = notification.userInfo!
        guard let keyboardFrame: NSValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height

        self.tableView.contentInset.bottom = keyboardHeight
        self.tableView.scrollIndicatorInsets.bottom = keyboardHeight

        self.scrollToBottom(animated: true)
        self.updateBottomOffset()
    }

    func keyboardWillHide(withNotification notification: Notification) {
        self.tableView.contentInset.bottom = 0
        self.tableView.scrollIndicatorInsets.bottom = 0
        self.updateBottomOffset()
    }

    func setupUI() {
        self.viewModel?.userName.asObservable().bind(to: self.navigationItem.rx.title).disposed(by: disposeBag)

        self.tableView.contentInset.bottom = messageAccessoryView.frame.size.height
        self.tableView.scrollIndicatorInsets.bottom = messageAccessoryView.frame.size.height
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.scrollToBottom(animated: false)
        self.messagesLoadingFinished()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.textFieldShouldEndEditing = true
        self.viewModel?.setMessagesAsRead()
    }

    func setupTableView() {
        self.tableView.estimatedRowHeight = 50
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.separatorStyle = .none

        //Register cell
        self.tableView.register(UINib.init(nibName: "MessageCell", bundle: nil),
                                forCellReuseIdentifier: "MessageCellId")

        //Bind the TableView to the ViewModel
        self.viewModel?.messages
            .bind(to: tableView.rx.items(cellIdentifier: "MessageCellId",
                                         cellType: MessageCell.self)) { _, messageViewModel, cell in
                cell.messageLabel.text = messageViewModel.content
                cell.bubblePosition = messageViewModel.bubblePosition()
        }.disposed(by: disposeBag)

        //Scroll to bottom when reloaded
        self.tableView.rx.methodInvoked(#selector(UITableView.reloadData)).subscribe(onNext: { _ in
            self.scrollToBottomIfNeed()
            self.updateBottomOffset()
        }).disposed(by: disposeBag)
    }

    fileprivate func updateBottomOffset() {
        self.bottomOffset = self.tableView.contentSize.height
            - ( self.tableView.frame.size.height
                - self.tableView.contentInset.top
                - self.tableView.contentInset.bottom )
    }

    fileprivate func messagesLoadingFinished() {
        self.spinnerView.isHidden = true
    }

    fileprivate func scrollToBottomIfNeed() {
        if self.isBottomContentOffset {
            self.scrollToBottom(animated: true)
        }
    }

    fileprivate func scrollToBottom(animated: Bool) {
        let numberOfRows = self.tableView.numberOfRows(inSection: 0)
        if  numberOfRows > 0 {
            let last = IndexPath(row: numberOfRows - 1, section: 0)
            self.tableView.scrollToRow(at: last, at: .bottom, animated: animated)
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
        self.messageAccessoryView.messageTextField.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: { _ in
            self.viewModel?.sendMessage(withContent: self.messageAccessoryView.messageTextField.text!)
            self.messageAccessoryView.messageTextField.text = ""
        }).disposed(by: disposeBag)
    }

    // Avoid the keyboard to be hidden when the Send button is touched
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return textFieldShouldEndEditing
    }

}
