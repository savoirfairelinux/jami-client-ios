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

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var bubble: MessageBubble!
    @IBOutlet weak var bubbleBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var bubbleTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabelMarginConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabel: ActiveLabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var bottomCorner: UIView!
    @IBOutlet weak var topCorner: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var leftDivider: UIView!
    @IBOutlet weak var rightDivider: UIView!
    @IBOutlet weak var sendingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var failedStatusLabel: UILabel!

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
        self.timeLabel.font = UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.medium)

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
        var bubbleColor: UIColor
        if item.isTransfer {
            bubbleColor = type == .received ? UIColor.ringMsgCellReceived : UIColor(hex: 0xcfebf5, alpha: 1.0)
        } else {
            bubbleColor = type == .received ? UIColor.ringMsgCellReceived : UIColor.ringMsgCellSent
        }
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

    func configureFromItem(_ conversationViewModel: ConversationViewModel,
                           _ items: [MessageViewModel]?,
                           cellForRowAt indexPath: IndexPath) {
        self.backgroundColor = UIColor.clear
        guard let item = items?[indexPath.row] else {
            return
        }

        // hide/show time label
        formatCellTimeLabel(item)

        if item.bubblePosition() == .generated {
            self.bubble.backgroundColor = UIColor.ringMsgCellReceived
            self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 2)
            // generated messages should always show the time
            if indexPath.row == 0 {
                messageLabelMarginConstraint.constant = 4
                self.bubbleTopConstraint.constant = 36
            } else {
                messageLabelMarginConstraint.constant = -2
                self.bubbleTopConstraint.constant = 32
            }
            return
        } else if item.isTransfer {
            self.messageLabel.lineBreakMode = .byTruncatingMiddle
            let type = item.bubblePosition()
            self.bubble.backgroundColor = type == .received ? UIColor.ringMsgCellReceived : UIColor(hex: 0xcfebf5, alpha: 1.0)
            self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 2)
            // transfer messages should always show the time
            if indexPath.row == 0 {
                messageLabelMarginConstraint.constant = 4
                self.bubbleTopConstraint.constant = 36
            } else {
                messageLabelMarginConstraint.constant = -2
                self.bubbleTopConstraint.constant = 32
            }
            if item.bubblePosition() == .received {
                self.acceptButton.tintColor = UIColor(hex: 0x00b20b, alpha: 1.0)
                self.cancelButton.tintColor = UIColor(hex: 0xf00000, alpha: 1.0)
                self.progressBar.tintColor = UIColor.ringMain
            } else if item.bubblePosition() == .sent {
                self.cancelButton.tintColor = UIColor(hex: 0xf00000, alpha: 1.0)
                self.progressBar.tintColor = UIColor.ringMain.lighten(byPercentage: 0.2)
            }
        }

        // bubble grouping for cell
        applyBubbleStyleToCell(items, cellForRowAt: indexPath)

        // special cases where top/bottom margins should be larger
        if indexPath.row == 0 {
            messageLabelMarginConstraint.constant = 4
            self.bubbleTopConstraint.constant = 36
        } else if items?.count == indexPath.row + 1 {
            self.bubbleBottomConstraint.constant = 16
        }

        // sent message status
        if item.bubblePosition() == .sent && !item.isTransfer {
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
            if item.isTransfer {

            }

            // received message avatar
            Observable<(Data?, String)>.combineLatest(conversationViewModel.profileImageData.asObservable(),
                                                      conversationViewModel.userName.asObservable()) { profileImage, username in
                                                        return (profileImage, username)
                }
                .observeOn(MainScheduler.instance)
                .startWith((conversationViewModel.profileImageData.value, conversationViewModel.userName.value))
                .subscribe({ [weak self] profileData -> Void in
                    self?.avatarView.subviews.forEach({ $0.removeFromSuperview() })
                    self?.avatarView.addSubview(AvatarView(profileImageData: profileData.element?.0,
                                                           username: (profileData.element?.1)!,
                                                           size: 32))
                    self?.avatarView.isHidden = !(item.sequencing == .lastOfSequence || item.sequencing == .singleMessage)
                    return
                })
                .disposed(by: self.disposeBag)

        }
    }
    // swiftlint:enable cyclomatic_complexity

}
