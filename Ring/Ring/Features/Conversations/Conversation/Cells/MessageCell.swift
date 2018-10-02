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
import SwiftyBeaver

class MessageCell: UITableViewCell, NibReusable {

    let log = SwiftyBeaver.self

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var bubble: MessageBubble!
    @IBOutlet weak var bubbleBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var bubbleTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabelMarginConstraint: NSLayoutConstraint!
    @IBOutlet weak var avatarBotomAlignConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabel: ActiveLabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var acceptButton: UIButton?
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var buttonsHeightConstraint: NSLayoutConstraint?
    @IBOutlet weak var bottomCorner: UIView!
    @IBOutlet weak var topCorner: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var leftDivider: UIView!
    @IBOutlet weak var rightDivider: UIView!
    @IBOutlet weak var sendingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var failedStatusLabel: UILabel!
    @IBOutlet weak var bubbleViewMask: UIView?

    private var transferImageView = UIImageView()

    var dataTransferProgressUpdater: Timer?

    var disposeBag = DisposeBag()


    override func prepareForReuse() {
        super.prepareForReuse()
        self.stopProgressMonitor()
        self.disposeBag = DisposeBag()
    }

    func startProgressMonitor(_ item: MessageViewModel,
                              _ conversationViewModel: ConversationViewModel) {
        if self.dataTransferProgressUpdater != nil {
            self.stopProgressMonitor()
            return
        }
        guard let transferId = item.daemonId else { return }
        self.dataTransferProgressUpdater = Timer.scheduledTimer(timeInterval: 0.5,
                                                                target: self,
                                                                selector: #selector(self.updateProgressBar),
                                                                userInfo: ["transferId": transferId,
                                                                           "conversationViewModel": conversationViewModel],
                                                                repeats: true)
    }

    func stopProgressMonitor() {
        guard let updater = self.dataTransferProgressUpdater else { return }
        updater.invalidate()
        self.dataTransferProgressUpdater = nil
    }

    @objc func updateProgressBar(timer: Timer) {
        guard let userInfoDict = timer.userInfo as? NSDictionary else { return }
        guard let transferId = userInfoDict["transferId"] as? UInt64 else { return }
        guard let viewModel = userInfoDict["conversationViewModel"] as? ConversationViewModel else { return }
        if let progress = viewModel.getTransferProgress(transferId: transferId) {
            DispatchQueue.main.async {
                self.progressBar.progress = progress
            }
        }
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
            if item.content.containsOnlyEmoji {
                bubbleColor = UIColor.ringMsgCellEmoji
            } else {
                bubbleColor = type == .received ? UIColor.ringMsgCellReceived : UIColor(hex: 0xcfebf5, alpha: 1.0)
            }
        } else {
            if item.content.containsOnlyEmoji {
                bubbleColor = UIColor.ringMsgCellEmoji
            } else {
                bubbleColor = type == .received ? UIColor.ringMsgCellReceived : UIColor.ringMsgCellSent
            }
        }

        if item.isTransfer {
            self.messageLabel.enabledTypes = []
            let contentArr = item.content.components(separatedBy: "\n")
            if contentArr.count > 1 {
                self.messageLabel.text = contentArr[0]
                self.sizeLabel.text = contentArr[1]
            } else {
                self.messageLabel.text = item.content
            }
        } else {
            self.messageLabel.enabledTypes = [.url]
            self.setup()
            self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 2)
            self.messageLabel.handleURLTap { url in
                let urlString = url.absoluteString
                if let prefixedUrl = URL(string: urlString.contains("http") ? urlString : "http://\(urlString)") {
                    UIApplication.shared.openURL(prefixedUrl)
                }
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
            self.topCorner.isHidden = item.isTransfer
            self.bottomCorner.isHidden = item.isTransfer
            self.bubbleBottomConstraint.constant = 1
            self.bubbleTopConstraint.constant = item.timeStringShown != nil ? 32 : 1
        case .firstOfSequence:
            self.bottomCorner.isHidden = item.isTransfer
            self.bubbleBottomConstraint.constant = 1
            self.bubbleTopConstraint.constant = item.timeStringShown != nil ? 32 : 8
        case .lastOfSequence:
            self.topCorner.isHidden = item.isTransfer
            self.bubbleTopConstraint.constant = item.timeStringShown != nil ? 32 : 1
        default: break
        }
        if item.content.containsOnlyEmoji {
            self.messageLabel.font = UIFont.systemFont(ofSize: 40.0, weight: UIFont.Weight.medium)
        } else {
            self.messageLabel.font = UIFont.systemFont(ofSize: 16.0, weight: UIFont.Weight.medium)
        }
    }

    /// swiftlint:disable function_body_length
    func configureFromItem(_ conversationViewModel: ConversationViewModel,
                           _ items: [MessageViewModel]?,
                           cellForRowAt indexPath: IndexPath) {

        self.backgroundColor = UIColor.clear
        self.bubbleViewMask?.backgroundColor = UIColor.ringMsgBackground
        self.transferImageView.backgroundColor = UIColor.ringMsgBackground
        buttonsHeightConstraint?.priority = UILayoutPriority(rawValue: 999.0)
        guard let item = items?[indexPath.row] else {
            return
        }

        self.transferImageView.removeFromSuperview()
        self.bubbleViewMask?.isHidden = true

        // hide/show time label
        self.formatCellTimeLabel(item)

        if item.bubblePosition() == .generated {
            self.bubble.backgroundColor = UIColor.ringMsgCellReceived
            self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 2)
            if indexPath.row == 0 {
                self.messageLabelMarginConstraint.constant = 4
                self.bubbleTopConstraint.constant = 36
            } else {
                self.messageLabelMarginConstraint.constant = -2
                self.bubbleTopConstraint.constant = 32
            }
            return
        } else if item.isTransfer {
            self.messageLabel.lineBreakMode = .byTruncatingMiddle
            let type = item.bubblePosition()
            self.bubble.backgroundColor = type == .received ? UIColor.ringMsgCellReceived : UIColor(hex: 0xcfebf5, alpha: 1.0)
            if indexPath.row == 0 {
                self.messageLabelMarginConstraint.constant = 4
                self.bubbleTopConstraint.constant = 36
            } else {
                self.messageLabelMarginConstraint.constant = -2
                self.bubbleTopConstraint.constant = 32
            }
            if item.bubblePosition() == .received {
                self.acceptButton?.tintColor = UIColor(hex: 0x00b20b, alpha: 1.0)
                self.cancelButton.tintColor = UIColor(hex: 0xf00000, alpha: 1.0)
                self.progressBar.tintColor = UIColor.ringMain
            } else if item.bubblePosition() == .sent {
                self.cancelButton.tintColor = UIColor(hex: 0xf00000, alpha: 1.0)
                self.progressBar.tintColor = UIColor.ringMain.lighten(byPercentage: 0.2)
            }

            if item.shouldDisplayTransferedImage {
                self.displayTransferedImage(message: item, conversationID: conversationViewModel.conversation.value.conversationId)
            }
        }

        // bubble grouping for cell
        self.applyBubbleStyleToCell(items, cellForRowAt: indexPath)

        // special cases where top/bottom margins should be larger
        if indexPath.row == 0 {
            self.messageLabelMarginConstraint.constant = 4
            self.bubbleTopConstraint.constant = 36
        } else if items?.count == indexPath.row + 1 {
            self.bubbleBottomConstraint.constant = 16
        }

        if item.bubblePosition() == .sent {
            // When the message contains only emoji
            if item.content.containsOnlyEmoji {
                self.bubble.backgroundColor = UIColor.ringMsgCellEmoji
            } else {
                self.bubble.backgroundColor = UIColor.ringMsgCellSent
            }
            if item.isTransfer {
                // outgoing transfer
            } else {
                // sent message status
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
            }
        } else if item.bubblePosition() == .received {
            // When the message contains only emoji
            if item.content.containsOnlyEmoji {
                self.bubble.backgroundColor = UIColor.ringMsgCellEmoji
                self.avatarBotomAlignConstraint.constant = -14
            } else {
                self.bubble.backgroundColor = UIColor.ringMsgCellReceived
                self.avatarBotomAlignConstraint.constant = -1
            }
            // received message avatar
            Observable<(Data?, String)>.combineLatest(conversationViewModel.profileImageData.asObservable(),
                                                      conversationViewModel.userName.asObservable(),
                                                      conversationViewModel.displayName.asObservable()) { profileImage, username, displayName in
                                                        if let displayName = displayName, !displayName.isEmpty {
                                                            return (profileImage, displayName)
                                                        }
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

    // swiftlint:enable function_body_length

    func displayTransferedImage(message: MessageViewModel, conversationID: String) {
        let maxDimsion: CGFloat = 250
        if let image = message.getTransferedImage(maxSize: maxDimsion, conversationID: conversationID) {
            self.transferImageView.image = image
            self.transferImageView.contentMode = .center
            buttonsHeightConstraint?.priority = UILayoutPriority(rawValue: 250.0)
            self.bubble.addSubview(self.transferImageView)
            self.bubbleViewMask?.isHidden = false
            self.bottomCorner.isHidden = true
            self.topCorner.isHidden = true
            self.transferImageView.translatesAutoresizingMaskIntoConstraints = false
            if message.bubblePosition() == .sent {
                self.transferImageView.trailingAnchor.constraint(equalTo: self.bubble.trailingAnchor, constant: 0).isActive = true
            } else if message.bubblePosition() == .received {
                self.transferImageView.leadingAnchor.constraint(equalTo: self.bubble.leadingAnchor, constant: 0).isActive = true
            }
            self.transferImageView.topAnchor.constraint(equalTo: self.bubble.topAnchor, constant: 0).isActive = true
            self.transferImageView.bottomAnchor.constraint(equalTo: self.bubble.bottomAnchor, constant: 0).isActive = true
        }
    }
    // swiftlint:enable cyclomatic_complexity

}
