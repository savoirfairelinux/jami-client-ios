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
import Reusable
import SwiftyBeaver

enum BubbleChaining {
    case singleMessage
    case firstOfSequence
    case lastOfSequence
    case middleOfSequence
    case error
}

class ConversationViewController: UIViewController, UITextFieldDelegate, StoryboardBased, ViewModelBased {

    let log = SwiftyBeaver.self

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var spinnerView: UIView!

    let disposeBag = DisposeBag()

    var viewModel: ConversationViewModel!
    var messageViewModels: [MessageViewModel]?
    var textFieldShouldEndEditing = false
    var bottomOffset: CGFloat = 0
    let scrollOffsetThreshold: CGFloat = 600

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
        self.viewModel.userName.asObservable().bind(to: self.navigationItem.rx.title).disposed(by: disposeBag)

        self.tableView.contentInset.bottom = messageAccessoryView.frame.size.height
        self.tableView.scrollIndicatorInsets.bottom = messageAccessoryView.frame.size.height

        //invite button
        let inviteItem = UIBarButtonItem()
        inviteItem.image = UIImage(named: "add_person")
        inviteItem.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
            self.inviteItemTapped()
        }).disposed(by: self.disposeBag)

        self.navigationItem.rightBarButtonItem = inviteItem

        self.viewModel.inviteButtonIsAvailable.asObservable().bind(to: inviteItem.rx.isEnabled).disposed(by: disposeBag)
    }

    func inviteItemTapped() {
       self.viewModel?.sendContactRequest()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.scrollToBottom(animated: false)
        self.messagesLoadingFinished()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.textFieldShouldEndEditing = true
        self.viewModel.setMessagesAsRead()
    }

    func setupTableView() {
        self.tableView.dataSource = self

        self.tableView.estimatedRowHeight = 50
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.separatorStyle = .none

        //Register cell
        self.tableView.register(cellType: MessageCellSent.self)
        self.tableView.register(cellType: MessageCellReceived.self)
        self.tableView.register(cellType: MessageCellGenerated.self)

        //Bind the TableView to the ViewModel
        self.viewModel.messages.subscribe(onNext: { [weak self] (messageViewModels) in
            self?.messageViewModels = messageViewModels
            self?.tableView.reloadData()
        }).disposed(by: self.disposeBag)

        //Scroll to bottom when reloaded
        self.tableView.rx.methodInvoked(#selector(UITableView.reloadData)).subscribe(onNext: { [unowned self] _ in
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
            self.scrollToBottom(animated: false)
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
        updateBottomOffset()
        let offset = abs((self.tableView.contentOffset.y + self.tableView.contentInset.top) - bottomOffset)
        return offset <= scrollOffsetThreshold
    }

    override var inputAccessoryView: UIView {
        return self.messageAccessoryView
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    lazy var messageAccessoryView: MessageAccessoryView = {
        return MessageAccessoryView.loadFromNib()
    }()

    func setupBindings() {

        //Binds the keyboard Send button action to the ViewModel
        self.messageAccessoryView.messageTextField.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: { [unowned self] _ in
            self.viewModel.sendMessage(withContent: self.messageAccessoryView.messageTextField.text!)
            self.messageAccessoryView.messageTextField.text = ""
        }).disposed(by: disposeBag)
    }

    // Avoid the keyboard to be hidden when the Send button is touched
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return textFieldShouldEndEditing
    }

    func isFirstMessage(cellForRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row == 0
    }

    func isLastMessage(cellForRowAt indexPath: IndexPath) -> Bool {
        return self.messageViewModels?.count == indexPath.row + 1
    }

    func getBubbleChaining(cellForRowAt indexPath: IndexPath) -> BubbleChaining {
        if let msgViewModel = self.messageViewModels?[indexPath.row] {
            let msgOwner = msgViewModel.bubblePosition()
            if self.messageViewModels?.count == 1 || indexPath.row == 0 {
                if self.messageViewModels?.count == indexPath.row + 1 {
                    return BubbleChaining.singleMessage
                }
                let nextMsgViewModel = indexPath.row + 1 <= (self.messageViewModels?.count)!
                    ? self.messageViewModels?[indexPath.row + 1] : nil
                if nextMsgViewModel != nil {
                    return msgOwner != nextMsgViewModel?.bubblePosition()
                        ? BubbleChaining.singleMessage : BubbleChaining.firstOfSequence
                }
            } else if self.messageViewModels?.count == indexPath.row + 1 {
                let lastMsgViewModel = indexPath.row - 1 >= 0 && indexPath.row - 1 < (self.messageViewModels?.count)!
                    ? self.messageViewModels?[indexPath.row - 1] : nil
                if lastMsgViewModel != nil {
                    return msgOwner != lastMsgViewModel?.bubblePosition()
                        ? BubbleChaining.singleMessage : BubbleChaining.lastOfSequence
                }
            }
            let lastMsgViewModel = indexPath.row - 1 >= 0 && indexPath.row - 1 < (self.messageViewModels?.count)!
                ? self.messageViewModels?[indexPath.row - 1] : nil
            let nextMsgViewModel = indexPath.row + 1 <= (self.messageViewModels?.count)!
                ? self.messageViewModels?[indexPath.row + 1] : nil
            var chaining = BubbleChaining.singleMessage
            if (lastMsgViewModel != nil) && (nextMsgViewModel != nil) {
                if msgOwner != lastMsgViewModel?.bubblePosition() && msgOwner == nextMsgViewModel?.bubblePosition() {
                    chaining = BubbleChaining.firstOfSequence
                } else if msgOwner != nextMsgViewModel?.bubblePosition() && msgOwner == lastMsgViewModel?.bubblePosition() {
                    chaining = BubbleChaining.lastOfSequence
                } else if msgOwner == nextMsgViewModel?.bubblePosition() && msgOwner == lastMsgViewModel?.bubblePosition() {
                    chaining = BubbleChaining.middleOfSequence
                }
            }
            return chaining
        }
        return BubbleChaining.error
    }

    func applyBubbleStyleToCell(toCell cell: MessageCell,
                                withChaining chaining: BubbleChaining,
                                withContent content: String,
                                withType type: BubblePosition) {

        let bubbleColor = type == .received ? UIColor.ringMsgCellReceived : UIColor.ringMsgCellSent

        cell.messageLabel.setTextWithLineSpacing(withText: content, withLineSpacing: 2)

        cell.topCorner.isHidden = true
        cell.topCorner.backgroundColor = bubbleColor
        cell.bottomCorner.isHidden = true
        cell.bottomCorner.backgroundColor = bubbleColor
        cell.bubbleBottomConstraint.constant = 8
        cell.bubbleTopConstraint.constant = 8

        switch chaining {
        case .middleOfSequence:
            cell.topCorner.isHidden = false
            cell.bottomCorner.isHidden = false
            cell.bubbleBottomConstraint.constant = 1
            cell.bubbleTopConstraint.constant = 1
        case .firstOfSequence:
            cell.bottomCorner.isHidden = false
            cell.bubbleBottomConstraint.constant = 1
        case .lastOfSequence:
            cell.topCorner.isHidden = false
            cell.bubbleTopConstraint.constant = 1
        default: break
        }
    }

}

extension ConversationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messageViewModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if let messageViewModel = self.messageViewModels?[indexPath.row] {
            let chaining = self.getBubbleChaining(cellForRowAt: indexPath)
            if messageViewModel.bubblePosition() == .received {
                // left side (incoming)
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellReceived.self)

                // Format cell
                applyBubbleStyleToCell(toCell: cell, withChaining: chaining, withContent: messageViewModel.content, withType: .received)

                // Special cases where top/bottom margins should be larger
                if isFirstMessage(cellForRowAt: indexPath) {
                    cell.bubbleTopConstraint.constant = 16
                } else if isLastMessage(cellForRowAt: indexPath) {
                    cell.bubbleBottomConstraint.constant = 16
                }

                return cell
            } else {
                // right side (outgoing)
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellSent.self)

                // Format cell
                applyBubbleStyleToCell(toCell: cell, withChaining: chaining, withContent: messageViewModel.content, withType: .sent)

                // Special cases where top/bottom margins should be larger
                if isFirstMessage(cellForRowAt: indexPath) {
                    cell.bubbleTopConstraint.constant = 16
                } else if isLastMessage(cellForRowAt: indexPath) {
                    cell.bubbleBottomConstraint.constant = 16
                }

                return cell
            }
        }

        return tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellSent.self)

    }

}
