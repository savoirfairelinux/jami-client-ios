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
import Reusable
import RxSwift

class ContactRequestCell: UITableViewCell, NibReusable {

    @IBOutlet weak var fallbackAvatar: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var discardButton: UIButton!
    @IBOutlet weak var banButton: UIButton!

    override func setSelected(_ selected: Bool, animated: Bool) {
        let fallbackAvatarBGColor = self.fallbackAvatar.backgroundColor
        super.setSelected(selected, animated: animated)
        self.fallbackAvatar.backgroundColor = fallbackAvatarBGColor
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let fallbackAvatarBGColor = self.fallbackAvatar.backgroundColor
        super.setSelected(highlighted, animated: animated)
        self.fallbackAvatar.backgroundColor = fallbackAvatarBGColor
    }

    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        self.disposeBag = DisposeBag()
    }
}
