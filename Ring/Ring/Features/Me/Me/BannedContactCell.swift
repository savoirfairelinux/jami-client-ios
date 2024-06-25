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

import Reusable
import RxSwift
import UIKit

class BannedContactCell: UITableViewCell, NibReusable {
    @IBOutlet var fallbackAvatar: UILabel!
    @IBOutlet var profileImageView: UIImageView!
    @IBOutlet var fallbackAvatarImage: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var unblockButton: UIButton!

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

    func configureFromItem(_ item: BannedContactItem) {
        // avatar
        profileImageView.subviews.forEach { $0.removeFromSuperview() }
        profileImageView.addSubview(AvatarView(profileImageData: item.image,
                                               username: item
                                                .displayName ??
                                                (item.contact.userName ?? item.contact.hash),
                                               size: 40))

        if let displayName = item.displayName, !displayName.isEmpty {
            userNameLabel.text = displayName
        } else if let name = item.contact.userName, !name.isEmpty {
            userNameLabel.text = name
        } else {
            userNameLabel.text = item.contact.hash
        }

        unblockButton.titleLabel?.text = L10n.AccountPage.unblockContact
    }
}
