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

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var newMessagesIndicator: UIView?
    @IBOutlet weak var newMessagesLabel: UILabel?
    @IBOutlet weak var lastMessageDateLabel: UILabel?
    @IBOutlet weak var lastMessagePreviewLabel: UILabel?
    @IBOutlet weak var presenceIndicator: UIView?

    var avatarSize: CGFloat { return 40 }

    override func setSelected(_ selected: Bool, animated: Bool) {
        self.backgroundColor = UIColor.jamiUITableViewCellSelection
        UIView.animate(withDuration: 0.35, animations: {
            self.backgroundColor = UIColor.jamiUITableViewCellSelection.lighten(by: 5.0)
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
        self.disposeBag = DisposeBag()
    }

    func configureFromItem(_ item: ConversationSection.Item) {
        // avatar
        Observable<(Data?, String)>.combineLatest(item.profileImageData.asObservable(),
                                                  item.userName.asObservable(),
                                                  item.displayName.asObservable()) { profileImage, username, displayName in
                                                    if let displayName = displayName, !displayName.isEmpty {
                                                        return (profileImage, displayName)
                                                    }
                                                    return (profileImage, username)
        }
            .observeOn(MainScheduler.instance)
            .startWith((item.profileImageData.value, item.userName.value))
            .subscribe({ [weak self] profileData -> Void in
                guard let data = profileData.element?.1 else {
                    return
                }
                self?.avatarView.subviews.forEach({ $0.removeFromSuperview() })
                self?.avatarView
                    .addSubview(
                        AvatarView(profileImageData: profileData.element?.0,
                                   username: data,
                                   size: self?.avatarSize ?? 40))
                return
            })
            .disposed(by: self.disposeBag)

        // unread messages
        self.newMessagesLabel?.text = item.unreadMessages
        self.newMessagesIndicator?.isHidden = item.hideNewMessagesLabel

        // presence
        if self.presenceIndicator != nil {
        item.contactPresence.asObservable()
            .observeOn(MainScheduler.instance)
            .map { value in !value }
            .bind(to: self.presenceIndicator!.rx.isHidden)
            .disposed(by: self.disposeBag)
            }

        // username
        item.bestName.asObservable()
            .observeOn(MainScheduler.instance)
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.nameLabel.lineBreakMode = .byTruncatingTail

        // last message date
        self.lastMessageDateLabel?.text = item.lastMessageReceivedDate

        // last message preview
        self.lastMessagePreviewLabel?.text = item.lastMessage
        self.lastMessagePreviewLabel?.lineBreakMode = .byTruncatingTail

        self.selectionStyle = .none
    }
}
