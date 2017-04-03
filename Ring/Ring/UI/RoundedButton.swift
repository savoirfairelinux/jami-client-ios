/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

class RoundedButton: UIButton {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        //Button layout
        self.layer.borderColor = self.backgroundColor?.cgColor
        self.layer.borderWidth = 1.0
        self.clipsToBounds = true
        self.layer.cornerRadius = 15.0
        self.contentEdgeInsets = UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0)

        //Text colors
        self.setTitleColor(UIColor.white, for: .normal)
        self.setTitleColor(UIColor.gray, for: .disabled)
    }
}
