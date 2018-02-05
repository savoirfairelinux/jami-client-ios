/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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
import Reusable
import RxSwift
import ActiveLabel

class MessageCell: UITableViewCell, NibReusable {

    @IBOutlet weak var bubble: MessageBubble!
    @IBOutlet weak var bubbleBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var bubbleTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabel: ActiveLabel!
    @IBOutlet weak var bottomCorner: UIView!
    @IBOutlet weak var topCorner: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var leftDivider: UIView!
    @IBOutlet weak var rightDivider: UIView!
    @IBOutlet weak var sendingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var failedStatusLabel: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var fallbackAvatar: UILabel!
    @IBOutlet weak var fallbackAvatarImage: UIImageView!

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        self.disposeBag = DisposeBag()
    }

    func showCopyMenu() {
        becomeFirstResponder()
        let menu = UIMenuController.shared
        if !menu.isMenuVisible {
            menu.setTargetRect(self.bubble.frame, in: self)
            menu.setMenuVisible(true, animated: true)
        }
    }

    func setup() {
        let longGestureRecognizer = UILongPressGestureRecognizer()
        self.messageLabel.isUserInteractionEnabled = true
        self.messageLabel.addGestureRecognizer(longGestureRecognizer)
        longGestureRecognizer.rx.event.bind(onNext: { [weak self] _ in
            self?.showCopyMenu()
        }).disposed(by: self.disposeBag)
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = self.messageLabel.text
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.copy) {
            return true
        }
        return false
    }

    func formatCellTimeLabel(_ item: MessageViewModel) {
        // hide for potentially reused cell
        self.timeLabel.isHidden = true
        self.leftDivider.isHidden = true
        self.rightDivider.isHidden = true

        if item.timeStringShown == nil {
            return
        }

        // setup the label
        self.timeLabel.text = item.timeStringShown
        self.timeLabel.textColor = UIColor.ringMsgCellTimeText
        self.timeLabel.font = UIFont.boldSystemFont(ofSize: 14.0)

        // show the time
        self.timeLabel.isHidden = false
        self.leftDivider.isHidden = false
        self.rightDivider.isHidden = false
    }

    // swiftlint:disable cyclomatic_complexity
    func applyBubbleStyleToCell(_ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        guard let item = items?[indexPath.row] else {
            return
        }

        let type = item.bubblePosition()
        let bubbleColor = type == .received ? UIColor.ringMsgCellReceived : UIColor.ringMsgCellSent
        self.setup()

        self.messageLabel.enabledTypes = [.url]
        self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 2)
        self.messageLabel.handleURLTap { url in
            let urlString = url.absoluteString
            if let prefixedUrl = URL(string: urlString.contains("http") ? urlString : "http://\(urlString)") {
                UIApplication.shared.openURL(prefixedUrl)
            }
        }

        self.topCorner.isHidden = true
        self.topCorner.backgroundColor = bubbleColor
        self.bottomCorner.isHidden = true
        self.bottomCorner.backgroundColor = bubbleColor
        self.bubbleBottomConstraint.constant = 8
        self.bubbleTopConstraint.constant = 8

        var adjustedSequencing = item.sequencing

        if item.timeStringShown != nil {
            self.bubbleTopConstraint.constant = 32
            adjustedSequencing = indexPath.row == (items?.count)! - 1 ?
                .singleMessage : adjustedSequencing != .singleMessage && adjustedSequencing != .lastOfSequence ?
                    .firstOfSequence : .singleMessage
        }

        if indexPath.row + 1 < (items?.count)! {
            if items?[indexPath.row + 1].timeStringShown != nil {
                switch adjustedSequencing {
                case .firstOfSequence:
                    adjustedSequencing = .singleMessage
                case .middleOfSequence:
                    adjustedSequencing = .lastOfSequence
                default: break
                }
            }
        }

        item.sequencing = adjustedSequencing

        switch item.sequencing {
        case .middleOfSequence:
            self.topCorner.isHidden = false
            self.bottomCorner.isHidden = false
            self.bubbleBottomConstraint.constant = 1
            self.bubbleTopConstraint.constant = item.timeStringShown != nil ? 32 : 1
        case .firstOfSequence:
            self.bottomCorner.isHidden = false
            self.bubbleBottomConstraint.constant = 1
            self.bubbleTopConstraint.constant = item.timeStringShown != nil ? 32 : 8
        case .lastOfSequence:
            self.topCorner.isHidden = false
            self.bubbleTopConstraint.constant = item.timeStringShown != nil ? 32 : 1
        default: break
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // swiftlint:disable cyclomatic_complexity
    func configureFromItem(_ conversationViewModel: ConversationViewModel,
                      _ items: [MessageViewModel]?,
                      cellForRowAt indexPath: IndexPath) {
        guard let item = items?[indexPath.row] else {
            return
        }

        // hide/show time label
        formatCellTimeLabel(item)

        if item.bubblePosition() == .generated {
            self.bubble.backgroundColor = UIColor.ringMsgCellReceived
            self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 2)
            // generated messages should always show the time
            self.bubbleTopConstraint.constant = 32
            return
        }

        // bubble grouping for cell
        applyBubbleStyleToCell(items, cellForRowAt: indexPath)

        // special cases where top/bottom margins should be larger
        if indexPath.row == 0 {
            self.bubbleTopConstraint.constant = 32
        } else if items?.count == indexPath.row + 1 {
            self.bubbleBottomConstraint.constant = 16
        }

        if item.bubblePosition() == .sent {
            item.status.asObservable()
                .observeOn(MainScheduler.instance)
                .map { value in value == MessageStatus.sending ? true : false }
                .bind(to: self.sendingIndicator.rx.isAnimating)
                .disposed(by: self.disposeBag)
            item.status.asObservable()
                .observeOn(MainScheduler.instance)
                .map { value in value == MessageStatus.failure ? false : true }
                .bind(to: self.failedStatusLabel.rx.isHidden)
                .disposed(by: self.disposeBag)
        } else if item.bubblePosition() == .received {
            // avatar
            guard let fallbackAvatar = self.fallbackAvatar else {
                return
            }

            self.fallbackAvatar.isHidden = true
            self.profileImage?.isHidden = true
            if item.sequencing == .lastOfSequence || item.sequencing == .singleMessage {
                self.profileImage?.isHidden = false

                // Set placeholder avatar
                fallbackAvatar.text = nil
                self.fallbackAvatarImage.isHidden = true
                let name = conversationViewModel.userName.value
                let scanner = Scanner(string: name.toMD5HexString().prefixString())
                var index: UInt64 = 0
                if scanner.scanHexInt64(&index) {
                    fallbackAvatar.isHidden = false
                    fallbackAvatar.backgroundColor = avatarColors[Int(index)]
                    if conversationViewModel.conversation.value.recipientRingId != name {
                        self.fallbackAvatar.text = name.prefixString().capitalized
                    } else {
                        self.fallbackAvatarImage.isHidden = true
                    }
                }

                // Avatar placeholder color
                conversationViewModel.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .map { name in
                        let scanner = Scanner(string: name.toMD5HexString().prefixString())
                        var index: UInt64 = 0
                        if scanner.scanHexInt64(&index) {
                            return avatarColors[Int(index)]
                        }
                        return defaultAvatarColor
                    }.subscribe(onNext: { backgroundColor in
                        self.fallbackAvatar.backgroundColor = backgroundColor
                    })
                    .disposed(by: self.disposeBag)

                // Avatar placeholder initial
                conversationViewModel.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .filter({ userName in
                        return userName != conversationViewModel.conversation.value.recipientRingId
                    })
                    .map { value in
                        value.prefixString().capitalized
                    }
                    .bind(to: self.fallbackAvatar.rx.text)
                    .disposed(by: self.disposeBag)

                // If only the ringId is known, use fallback avatar image
                conversationViewModel.userName.asObservable()
                    .observeOn(MainScheduler.instance)
                    .map { userName in
                        userName != conversationViewModel.conversation.value.recipientRingId
                    }
                    .bind(to: self.fallbackAvatarImage.rx.isHidden)
                    .disposed(by: self.disposeBag)

                // Set image if any
                if let imageData = conversationViewModel.profileImageData.value {
                    if let image = UIImage(data: imageData) {
                        self.profileImage.image = image
                        self.fallbackAvatar.isHidden = true
                    }
                } else {
                    self.fallbackAvatar.isHidden = false
                    self.profileImage.image = nil
                }

                conversationViewModel.profileImageData.asObservable()
                    .observeOn(MainScheduler.instance)
                    .subscribe(onNext: { data in
                        if let imageData = data, let image = UIImage(data: imageData) {
                            self.profileImage.image = image
                            self.fallbackAvatar.isHidden = true
                        } else {
                            self.fallbackAvatar.isHidden = false
                            self.profileImage.image = nil
                        }
                    }).disposed(by: self.disposeBag)
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity
}
