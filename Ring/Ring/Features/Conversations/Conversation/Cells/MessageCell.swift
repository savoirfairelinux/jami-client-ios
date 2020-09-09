/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
import RxCocoa
import ActiveLabel
import SwiftyBeaver

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class MessageCell: UITableViewCell, NibReusable, PlayerDelegate {

    // MARK: Properties

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
    @IBOutlet weak var bubbleHeightConstraint: NSLayoutConstraint?
    @IBOutlet weak var bottomCorner: UIView!
    @IBOutlet weak var topCorner: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var leftDivider: UIView!
    @IBOutlet weak var rightDivider: UIView!
    @IBOutlet weak var sendingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var failedStatusLabel: UILabel!
    @IBOutlet weak var bubbleViewMask: UIView?
    @IBOutlet weak var messageReadIndicator: UIView?

    private var transferImageView = UIImageView()
    private var transferProgressView = ProgressView()
    private var composingMsg = UIView()

    var dataTransferProgressUpdater: Timer?
    var outgoingImageProgressUpdater: Timer?

    var playerView: PlayerView?

    var disposeBag = DisposeBag()

    var playerHeight = Variable<CGFloat>(0)

    private(set) var messageId: Int64?
    private var isCopyable: Bool = false
    private var couldBeShared: Bool = false
    private let _deleteMessage = BehaviorRelay<Bool>(value: false)
    var deleteMessage: Observable<Bool> { _deleteMessage.asObservable() }

    var shareMessage = PublishSubject<Bool>()

    private let showTimeTap = BehaviorRelay<Bool>(value: false)
    var tappedToShowTime: Observable<Bool> { showTimeTap.asObservable() }
    private var previousBubbleConstraint: CGFloat?

    private var longGestureRecognizer: UILongPressGestureRecognizer?
    var tapGestureRecognizer: UITapGestureRecognizer?
    var doubleTapGestureRecognizer: UITapGestureRecognizer?

    let openPreview = BehaviorRelay<(Bool)>(value: (false))

    var transferedImage: UIImage? {
        return transferImageView.image
    }

    // MARK: PrepareForReuse

    override func prepareForReuse() {
        self.setCellTimeLabelVisibility(hide: true)

        if self.sendingIndicator != nil {
            self.sendingIndicator.stopAnimating()
        }
        self.stopProgressMonitor()
        self.stopOutgoingImageMonitor()
        self.transferProgressView.removeFromSuperview()
        self.playerView?.removeFromSuperview()
        self.composingMsg.removeFromSuperview()
        self.transferImageView.image = nil
        self.playerHeight.value = 0
        self.disposeBag = DisposeBag()
        openPreview.accept(false)
        super.prepareForReuse()
    }

    private func prepareForReuseTapGesture() {
        self.showTimeTap.accept(false)
        self.previousBubbleConstraint = nil
        if let tapGestureRecognizer = tapGestureRecognizer {
            self.bubble.removeGestureRecognizer(tapGestureRecognizer)
            self.tapGestureRecognizer = nil
        }

        if self.bubbleHeightConstraint != nil && self.bubbleHeightConstraint!.relation == .equal {
            self.bubbleHeightConstraint?.constant = 31
            changeRelation(constraint: self.bubbleHeightConstraint!, relation: .greaterThanOrEqual)
        }
    }

    private func prepareForReuseLongGesture() {
        self.messageId = nil
        self.isCopyable = false
        self.couldBeShared = false
        self._deleteMessage.accept(false)
        if let longGestureRecognizer = longGestureRecognizer {
            self.bubble.removeGestureRecognizer(longGestureRecognizer)
            self.longGestureRecognizer = nil
        }
    }

    // MARK: Progress

    func startProgressMonitor(_ item: MessageViewModel,
                              _ conversationViewModel: ConversationViewModel) {
        if self.outgoingImageProgressUpdater != nil {
            self.stopOutgoingImageMonitor()
            return
        }
        if self.dataTransferProgressUpdater != nil {
            self.stopProgressMonitor()
            return
        }
        guard let transferId = item.daemonId else { return }
        self.dataTransferProgressUpdater = Timer
            .scheduledTimer(timeInterval: 0.5,
                            target: self,
                            selector: #selector(self.updateProgressBar),
                            userInfo: ["transferId": transferId,
                                       "conversationViewModel": conversationViewModel],
                            repeats: true)
        self.outgoingImageProgressUpdater = Timer
            .scheduledTimer(timeInterval: 0.01,
                            target: self,
                            selector: #selector(self.updateOutgoigTransfer),
                            userInfo: ["transferId": transferId,
                                       "conversationViewModel": conversationViewModel],
                            repeats: true)
    }

    func stopProgressMonitor() {
        guard let updater = self.dataTransferProgressUpdater else { return }
        updater.invalidate()
        self.dataTransferProgressUpdater = nil
    }

    func stopOutgoingImageMonitor() {
        if let outgoingImageUpdater = self.outgoingImageProgressUpdater {
            outgoingImageUpdater.invalidate()
            self.outgoingImageProgressUpdater = nil
        }
    }

    @objc
    func updateProgressBar(timer: Timer) {
        guard let userInfoDict = timer.userInfo as? NSDictionary else { return }
        guard let transferId = userInfoDict["transferId"] as? UInt64 else { return }
        guard let viewModel = userInfoDict["conversationViewModel"] as? ConversationViewModel else { return }
        if let progress = viewModel.getTransferProgress(transferId: transferId) {
            DispatchQueue.main.async { [weak self] in
                self?.progressBar.progress = progress
            }
        }
    }

    @objc
    func updateOutgoigTransfer(timer: Timer) {
        guard let userInfoDict = timer.userInfo as? NSDictionary else { return }
        guard let transferId = userInfoDict["transferId"] as? UInt64 else { return }
        guard let viewModel = userInfoDict["conversationViewModel"] as? ConversationViewModel else { return }
        if let progress = viewModel.getTransferProgress(transferId: transferId) {
           DispatchQueue.main.async { [weak self] in
                self?.transferProgressView.progress = CGFloat(progress * 100)
           }
        }
    }

    func supportFullScreenMode() -> Bool {
        return (playerView != nil && playerView!.viewModel.hasVideo.value) || self.transferImageView.image != nil
    }

    // MARK: Configure

    func configureTapGesture() {
        let shownByDefault = !self.timeLabel.isHidden && !showTimeTap.value && !supportFullScreenMode()
        if shownByDefault { return }
        self.bubble.isUserInteractionEnabled = true
        self.tapGestureRecognizer = UITapGestureRecognizer()
        self.tapGestureRecognizer?.numberOfTapsRequired = 1
        self.tapGestureRecognizer?.delegate = self
        self.tapGestureRecognizer!.rx.event.bind(onNext: { [weak self] _ in self?.onTapGesture() }).disposed(by: self.disposeBag)
        self.bubble.addGestureRecognizer(tapGestureRecognizer!)
        guard let doubleTap = doubleTapGestureRecognizer else { return }
        self.tapGestureRecognizer?.require(toFail: doubleTap)
    }

    private func changeRelation(constraint: NSLayoutConstraint, relation: NSLayoutConstraint.Relation) {
        let new = NSLayoutConstraint(item: constraint.firstItem!, attribute: constraint.firstAttribute, relatedBy: relation,
                                     toItem: constraint.secondItem, attribute: constraint.secondAttribute, multiplier: constraint.multiplier, constant: constraint.constant)
        self.bubbleHeightConstraint!.isActive = false
        new.isActive = true
        self.layoutIfNeeded()
        self.bubbleHeightConstraint = new
    }

    private func prepareForTapGesture() {
        if self.bubbleHeightConstraint != nil && self.bubbleHeightConstraint!.relation != .equal {
            self.bubbleHeightConstraint?.constant = self.bubble.frame.height
            changeRelation(constraint: self.bubbleHeightConstraint!, relation: .equal)
        }
    }

    func onTapGesture() {
        // for player or image expand size on tap, for other messages show time
        if supportFullScreenMode() {
            openPreview.accept(true)
            return
        }
        self.prepareForTapGesture()

        if self.timeLabel.isHidden {
            self.previousBubbleConstraint = self.bubbleTopConstraint.constant
            self.bubbleTopConstraint.constant = 32
        } else {
            self.bubbleTopConstraint.constant = self.previousBubbleConstraint ?? 1
        }
        // trigger animation
        self.showTimeTap.accept(true)
    }

    private func configureLongGesture(_ messageId: Int64, _ bubblePosition: BubblePosition, _ isTransfer: Bool, _ isLocationSharingBubble: Bool) {
        self.messageId = messageId
        self.isCopyable = bubblePosition != .generated && !isTransfer && !isLocationSharingBubble
        self.couldBeShared = bubblePosition != .generated && !isLocationSharingBubble
        self.bubble.isUserInteractionEnabled = true
        longGestureRecognizer = UILongPressGestureRecognizer()
        longGestureRecognizer!.rx.event.bind(onNext: { [weak self] _ in self?.onLongGesture() }).disposed(by: self.disposeBag)
        self.bubble.addGestureRecognizer(longGestureRecognizer!)
    }

    private func onLongGesture() {
        becomeFirstResponder()
        let menu = UIMenuController.shared
        let shareItem = UIMenuItem(title: L10n.Global.share, action: NSSelectorFromString("share"))
        menu.menuItems = [shareItem]
        if !menu.isMenuVisible {
            menu.setTargetRect(self.bubble.frame, in: self)
            menu.setMenuVisible(true, animated: true)
        }
    }

    @objc
    func share() {
        shareMessage.onNext(true)
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = self.messageLabel.text
        UIMenuController.shared.setMenuVisible(false, animated: true)
    }

    override func delete(_ sender: Any?) {
        _deleteMessage.accept(true)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.copy) && self.isCopyable ||
            action == #selector(UIResponderStandardEditActions.delete) || (action == NSSelectorFromString("share") && self.couldBeShared)
    }

    func toggleCellTimeLabelVisibility() {
        self.setCellTimeLabelVisibility(hide: !self.timeLabel.isHidden)
    }

    private func setCellTimeLabelVisibility(hide: Bool) {
        self.timeLabel.isHidden = hide
        self.leftDivider.isHidden = hide
        self.rightDivider.isHidden = hide
    }

    private func configureCellTimeLabel(_ item: MessageViewModel) {
        // hide for potentially reused cell
        self.setCellTimeLabelVisibility(hide: true)

        // setup the label
        self.timeLabel.text = item.timeStringShown
        self.timeLabel.textColor = UIColor.jamiMsgCellTimeText
        self.timeLabel.font = UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.medium)

        if item.shouldShowTimeString {
            // show the time
            self.setCellTimeLabelVisibility(hide: false)
        }
    }

    // bubble grouping for cell
    // swiftlint:disable cyclomatic_complexity
    func applyBubbleStyleToCell(_ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {

        guard let items = items else { return }
        let item = items[indexPath.row]

        self.topCorner.isHidden = true
        self.bottomCorner.isHidden = true
        self.bubbleBottomConstraint.constant = 8
        self.bubbleTopConstraint.constant = 8

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
            self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 2)
            self.messageLabel.handleURLTap { url in
                let urlString = url.absoluteString
                if let prefixedUrl = URL(string: urlString.contains("http") ? urlString : "http://\(urlString)") {
                    UIApplication.shared.open(prefixedUrl, completionHandler: nil)
                }
            }
        }

        item.sequencing = { (item: MessageViewModel) -> MessageSequencing in
            var adjustedSequencing = item.sequencing

            if item.shouldShowTimeString {
                self.bubbleTopConstraint.constant = 32

                if indexPath.row == items.count - 1 {
                    adjustedSequencing =  .singleMessage
                } else if adjustedSequencing != .singleMessage && adjustedSequencing != .lastOfSequence {
                    adjustedSequencing = .firstOfSequence
                } else {
                    adjustedSequencing = .singleMessage
                }
            }

            if indexPath.row + 1 < items.count && items[indexPath.row + 1].shouldShowTimeString {
                switch adjustedSequencing {
                case .firstOfSequence: adjustedSequencing = .singleMessage
                case .middleOfSequence: adjustedSequencing = .lastOfSequence
                default: break
                }
            }
            return adjustedSequencing
        }(item)

        switch item.sequencing {
        case .firstOfSequence:
            self.bottomCorner.isHidden = item.isTransfer
            self.bubbleBottomConstraint.constant = 1
            self.bubbleTopConstraint.constant = item.shouldShowTimeString ? 32 : 8
        case .middleOfSequence:
            self.topCorner.isHidden = item.isTransfer
            self.bottomCorner.isHidden = item.isTransfer
            self.bubbleBottomConstraint.constant = 1
            self.bubbleTopConstraint.constant = item.shouldShowTimeString ? 32 : 1
        case .lastOfSequence:
            self.topCorner.isHidden = item.isTransfer
            self.bubbleTopConstraint.constant = item.shouldShowTimeString ? 32 : 1
        default: break
        }
        if item.content.containsOnlyEmoji {
            self.messageLabel.font = UIFont.systemFont(ofSize: 40.0, weight: UIFont.Weight.medium)
        } else {
            self.messageLabel.font = UIFont(name: "HelveticaNeue", size: 18.0)
        }
    }

    private func configureBackgroundColor(_ containsOnlyEmoji: Bool, _ bubblePosition: BubblePosition) {
        self.backgroundColor = UIColor.clear
        self.bubbleViewMask?.backgroundColor = UIColor.jamiMsgBackground
        self.transferImageView.backgroundColor = UIColor.jamiMsgBackground

        let cellBgColor: UIColor = { (containsOnlyEmoji: Bool, bubblePosition: BubblePosition) -> UIColor in
            switch bubblePosition {
            case .generated: return UIColor.jamiMsgCellReceived
            case .sent: return containsOnlyEmoji ? UIColor.jamiMsgCellEmoji : UIColor.jamiMsgCellSent
            case .received: return containsOnlyEmoji ? UIColor.jamiMsgCellEmoji : UIColor.jamiMsgCellReceived
            }
            // use this if is a sent transfer?
            // return UIColor(hex: 0xcfebf5, alpha: 1.0)
            // was previously set in that case but was overridden afterwards so useless
        }(containsOnlyEmoji, bubblePosition)

        self.topCorner?.backgroundColor = cellBgColor
        self.bottomCorner?.backgroundColor = cellBgColor
        self.bubble.backgroundColor = cellBgColor
    }

    func configureFromItem(_ conversationViewModel: ConversationViewModel,
                           _ items: [MessageViewModel]?,
                           cellForRowAt indexPath: IndexPath) {

        self.buttonsHeightConstraint?.priority = UILayoutPriority(rawValue: 999.0)
        self.transferImageView.removeFromSuperview()
        self.playerView?.removeFromSuperview()
        self.composingMsg.removeFromSuperview()
        self.playerHeight.value = 0
        self.bubbleViewMask?.isHidden = true

        guard let item = items?[indexPath.row] else { return }

        // hide/show time label
        self.configureCellTimeLabel(item)

        self.prepareForReuseLongGesture()
        self.configureLongGesture(item.message.messageId, item.bubblePosition(), item.isTransfer, item.isLocationSharingBubble)

        self.prepareForReuseTapGesture()

        self.configureBackgroundColor(item.content.containsOnlyEmoji, item.bubblePosition())

        switch item.bubblePosition() {
        case .generated:
            self.messageLabel.setTextWithLineSpacing(withText: item.content, withLineSpacing: 10)
            if indexPath.row == 0 {
                self.messageLabelMarginConstraint.constant = 4
                self.bubbleTopConstraint.constant = 36
            } else {
                self.messageLabelMarginConstraint.constant = -2
                self.bubbleTopConstraint.constant = 32
            }
            return

        case .sent:
            guard !item.isLocationSharingBubble else {
                self.setCellTimeLabelVisibility(hide: false)
                self.bubbleTopConstraint.constant = 32
                self.bubbleBottomConstraint.constant = 1
                break
            }

            self.configureTransferCell(item, conversationViewModel)

            self.applyBubbleStyleToCell(items, cellForRowAt: indexPath)

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

                self.configureMessageReadAvatar(item, conversationViewModel)
            }

        case .received:
            guard !item.isLocationSharingBubble else {
                self.setCellTimeLabelVisibility(hide: false)
                self.bubbleTopConstraint.constant = 32
                self.bubbleBottomConstraint.constant = 1
                self.configureReceivedMessageAvatar(item.sequencing, conversationViewModel)
                break
            }

            self.configureTransferCell(item, conversationViewModel)

            self.applyBubbleStyleToCell(items, cellForRowAt: indexPath)

            if self.avatarBotomAlignConstraint != nil {
                self.avatarBotomAlignConstraint.constant = item.content.containsOnlyEmoji ? -14 : -1
            }

            if item.isComposingIndicator {
                self.addComposingMsgView()
            }

            self.configureReceivedMessageAvatar(item.sequencing, conversationViewModel)
        }

        // special cases where top/bottom margins should be larger
        if indexPath.row == 0 {
            self.messageLabelMarginConstraint.constant = 4
            self.bubbleTopConstraint.constant = 36
        } else if items?.count == indexPath.row + 1 {
            self.bubbleBottomConstraint.constant = 16
        } else if item.isTransfer {
            self.messageLabelMarginConstraint.constant = -2
        }

        self.configureTapGesture()
    }

    private func configureTransferCell(_ item: MessageViewModel, _ conversationViewModel: ConversationViewModel) {
        guard item.isTransfer else { return }

        self.messageLabel.lineBreakMode = .byTruncatingMiddle

        if item.bubblePosition() == .received {
            self.acceptButton?.tintColor = UIColor(hex: 0x00b20b, alpha: 1.0)
            self.cancelButton.tintColor = UIColor(hex: 0xf00000, alpha: 1.0)
            self.progressBar.tintColor = UIColor.jamiMain
        } else if item.bubblePosition() == .sent {
            self.cancelButton.tintColor = UIColor(hex: 0xf00000, alpha: 1.0)
            self.progressBar.tintColor = UIColor.jamiMain.lighten(by: 0.2)
        }

        if item.shouldDisplayTransferedImage {
            self.displayTransferedImage(message: item, conversationID: conversationViewModel.conversation.value.conversationId, accountId: conversationViewModel.conversation.value.accountId)
        }

        if let player = item.getPlayer(conversationViewModel: conversationViewModel) {
            let screenWidth = UIScreen.main.bounds.width
            // size for audio file transfer
            var defaultSize = CGSize(width: 250, height: 100)
            var origin = CGPoint(x: 0, y: 0)
            // if have video update size to keep video ratio
            if let firstImage = player.firstFrame,
                let frameSize = firstImage.getNewSize(of: CGSize(width: getMaxDimensionForTransfer(), height: getMaxDimensionForTransfer())) {
                defaultSize = frameSize
                let xOriginImageSend = screenWidth - 112 - (defaultSize.width)
                if item.bubblePosition() == .sent {
                    origin = CGPoint(x: xOriginImageSend, y: 0)
                }
            }
            let frame = CGRect(origin: origin, size: defaultSize)
            let pView = PlayerView(frame: frame)
            pView.sizeMode = .inConversationMessage
            pView.viewModel = player
            player.delegate = self
            self.playerView = pView
            self.bubbleViewMask?.isHidden = false
            self.playerView!.layer.cornerRadius = 20
            self.playerView!.layer.masksToBounds = true
            self.buttonsHeightConstraint?.priority = UILayoutPriority(rawValue: 250.0)
            self.bubble.addSubview(self.playerView!)
            self.bubble.heightAnchor.constraint(equalTo: self.playerView!.heightAnchor, constant: 1).isActive = true
        }
    }

    private func configureReceivedMessageAvatar(_ itemSequencing: MessageSequencing, _ conversationViewModel: ConversationViewModel) {

        Observable<(Data?, String)>.combineLatest(conversationViewModel.profileImageData.asObservable(),
                                                  conversationViewModel.bestName.asObservable()) { ($0, $1) }
            .observeOn(MainScheduler.instance)
            .startWith((conversationViewModel.profileImageData.value, conversationViewModel.userName.value))
            .subscribe({ [weak self] profileData in
                guard let data = profileData.element?.1 else { return }
                self?.avatarView.subviews.forEach({ $0.removeFromSuperview() })
                if itemSequencing == .lastOfSequence || itemSequencing == .singleMessage {
                    self?.avatarView.addSubview(AvatarView(profileImageData: profileData.element?.0, username: data, size: 32))
                }
            })
            .disposed(by: self.disposeBag)
     }

    private func configureMessageReadAvatar(_ item: MessageViewModel, _ conversationViewModel: ConversationViewModel) {
        guard self.messageReadIndicator != nil else { return }

        Observable<(Data?, String, Bool)>.combineLatest(conversationViewModel.profileImageData.asObservable(),
                                                        conversationViewModel.bestName.asObservable(),
                                                        item.displayReadIndicator.asObservable()) { ($0, $1, $2) }
            .observeOn(MainScheduler.instance)
            .startWith((conversationViewModel.profileImageData.value, conversationViewModel.userName.value, item.displayReadIndicator.value))
            .subscribe({ [weak self] profileData in
                guard let bestName = profileData.element?.1 else { return }
                self?.messageReadIndicator?.subviews.forEach({ $0.removeFromSuperview() })
                if let displayReadIndicator = profileData.element?.2, displayReadIndicator {
                    self?.messageReadIndicator?.addSubview(AvatarView(profileImageData: profileData.element?.0, username: bestName, size: 12))
                }
            })
            .disposed(by: self.disposeBag)
    }

    func addComposingMsgView() {
        self.composingMsg = UIView(frame: self.messageLabel.frame)
        let size: CGFloat = 10
        let margin: CGFloat = 2
        let originY: CGFloat = self.messageLabel.frame.size.height * 0.5 - (size * 0.5)
        let point1 = UIView(frame: CGRect(x: 0, y: originY, width: size, height: size))
        let point2 = UIView(frame: CGRect(x: margin + size, y: originY, width: size, height: size))
        let point3 = UIView(frame: CGRect(x: point2.frame.origin.x + margin + size, y: originY, width: size, height: size))
        point1.cornerRadius = 5
        point2.cornerRadius = 5
        point3.cornerRadius = 5
        point1.backgroundColor = UIColor.jamiMain
        point2.backgroundColor = UIColor.jamiMain
        point3.backgroundColor = UIColor.jamiMain
        self.composingMsg.addSubview(point1)
        self.composingMsg.addSubview(point2)
        self.composingMsg.addSubview(point3)
        self.bubble.addSubview(composingMsg)
        point1.blink()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) { [weak point2] in
            point2?.blink()
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak point3] in
            point3?.blink()
        }
    }

    func extractedVideoFrame(with height: CGFloat) {
        guard (self.playerView?.superview) != nil else {
            return
        }
        playerHeight.value = height
    }

    func getMaxDimensionForTransfer() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        //iPhone 5 width
        if screenWidth <= 320 {
            return 200
            //iPhone 6, iPhone 6 Plus and iPhone XR width
        } else if screenWidth > 320 && screenWidth <= 414 {
            return 250
            //iPad width
        } else if screenWidth > 414 {
            return 300
        }
        return 250
    }

    func getInitialFrame() -> CGRect? {
        if self.playerView != nil {
            return self.playerView?.convert(self.playerView?.incomingImage.frame ?? CGRect.zero, to: nil)
        }
        return self.bubble.convert(self.transferImageView.frame, to: nil)
    }

    // swiftlint:enable function_body_length

    func displayTransferedImage(message: MessageViewModel, conversationID: String, accountId: String) {
        let screenWidth = UIScreen.main.bounds.width
        let maxDimsion: CGFloat = getMaxDimensionForTransfer()
        let defaultSize = CGSize(width: maxDimsion, height: maxDimsion)
        if let image = message.getTransferedImage(maxSize: maxDimsion,
                                                  conversationID: conversationID,
                                                  accountId: accountId) {
            self.transferImageView.image = image
            let newSize = self.transferImageView.image?.getNewSize(of: defaultSize)
            let xOriginImageSend = screenWidth - 112 - (newSize?.width ?? 200)
            if message.bubblePosition() == .sent {
                self.transferImageView.frame = CGRect(x: xOriginImageSend, y: 0, width: ((newSize?.width ?? 200)), height: ((newSize?.height ?? 200)))
            } else if message.bubblePosition() == .received {
                self.transferImageView.frame = CGRect(x: 0, y: 0, width: ((newSize?.width ?? 200)), height: ((newSize?.height ?? 200)))
            }
            self.transferImageView.layer.cornerRadius = 20
            self.transferImageView.layer.masksToBounds = true
            self.transferImageView.contentMode = .scaleAspectFill
            buttonsHeightConstraint?.priority = UILayoutPriority(rawValue: 250.0)
            self.bubble.addSubview(self.transferImageView)
            self.bubbleViewMask?.isHidden = false
            self.bottomCorner.isHidden = true
            self.topCorner.isHidden = true
            self.transferImageView.translatesAutoresizingMaskIntoConstraints = true
            self.transferImageView.topAnchor.constraint(equalTo: self.bubble.topAnchor, constant: 0).isActive = true
            self.transferImageView.bottomAnchor.constraint(equalTo: self.bubble.bottomAnchor, constant: 0).isActive = true
            if !message.message.incoming && message.initialTransferStatus != .success {
                self.transferProgressView.frame = self.transferImageView.frame
                self.transferProgressView.configureViews()
                self.transferProgressView.progress = 0
                self.transferProgressView.target = 100
                self.transferProgressView.currentProgress = 0
                self.transferProgressView.status.value = message.initialTransferStatus
                self.bubble.addSubview(self.transferProgressView)
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

// MARK: UIGestureRecognizerDelegate
extension MessageCell {
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
