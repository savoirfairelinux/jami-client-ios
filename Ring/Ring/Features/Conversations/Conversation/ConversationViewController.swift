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

extension UITextField {
    func setPadding(_ left: CGFloat, _ right: CGFloat) {
        self.leftView = UIView(frame: CGRect(x: 0, y: 0, width: left, height: self.frame.size.height))
        self.rightView = UIView(frame: CGRect(x: 0, y: 0, width: right, height: self.frame.size.height))
        self.leftViewMode = .always
        self.rightViewMode = .always
    }
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

        self.messageAccessoryView.messageTextField.setPadding(8.0, 8.0)

        /*
         Register to keyboard notifications to adjust tableView insets when the keybaord appears
         or disappears
         */
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(withNotification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    @objc func keyboardWillShow(withNotification notification: Notification) {

        let userInfo: Dictionary = notification.userInfo!
        guard let keyboardFrame: NSValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height

        self.tableView.contentInset.bottom = keyboardHeight
        self.tableView.scrollIndicatorInsets.bottom = keyboardHeight

        self.scrollToBottom(animated: false)
        self.updateBottomOffset()
    }

    @objc func keyboardWillHide(withNotification notification: Notification) {
        self.tableView.contentInset.bottom = 0
        self.tableView.scrollIndicatorInsets.bottom = 0
        self.updateBottomOffset()
    }

    func generateAvatarUIViewFromProfileData(profileImageData: Data?,
                                             username: String?,
                                             size: CGFloat = 32.0,
                                             offset: CGPoint = CGPoint(x: 0.0, y: 0.0)) -> UIView? {
        let avatarView: UIView = UIView.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        let avatarImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        if let imageData = profileImageData, let image = UIImage(data: imageData) {
            (avatarImageView as UIImageView).image = image.circleMasked
            avatarView.addSubview(avatarImageView)
        } else {
            // use fallback avatars
            let name = self.viewModel.userName.value
            let scanner = Scanner(string: name.toMD5HexString().prefixString())
            var index: UInt64 = 0
            if scanner.scanHexInt64(&index) {
                let fbaBGColor = avatarColors[Int(index)]
                let circle = UIView(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
                circle.center = CGPoint.init(x: size / 2, y: avatarView.center.y)
                circle.layer.cornerRadius = size / 2
                circle.backgroundColor = fbaBGColor
                circle.clipsToBounds = true
                avatarView.addSubview(circle)
                if self.viewModel.conversation.value.recipientRingId != name {
                    // use g-style fallback avatar
                    let initialLabel: UILabel = UILabel.init(frame: CGRect.init(x: offset.x, y: offset.y, width: size, height: size))
                    initialLabel.center = circle.center
                    initialLabel.text = name.prefixString().capitalized
                    initialLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                    initialLabel.textColor = UIColor.white
                    initialLabel.textAlignment = .center
                    avatarView.addSubview(initialLabel)
                } else {
                    // ringId only, so fallback fallback avatar
                    if let image = UIImage(named: "fallback_avatar") {
                        (avatarImageView as UIImageView).image = image.circleMasked
                        avatarView.addSubview(avatarImageView)
                    }
                }
            }
        }
        return avatarView
    }

    func setupNavTitle(profileImageData: Data?, displayName: String? = nil, username: String?) {
        let imageSize       = CGFloat(36.0)
        let imageOffsetY    = CGFloat(5.0)
        let infoPadding     = CGFloat(8.0)
        let maxNameLength   = CGFloat(128.0)
        var userNameYOffset = CGFloat(9.0)
        var nameSize        = CGFloat(18.0)
        let navbarFrame     = self.navigationController?.navigationBar.frame
        let totalHeight     = ((navbarFrame?.size.height ?? 0) + (navbarFrame?.origin.y ?? 0)) / 2

        // Replace "< Home" with a back arrow while we are crunching everything to the left side of the bar for now.
        self.navigationController?.navigationBar.backIndicatorImage = UIImage(named: "back_button")
        self.navigationController?.navigationBar.backIndicatorTransitionMaskImage = UIImage(named: "back_button")
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: nil, action: nil)

        let titleView: UIView = UIView.init(frame: CGRect(x: 0, y: 0, width: view.frame.width - 32, height: totalHeight))

        let profileImageView = UIImageView(frame: CGRect(x: 0, y: imageOffsetY, width: imageSize, height: imageSize))
        profileImageView.frame = CGRect.init(x: 0, y: 0, width: imageSize, height: imageSize)
        profileImageView.center = CGPoint.init(x: imageSize / 2, y: titleView.center.y)

        if let profileImageUIView = generateAvatarUIViewFromProfileData(profileImageData: profileImageData,
                                                                        username: username,
                                                                        size: 36) {
            profileImageView.addSubview(profileImageUIView)
            titleView.addSubview(profileImageView)
        }

        if let name = displayName, !name.isEmpty {
            let dnlabel: UILabel = UILabel.init(frame: CGRect.init(x: imageSize + infoPadding, y: 4, width: maxNameLength, height: 20))
            dnlabel.text = name
            dnlabel.font = UIFont.systemFont(ofSize: nameSize)
            dnlabel.textColor = UIColor.white
            dnlabel.textAlignment = .left
            titleView.addSubview(dnlabel)
            userNameYOffset = 20.0
            nameSize = 14.0
        }

        let unlabel: UILabel = UILabel.init(frame: CGRect.init(x: imageSize + infoPadding, y: userNameYOffset, width: maxNameLength, height: 24))
        unlabel.text = username
        unlabel.font = UIFont.systemFont(ofSize: nameSize)
        unlabel.textColor = UIColor.white
        unlabel.textAlignment = .left
        titleView.addSubview(unlabel)

        self.navigationItem.titleView = titleView

    }

    func setupUI() {
        if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
            self.viewModel.userName.asObservable().bind(to: self.navigationItem.rx.title).disposed(by: disposeBag)
        } else {
            self.setupNavTitle(profileImageData: self.viewModel.profileImageData.value,
                               displayName: self.viewModel.displayName.value,
                               username: self.viewModel.userName.value)

            Observable<(Data?, String?, String)>.combineLatest(self.viewModel.profileImageData.asObservable(),
                                                               self.viewModel.displayName.asObservable(),
                                                               self.viewModel.userName.asObservable()) { profileImage, displayName, username in
                                                            return (profileImage, displayName, username)
                }
                .observeOn(MainScheduler.instance)
                .subscribe({ [weak self] profileData -> Void in
                    self?.setupNavTitle(profileImageData: profileData.element?.0,
                                        displayName: profileData.element?.1,
                                        username: profileData.element?.2)
                    return
                })
                .disposed(by: self.disposeBag)
        }

        self.tableView.contentInset.bottom = messageAccessoryView.frame.size.height
        self.tableView.scrollIndicatorInsets.bottom = messageAccessoryView.frame.size.height

        //set navigation buttons - call and send contact request
        let inviteItem = UIBarButtonItem()
        inviteItem.image = UIImage(named: "add_person")
        inviteItem.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.inviteItemTapped()
            })
            .disposed(by: self.disposeBag)

        self.viewModel.inviteButtonIsAvailable.asObservable()
            .bind(to: inviteItem.rx.isEnabled)
            .disposed(by: disposeBag)

        // call button
        let audioCallItem = UIBarButtonItem()
        audioCallItem.image = UIImage(asset: Asset.callButton)
        audioCallItem.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.placeAudioOnlyCall()
            })
            .disposed(by: self.disposeBag)

        let videoCallItem = UIBarButtonItem()
        videoCallItem.image = UIImage(asset: Asset.videoRunning)
        videoCallItem.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.placeCall()
            }).disposed(by: self.disposeBag)

        //block contact button
        let blockItem = UIBarButtonItem()
        blockItem.image = UIImage(named: "block_icon")
        blockItem.rx.tap.throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] in
                self.blockItemTapped()
            }).disposed(by: self.disposeBag)

        // Items are from right to left
        self.navigationItem.rightBarButtonItems = [blockItem, videoCallItem, audioCallItem, inviteItem]

        Observable<[UIBarButtonItem]>
            .combineLatest(self.viewModel.inviteButtonIsAvailable.asObservable(),
                           self.viewModel.blockButtonIsAvailable.asObservable(),
                           resultSelector: { inviteButton, blockButton in
                            var buttons = [UIBarButtonItem]()
                            if blockButton {
                                buttons.append(blockItem)
                            }
                            buttons.append(videoCallItem)
                            buttons.append(audioCallItem)
                            if inviteButton {
                                buttons.append(inviteItem)
                            }
                            return buttons
            })
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] buttons in
                self?.navigationItem.rightBarButtonItems = buttons
            }).disposed(by: self.disposeBag)
    }

    func inviteItemTapped() {
       self.viewModel?.sendContactRequest()
    }

    func blockItemTapped() {
        let alert = UIAlertController(title: L10n.Alerts.confirmBlockContactTitle, message: L10n.Alerts.confirmBlockContact, preferredStyle: .alert)
        let blockAction = UIAlertAction(title: L10n.Actions.blockAction, style: .destructive) { (_: UIAlertAction!) -> Void in
            self.viewModel.block()
        }
        let cancelAction = UIAlertAction(title: L10n.Actions.cancelAction, style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(blockAction)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }

    func placeCall() {
        self.viewModel.startCall()
    }

    func placeAudioOnlyCall() {
        self.viewModel.startAudioCall()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.scrollToBottom(animated: false)
        self.textFieldShouldEndEditing = false
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
        self.viewModel.messages.asObservable().subscribe(onNext: { [weak self] (messageViewModels) in
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

    // MARK: - message formatting
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

    func getMessageSequencing(forIndex index: Int) -> MessageSequencing {
        if let messageItem = self.messageViewModels?[index] {
            let msgOwner = messageItem.bubblePosition()
            if self.messageViewModels?.count == 1 || index == 0 {
                if self.messageViewModels?.count == index + 1 {
                    return MessageSequencing.singleMessage
                }
                let nextMessageItem = index + 1 <= (self.messageViewModels?.count)!
                    ? self.messageViewModels?[index + 1] : nil
                if nextMessageItem != nil {
                    return msgOwner != nextMessageItem?.bubblePosition()
                        ? MessageSequencing.singleMessage : MessageSequencing.firstOfSequence
                }
            } else if self.messageViewModels?.count == index + 1 {
                let lastMessageItem = index - 1 >= 0 && index - 1 < (self.messageViewModels?.count)!
                    ? self.messageViewModels?[index - 1] : nil
                if lastMessageItem != nil {
                    return msgOwner != lastMessageItem?.bubblePosition()
                        ? MessageSequencing.singleMessage : MessageSequencing.lastOfSequence
                }
            }
            let lastMessageItem = index - 1 >= 0 && index - 1 < (self.messageViewModels?.count)!
                ? self.messageViewModels?[index - 1] : nil
            let nextMessageItem = index + 1 <= (self.messageViewModels?.count)!
                ? self.messageViewModels?[index + 1] : nil
            var sequencing = MessageSequencing.singleMessage
            if (lastMessageItem != nil) && (nextMessageItem != nil) {
                if msgOwner != lastMessageItem?.bubblePosition() && msgOwner == nextMessageItem?.bubblePosition() {
                    sequencing = MessageSequencing.firstOfSequence
                } else if msgOwner != nextMessageItem?.bubblePosition() && msgOwner == lastMessageItem?.bubblePosition() {
                    sequencing = MessageSequencing.lastOfSequence
                } else if msgOwner == nextMessageItem?.bubblePosition() && msgOwner == lastMessageItem?.bubblePosition() {
                    sequencing = MessageSequencing.middleOfSequence
                }
            }
            return sequencing
        }
        return MessageSequencing.unknown
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
                dateFormatter.dateFormat = "MMM d, h:mma"
            }
        } else {
            // age: [received the previous year, inf[
            dateFormatter.dateFormat = "MMM d, yyyy h:mma"
        }

        // generate the string containing the message time
        return dateFormatter.string(from: time).uppercased()
    }

}

extension ConversationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messageViewModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.messageViewModels?[indexPath.row] {
            let type =  item.bubblePosition() == .received ? MessageCellReceived.self :
                        item.bubblePosition() == .sent ? MessageCellSent.self :
                        item.bubblePosition() == .generated ? MessageCellGenerated.self :
                        MessageCellGenerated.self
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: type)
            cell.configureFromItem(viewModel, self.messageViewModels, cellForRowAt: indexPath)
            return cell
        }
        return tableView.dequeueReusableCell(for: indexPath, cellType: MessageCellSent.self)
    }

}
