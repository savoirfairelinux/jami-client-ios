/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

class BannedContactCell: UITableViewCell, NibReusable {

    @IBOutlet weak var fallbackAvatar: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var fallbackAvatarImage: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var unblockButton: UIButton!

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        super.prepareForReuse()
        self.disposeBag = DisposeBag()
    }

    func configureFromItem(_ item: BannedContactItem) {
        // avatar
        self.profileImageView.subviews.forEach({ $0.removeFromSuperview() })
        self.profileImageView.addSubview(AvatarView(profileImageData: item.image,
                                                    username: item.displayName ?? (item.contact.userName ?? item.contact.hash),
                                                    size: 40))

        if let displayName = item.displayName {
            self.displayNameLabel.text = displayName
        }

        if let name = item.contact.userName {
            self.userNameLabel.text = name
        } else {
            self.userNameLabel.text = item.contact.hash
        }

        self.unblockButton.titleLabel?.text = L10n.AccountPage.unblockContact
    }
}
