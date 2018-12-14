/*
 *  Copyright (C) 2017-2018 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

import Foundation
import UIKit

// swiftlint:disable identifier_name
extension UIColor {
    convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat) {
        let red_ = CGFloat(red) / 255.0
        let green_ = CGFloat(green) / 255.0
        let blue_ = CGFloat(blue) / 255.0
        self.init(red: red_, green: green_, blue: blue_, alpha: alpha)
    }

    convenience init(hex: Int, alpha: CGFloat) {
        self.init(red: (hex >> 16) & 0xff, green: (hex >> 8) & 0xff, blue: hex & 0xff, alpha: alpha)
    }

    static let jamiMain = UIColor(hex: 0x3F6DA7, alpha: 1.0)
    static let jamiSecondary = UIColor(hex: 0x1F4971, alpha: 1.0)
    static let jamiButtonLight = UIColor(hex: 0x285F97, alpha: 1.0)
    static let jamiButtonDark = UIColor(hex: 0x0F2643, alpha: 1.0)
    static let jamiMsgCellEmoji = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
    static let jamiMsgCellSent = UIColor(hex: 0x367BC1, alpha: 1.0)
    static let jamiMsgCellSentText = UIColor(red: 255, green: 255, blue: 255, alpha: 1.0)
    static let jamiMsgCellReceived = UIColor(red: 231, green: 235, blue: 235, alpha: 1.0)
    static let jamiMsgCellReceivedText = UIColor(red: 48, green: 48, blue: 48, alpha: 1.0)
    static let jamiMsgCellTimeText = UIColor(red: 128, green: 128, blue: 128, alpha: 1.0)
    static let jamiMsgBackground = UIColor(red: 252, green: 252, blue: 252, alpha: 1.0)
    static let jamiMsgTextFieldBackground = UIColor(red: 252, green: 252, blue: 252, alpha: 0)
    static let jamiMsgTextFieldBorder = UIColor(red: 220, green: 220, blue: 220, alpha: 1.0)
    static let jamiUITableViewCellSelection = UIColor(red: 209, green: 210, blue: 210, alpha: 1.0)
    static let jamiNavigationBar = UIColor(red: 235, green: 235, blue: 235, alpha: 1.0)
    static let jamiCallPulse = UIColor(hex: 0x039FDF, alpha: 1.0)
    static let jamiDefaultAvatar = UIColor(hex: 0x039FDF, alpha: 1.0)
    static let jamiSuccess = UIColor(hex: 0x00b20b, alpha: 1.0)
    static let jamiFailure = UIColor(hex: 0xf00000, alpha: 1.0)
    static let jamiWarning = UIColor.orange
}
