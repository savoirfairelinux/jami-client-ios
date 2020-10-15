/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import Reusable

class MessageCellSent: MessageCell {
    //Constraints
    @IBOutlet weak var messageLabelTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var messageLabelLeadingConstraint: NSLayoutConstraint!

    override func applyBubbleStyleToCell(_ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.applyBubbleStyleToCell(items, cellForRowAt: indexPath)
        if (self.messageLabel?.text?.containsOnlyEmoji) ?? false {
            self.messageLabelTrailingConstraint.constant = 0
            self.messageLabelLeadingConstraint.constant = 0
        } else {
            self.messageLabelTrailingConstraint.constant = 14
            self.messageLabelLeadingConstraint.constant = 14
        }
    }
}
