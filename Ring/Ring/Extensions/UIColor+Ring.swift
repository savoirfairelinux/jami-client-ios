/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

import Foundation
import UIKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat) {
        let red_ = CGFloat(red) / 255.0
        let green_ = CGFloat(green) / 255.0
        let blue_ = CGFloat(blue) / 255.0
        self.init(red: red_, green: green_, blue: blue_, alpha: alpha)
    }

    static let ringMain = UIColor(red: 58, green: 192, blue: 210, alpha: 1.0)
    static let ringSecondary = UIColor(red: 0, green: 76, blue: 96, alpha: 1.0)
    static let ringMsgCellSent = UIColor(red: 58, green: 192, blue: 210, alpha: 1.0)
    static let ringMsgCellSentText = UIColor(red: 255, green: 255, blue: 255, alpha: 1.0)
    static let ringMsgCellReceived = UIColor(red: 235, green: 239, blue: 239, alpha: 1.0)
    static let ringMsgCellReceivedText = UIColor(red: 48, green: 48, blue: 48, alpha: 1.0)
    static let ringMsgCellTimeText = UIColor(red: 128, green: 128, blue: 128, alpha: 1.0)
    static let ringUITableViewCellSelection = UIColor(red: 209, green: 210, blue: 210, alpha: 1.0)
    static let ringNavigationBar = UIColor(red: 235, green: 235, blue: 235, alpha: 1.0)
}
