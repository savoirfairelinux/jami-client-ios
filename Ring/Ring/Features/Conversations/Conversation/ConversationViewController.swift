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

    fileprivate var backgroundColorObservable: Observable<UIColor>!

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

        // UIColor that observes "best Id" prefix
        self.backgroundColorObservable = viewModel.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .map { name in
                let scanner = Scanner(string: name.toMD5HexString().prefixString())
                var index: UInt64 = 0
                if scanner.scanHexInt64(&index) {
                    return avatarColors[Int(index)]
                }
                return defaultAvatarColor
            }

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
            self?.computeSequencing()
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

    func computeSequencing() {
        var lastShownTime: Date?
        for (index, messageViewModel) in self.messageViewModels!.enumerated() {
            // time labels
            let time = messageViewModel.receivedDate
            if index == 0 ||  messageViewModel.bubblePosition() == .generated {
                // always show first message's time
                messageViewModel.timeStringShown = getTimeLabelString(forTime: time)
                lastShownTime = time
            } else {
                // only show time for new messages if beyond an arbitrary time frame (1 minute)
                // from the previously shown time
                let hourComp = Calendar.current.compare(lastShownTime!, to: time, toGranularity: .hour)
                let minuteComp = Calendar.current.compare(lastShownTime!, to: time, toGranularity: .minute)
                if hourComp == .orderedSame && minuteComp == .orderedSame {
                    messageViewModel.timeStringShown = nil
                } else {
                    messageViewModel.timeStringShown = getTimeLabelString(forTime: time)
                    lastShownTime = time
                }
            }
            // sequencing
            messageViewModel.sequencing = getMessageSequencing(forIndex: index)
        }
    }

    func getTimeLabelString(forTime time: Date) -> String {
        // get the current time
        let currentDateTime = Date()

        // prepare formatter
        let dateFormatter = DateFormatter()
        if Calendar.current.compare(currentDateTime, to: time, toGranularity: .year) == .orderedSame {
            if Calendar.current.compare(currentDateTime, to: time, toGranularity: .weekOfYear) == .orderedSame {
                if Calendar.current.compare(currentDateTime, to: time, toGranularity: .day) == .orderedSame {
                    // age: [0, received the previous day[
                    dateFormatter.dateFormat = "h:mma"
                } else {
                    // age: [received the previous day, received 7 days ago[
                    dateFormatter.dateFormat = "E h:mma"
                }
            } else {
                // age: [received 7 days ago, received the previous year[
                let day = Calendar.current.component(.day, from: time)
                // apply appropriate suffix to day value
                let suffix = day == 1 ? "st" : (day == 2 ? "nd" : (day == 3 ? "rd" : "th"))
                dateFormatter.dateFormat = "MMM d'\(suffix),' h:mma"
            }
        } else {
            // age: [received the previous year, inf[
            dateFormatter.dateFormat = "MMM d'th yyyy,' h:mma"
        }

        // generate the string containing the message time
        return dateFormatter.string(from: time).uppercased()
    }

    func formatTimeLabel(forCell cell: MessageCell,
                         withMessageVM messageVM: MessageViewModel) {
        // hide for potentially reused cell
        cell.timeLabel.isHidden = true
        cell.leftDivider.isHidden = true
        cell.rightDivider.isHidden = true

        if messageVM.timeStringShown == nil {
            return
        }

        // setup the label
        cell.timeLabel.text = messageVM.timeStringShown
        cell.timeLabel.textColor = UIColor.ringMsgCellTimeText
        cell.timeLabel.font = UIFont.boldSystemFont(ofSize: 14.0)

        // show the time
        cell.timeLabel.isHidden = false
        cell.leftDivider.isHidden = false
        cell.rightDivider.isHidden = false
    }

    func getMessageSequencing(forIndex index: Int) -> MessageSequencing {
        if let msgViewModel = self.messageViewModels?[index] {
            let msgOwner = msgViewModel.bubblePosition()
            if self.messageViewModels?.count == 1 || index == 0 {
                if self.messageViewModels?.count == index + 1 {
                    return MessageSequencing.singleMessage
                }
                let nextMsgViewModel = index + 1 <= (self.messageViewModels?.count)!
                    ? self.messageViewModels?[index + 1] : nil
                if nextMsgViewModel != nil {
                    return msgOwner != nextMsgViewModel?.bubblePosition()
                        ? MessageSequencing.singleMessage : MessageSequencing.firstOfSequence
                }
            } else if self.messageViewModels?.count == index + 1 {
                let lastMsgViewModel = index - 1 >= 0 && index - 1 < (self.messageViewModels?.count)!
                    ? self.messageViewModels?[index - 1] : nil
                if lastMsgViewModel != nil {
                    return msgOwner != lastMsgViewModel?.bubblePosition()
                        ? MessageSequencing.singleMessage : MessageSequencing.lastOfSequence
                }
            }
            let lastMsgViewModel = index - 1 >= 0 && index - 1 < (self.messageViewModels?.count)!
                ? self.messageViewModels?[index - 1] : nil
            let nextMsgViewModel = index + 1 <= (self.messageViewModels?.count)!
                ? self.messageViewModels?[index + 1] : nil
            var sequencing = MessageSequencing.singleMessage
            if (lastMsgViewModel != nil) && (nextMsgViewModel != nil) {
                if msgOwner != lastMsgViewModel?.bubblePosition() && msgOwner == nextMsgViewModel?.bubblePosition() {
                    sequencing = MessageSequencing.firstOfSequence
                } else if msgOwner != nextMsgViewModel?.bubblePosition() && msgOwner == lastMsgViewModel?.bubblePosition() {
                    sequencing = MessageSequencing.lastOfSequence
                } else if msgOwner == nextMsgViewModel?.bubblePosition() && msgOwner == lastMsgViewModel?.bubblePosition() {
                    sequencing = MessageSequencing.middleOfSequence
                }
            }
            return sequencing
        }
        return MessageSequencing.unknown
    }

    func applyBubbleStyleToCell(toCell cell: MessageCell,
                                cellForRowAt indexPath: IndexPath,
                                withMessageVM messageVM: MessageViewModel) {
        let type = messageVM.bubblePosition()
        let bubbleColor = type == .received ? UIColor.ringMsgCellReceived : UIColor.ringMsgCellSent

        cell.messageLabel.setTextWithLineSpacing(withText: messageVM.content, withLineSpacing: 2)

        cell.topCorner.isHidden = true
        cell.topCorner.backgroundColor = bubbleColor
        cell.bottomCorner.isHidden = true
        cell.bottomCorner.backgroundColor = bubbleColor
        cell.bubbleBottomConstraint.constant = 8
        cell.bubbleTopConstraint.constant = 8

        var adjustedSequencing = messageVM.sequencing

        if messageVM.timeStringShown != nil {
            cell.bubbleTopConstraint.constant = 32
            adjustedSequencing = indexPath.row == (self.messageViewModels?.count)! - 1 ?
                .singleMessage : adjustedSequencing != .singleMessage && adjustedSequencing != .lastOfSequence ?
                    .firstOfSequence : .singleMessage
        }

        if indexPath.row + 1 < (self.messageViewModels?.count)! {
            if self.messageViewModels?[indexPath.row + 1].timeStringShown != nil {
                switch adjustedSequencing {
                case .firstOfSequence:
                    adjustedSequencing = .singleMessage
                case .middleOfSequence:
                    adjustedSequencing = .lastOfSequence
                default: break
                }
            }
        }

        messageVM.sequencing = adjustedSequencing

        switch messageVM.sequencing {
        case .middleOfSequence:
            cell.topCorner.isHidden = false
            cell.bottomCorner.isHidden = false
            cell.bubbleBottomConstraint.constant = 1
            cell.bubbleTopConstraint.constant = messageVM.timeStringShown != nil ? 32 : 1
        case .firstOfSequence:
            cell.bottomCorner.isHidden = false
            cell.bubbleBottomConstraint.constant = 1
            cell.bubbleTopConstraint.constant = messageVM.timeStringShown != nil ? 32 : 8
        case .lastOfSequence:
            cell.topCorner.isHidden = false
            cell.bubbleTopConstraint.constant = messageVM.timeStringShown != nil ? 32 : 1
        default: break
        }

    }

    func formatCell(withCell cell: MessageCell,
                    cellForRowAt indexPath: IndexPath,
                    withMessageVM messageVM: MessageViewModel) {

        // hide/show time label
        formatTimeLabel(forCell: cell, withMessageVM: messageVM)

        if messageVM.bubblePosition() == .generated {
            cell.bubble.backgroundColor = UIColor.ringMsgCellReceived
            cell.messageLabel.setTextWithLineSpacing(withText: messageVM.content, withLineSpacing: 2)
            // generated messages should always show the time
            cell.bubbleTopConstraint.constant = 32
            return
        }

        // bubble grouping for cell
        applyBubbleStyleToCell(toCell: cell, cellForRowAt: indexPath, withMessageVM: messageVM)

        // special cases where top/bottom margins should be larger
        if indexPath.row == 0 {
            cell.bubbleTopConstraint.constant = 32
        } else if self.messageViewModels?.count == indexPath.row + 1 {
            cell.bubbleBottomConstraint.constant = 16
        }

        if messageVM.bubblePosition() == .sent {
            messageVM.status.asObservable()
                .observeOn(MainScheduler.instance)
                .map { value in value == MessageStatus.sending ? true : false }
                .bind(to: cell.sendingIndicator.rx.isAnimating)
                .disposed(by: cell.disposeBag)
            messageVM.status.asObservable()
                .observeOn(MainScheduler.instance)
                .map { value in value == MessageStatus.failure ? false : true }
                .bind(to: cell.failedStatusLabel.rx.isHidden)
                .disposed(by: cell.disposeBag)
        } else if messageVM.bubblePosition() == .received {
            // avatar
            guard let fallbackAvatar = cell.fallbackAvatar else {
                return
            }

            fallbackAvatar.isHidden = true
            cell.profileImage?.isHidden = true
            if messageVM.sequencing == .lastOfSequence || messageVM.sequencing == .singleMessage {
                cell.profileImage?.isHidden = false

                // Avatar placeholder initial
                viewModel.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .map { value in value.prefixString().capitalized }
                    .bind(to: fallbackAvatar.rx.text)
                    .disposed(by: cell.disposeBag)

                // Set placeholder avatar to backgroundColorObservable
                self.backgroundColorObservable
                    .subscribe(onNext: { backgroundColor in
                        fallbackAvatar.backgroundColor = backgroundColor
                    })
                    .disposed(by: cell.disposeBag)

                // Set image if any
                cell.profileImage?.image = nil
                if let imageData = viewModel.profileImageData {
                    if let image = UIImage(data: imageData) {
                        cell.profileImage?.image = image
                        fallbackAvatar.isHidden = true
                    }
                } else {
                    fallbackAvatar.isHidden = false
                }
            }
        }
    }
}

extension ConversationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messageViewModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let messageViewModel = self.messageViewModels?[indexPath.row] {
            if messageViewModel.bubblePosition() == .received {
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellReceived.self)
                formatCell(withCell: cell, cellForRowAt: indexPath, withMessageVM: messageViewModel)
                return cell
            } else if messageViewModel.bubblePosition() == .sent {
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellSent.self)
                formatCell(withCell: cell, cellForRowAt: indexPath, withMessageVM: messageViewModel)
                return cell
            } else if messageViewModel.bubblePosition() == .generated {
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellGenerated.self)
                formatCell(withCell: cell, cellForRowAt: indexPath, withMessageVM: messageViewModel)
                return cell
            }
        }

        return tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellSent.self)

    }

}
