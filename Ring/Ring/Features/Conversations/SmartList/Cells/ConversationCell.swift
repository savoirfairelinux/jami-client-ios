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
}
