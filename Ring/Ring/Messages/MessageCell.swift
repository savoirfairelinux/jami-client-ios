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

enum BubblePosition {
    case received
    case sent
}

class MessageCell: UITableViewCell {

    @IBOutlet weak var bubble: UIView!
    @IBOutlet weak var messageLabel: UILabel!

    @IBOutlet weak var minimumLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerLeadingConstraint: NSLayoutConstraint!

    @IBOutlet weak var minimumTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerTrailingConstraint: NSLayoutConstraint!

    var bubblePosition = BubblePosition.received {
        didSet {
            if bubblePosition == .sent {
                self.minimumTrailingConstraint.priority = 1
                self.containerTrailingConstraint.priority = 999
                self.containerLeadingConstraint.priority = 1
                self.minimumLeadingConstraint.priority = 999

                self.bubble.backgroundColor = Colors.ringMainColor
                self.messageLabel.textColor = UIColor.white
            } else {
                self.minimumLeadingConstraint.priority = 1
                self.containerLeadingConstraint.priority = 999
                self.containerTrailingConstraint.priority = 1
                self.minimumTrailingConstraint.priority = 999

                self.bubble.backgroundColor = UIColor.lightGray
                self.messageLabel.textColor = UIColor.black
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.bubblePosition = .received
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
