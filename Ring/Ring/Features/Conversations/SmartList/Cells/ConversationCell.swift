/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

class ConversationCell: UITableViewCell, NibReusable {

    @IBOutlet weak var myLocationSharingIcon: UIImageView!
    @IBOutlet weak var locationSharingIcon: UIImageView!
    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var newMessagesIndicator: UIView?
    @IBOutlet weak var newMessagesLabel: UILabel?
    @IBOutlet weak var lastMessageDateLabel: UILabel?
    @IBOutlet weak var lastMessagePreviewLabel: UILabel?
    @IBOutlet weak var presenceIndicator: UIView?
    @IBOutlet weak var selectionIndicator: UIButton?
    @IBOutlet weak var selectionContainer: UIView?

    var avatarSize: CGFloat { return 50 }

    var incomingLocationSharing = false
    var outgoingLocationSharing = false

    override func setSelected(_ selected: Bool, animated: Bool) {
        let initialColor = selected ? UIColor.jamiUITableViewCellSelection : UIColor.jamiUITableViewCellSelection.lighten(by: 5.0)
        let finalColor = selected ? UIColor.jamiUITableViewCellSelection.lighten(by: 5.0) : UIColor.clear
        self.backgroundColor = initialColor
        UIView.animate(withDuration: 0.35, animations: { [weak self] in
            self?.backgroundColor = finalColor
        })
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        if highlighted {
            self.backgroundColor = UIColor.jamiUITableViewCellSelection
        } else {
            self.backgroundColor = UIColor.clear
        }
    }

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        super.prepareForReuse()
        self.disposeBag = DisposeBag()
        self.incomingLocationSharing = false
        self.outgoingLocationSharing = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            updateLocationSharingState()
        }
    }

    func updateLocationSharingState() {
        self.locationSharingIcon.isHidden = !self.incomingLocationSharing
        self.myLocationSharingIcon.isHidden = !self.outgoingLocationSharing
        if incomingLocationSharing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.locationSharingIcon.stopBlinking()
                self?.locationSharingIcon.blink()
            }
        }
        if outgoingLocationSharing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.myLocationSharingIcon.stopBlinking()
                self?.myLocationSharingIcon.blink()
            }
        }
    }

    func configureFromItem(_ item: ConversationSection.Item) {
        // avatar
        Observable<(Data?, String)>.combineLatest(item.profileImageData.asObservable(),
                                                  item.bestName.asObservable()) { ($0, $1) }
            .startWith((item.profileImageData.value, item.userName.value))
            .observe(on: MainScheduler.instance)
            .subscribe({ [weak self] profileData in
                guard let data = profileData.element?.1 else { return }

                self?.avatarView.subviews.forEach({ $0.removeFromSuperview() })
                self?.avatarView.addSubview(AvatarView(profileImageData: profileData.element?.0,
                                                       username: data,
                                                       size: self?.avatarSize ?? 50))
            })
            .disposed(by: self.disposeBag)

        // unread messages
        if let unreadMessages = self.newMessagesLabel {
            item.unreadMessages
                .observe(on: MainScheduler.instance)
                .startWith(item.unreadMessages.value)
                .bind(to: unreadMessages.rx.text)
                .disposed(by: self.disposeBag)
        }
        if let unreadMessagesIndicator = self.newMessagesIndicator {
            item.hideNewMessagesLabel
                .observe(on: MainScheduler.instance)
                .startWith(item.hideNewMessagesLabel.value)
                .bind(to: unreadMessagesIndicator.rx.isHidden)
                .disposed(by: self.disposeBag)
        }
        // presence
        if self.presenceIndicator != nil {
            item.contactPresence.asObservable()
                .observe(on: MainScheduler.instance)
                .startWith(item.contactPresence.value)
                .subscribe(onNext: { [weak self] presenceStatus in
                    guard let self = self else { return }
                    self.presenceIndicator?.isHidden = presenceStatus == .offline
                    if presenceStatus == .connected {
                        self.presenceIndicator?.backgroundColor = .onlinePresenceColor
                    } else if presenceStatus == .available {
                        self.presenceIndicator?.backgroundColor = .availablePresenceColor
                    }
                })
                .disposed(by: self.disposeBag)
        }

        // username
        item.bestName.asObservable()
            .observe(on: MainScheduler.instance)
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.nameLabel.lineBreakMode = .byTruncatingTail
        // last message date
        if let lastMessageTime = self.lastMessageDateLabel {
            item.lastMessageReceivedDate
                .observe(on: MainScheduler.instance)
                .startWith(item.lastMessageReceivedDate.value)
                .bind(to: lastMessageTime.rx.text)
                .disposed(by: self.disposeBag)
        }

        // last message preview
        if let lastMessage = self.lastMessagePreviewLabel {
            lastMessage.lineBreakMode = .byTruncatingTail
            item.lastMessage
                .observe(on: MainScheduler.instance)
                .startWith(item.lastMessage.value)
                .bind(to: lastMessage.rx.text)
                .disposed(by: self.disposeBag)
        }

        if let outgoingLocationSharingImage = Asset.localisationsSendBlack.image.withColor(.systemBlue) {
            self.myLocationSharingIcon.image = outgoingLocationSharingImage
        }

        if let incomingLocationSharingImage = Asset.localisationsReceiveBlack.image.withColor(.label) {
            self.locationSharingIcon.image = incomingLocationSharingImage
        }

        item.showOutgoingLocationSharing
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .startWith(item.showOutgoingLocationSharing.value)
            .subscribe(onNext: { [weak self] show in
                guard let self = self else { return }
                self.outgoingLocationSharing = show
                self.myLocationSharingIcon.isHidden = !show
                if show {
                    self.myLocationSharingIcon.blink()
                } else {
                    self.myLocationSharingIcon.stopBlinking()
                }
            })
            .disposed(by: self.disposeBag)

        item.showIncomingLocationSharing
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .startWith(item.showIncomingLocationSharing.value)
            .subscribe(onNext: { [weak self] show in
                guard let self = self else { return }
                self.incomingLocationSharing = show
                self.locationSharingIcon.isHidden = !show
                if show {
                    self.locationSharingIcon.blink()
                } else {
                    self.locationSharingIcon.stopBlinking()
                }
            })
            .disposed(by: self.disposeBag)
        self.selectionStyle = .none
    }
}
