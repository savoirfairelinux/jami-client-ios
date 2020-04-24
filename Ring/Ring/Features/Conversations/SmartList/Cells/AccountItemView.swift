/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

class AccountItemView: UIView {

    @IBOutlet var containerView: UIView!
    @IBOutlet weak var avatarView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var needMigrateLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.commonInit()
    }

    func commonInit() {
        Bundle.main.loadNibNamed("AccountItemView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = self.bounds
        needMigrateLabel.text = L10n.Account.needMigration
        nameLabel.textColor = UIColor.jamiLabelColor
    }
}
