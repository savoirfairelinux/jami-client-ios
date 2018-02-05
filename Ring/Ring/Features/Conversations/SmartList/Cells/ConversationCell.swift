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

class ConversationCell: UITableViewCell, NibReusable {

    @IBOutlet weak var fallbackAvatar: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var fallbackAvatarImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var newMessagesIndicator: UIView!
    @IBOutlet weak var newMessagesLabel: UILabel!
    @IBOutlet weak var lastMessageDateLabel: UILabel!
    @IBOutlet weak var lastMessagePreviewLabel: UILabel!
    @IBOutlet weak var presenceIndicator: UIView!

    override func setSelected(_ selected: Bool, animated: Bool) {
        let presenceBGColor = self.presenceIndicator.backgroundColor
        let fallbackAvatarBGColor = self.fallbackAvatar.backgroundColor
        let newMessagesIndicatorBGColor = self.newMessagesIndicator.backgroundColor
        super.setSelected(selected, animated: animated)
        self.newMessagesIndicator.backgroundColor = newMessagesIndicatorBGColor
        self.presenceIndicator.backgroundColor = presenceBGColor
        self.fallbackAvatar.backgroundColor = fallbackAvatarBGColor
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let presenceBGColor = self.presenceIndicator.backgroundColor
        let fallbackAvatarBGColor = self.fallbackAvatar.backgroundColor
        let newMessagesIndicatorBGColor = self.newMessagesIndicator.backgroundColor
        super.setSelected(highlighted, animated: animated)
        self.newMessagesIndicator.backgroundColor = newMessagesIndicatorBGColor
        self.presenceIndicator.backgroundColor = presenceBGColor
        self.fallbackAvatar.backgroundColor = fallbackAvatarBGColor
    }

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        self.disposeBag = DisposeBag()
    }

    func initFromItem(_ item: ConversationSection.Item) {
        item.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        // Avatar placeholder initial
        self.fallbackAvatar.text = nil
        self.fallbackAvatarImage.isHidden = true
        let name = item.userName.value
        let scanner = Scanner(string: name.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            self.fallbackAvatar.isHidden = false
            self.fallbackAvatar.backgroundColor = avatarColors[Int(index)]
            if item.conversation.value.recipientRingId != name {
                self.fallbackAvatar.text = name.prefixString().capitalized
            } else {
                self.fallbackAvatarImage.isHidden = false
            }
        }

        item.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .filter({ [weak item] userName in
                return userName != item?.conversation.value.recipientRingId
            })
            .map { value in value.prefixString().capitalized }
            .bind(to: self.fallbackAvatar.rx.text)
            .disposed(by: self.disposeBag)

        item.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .map { [weak item] userName in userName != item?.conversation.value.recipientRingId }
            .bind(to: self.fallbackAvatarImage.rx.isHidden)
            .disposed(by: self.disposeBag)

        // UIColor that observes "best Id" prefix
        item.userName.asObservable()
            .observeOn(MainScheduler.instance)
            .map { name in
                let scanner = Scanner(string: name.toMD5HexString().prefixString())
                var index: UInt64 = 0
                if scanner.scanHexInt64(&index) {
                    return avatarColors[Int(index)]
                }
                return defaultAvatarColor
            }
            .subscribe(onNext: { backgroundColor in
                self.fallbackAvatar.backgroundColor = backgroundColor
            })
            .disposed(by: self.disposeBag)

        // Set image if any
        if let imageData = item.profileImageData.value {
            if let image = UIImage(data: imageData) {
                self.profileImage.image = image
                self.fallbackAvatar.isHidden = true
            }
        } else {
            self.fallbackAvatar.isHidden = false
            self.profileImage.image = nil
        }

        item.profileImageData.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { data in
                if let imageData = data {
                    if let image = UIImage(data: imageData) {
                        UIView.transition(with: self.profileImage,
                                          duration: 1.0,
                                          options: .transitionCrossDissolve,
                                          animations: {
                                            self.profileImage.image = image
                        }, completion: { _ in
                            self.fallbackAvatar.isHidden = true
                        })
                    }
                } else {
                    self.fallbackAvatar.isHidden = false
                    self.profileImage.image = nil
                }
            }).disposed(by: self.disposeBag)

        self.newMessagesLabel.text = item.unreadMessages
        self.lastMessageDateLabel.text = item.lastMessageReceivedDate
        self.newMessagesIndicator.isHidden = item.hideNewMessagesLabel
        self.lastMessagePreviewLabel.text = item.lastMessage

        item.contactPresence.asObservable()
            .observeOn(MainScheduler.instance)
            .map { value in !value }
            .bind(to: self.presenceIndicator.rx.isHidden)
            .disposed(by: self.disposeBag)
    }
}
