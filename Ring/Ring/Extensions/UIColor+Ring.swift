/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat) {
        let redFloat = CGFloat(red) / 255.0
        let greenFloat = CGFloat(green) / 255.0
        let blueFloat = CGFloat(blue) / 255.0
        self.init(red: redFloat, green: greenFloat, blue: blueFloat, alpha: alpha)
    }

    convenience init(hex: Int, alpha: CGFloat) {
        self.init(red: (hex >> 16) & 0xff, green: (hex >> 8) & 0xff, blue: hex & 0xff, alpha: alpha)
    }

    func lighten(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage) )
    }

    func darker(by percentage: CGFloat) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage / 100, 1.0),
                           green: min(green + percentage / 100, 1.0),
                           blue: min(blue + percentage / 100, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }
    func isLight(threshold: Float) -> Bool? {
        let originalCGColor = self.cgColor

        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }

    public convenience init?(hexString: String) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if hexString.hasPrefix("#") {
            scanner.currentIndex = hexString.dropFirst().startIndex
        }
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        let mask = 0x000000FF
        let redInt = Int(color >> 16) & mask
        let greenInt = Int(color >> 8) & mask
        let blueInt = Int(color) & mask
        let red = CGFloat(redInt) / 255.0
        let green = CGFloat(greenInt) / 255.0
        let blue = CGFloat(blueInt) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    // MARK: - Brand
    static let jami = UIColor(named: "jami")!
    static let jamiSecondary = UIColor(hex: 0x1F4971, alpha: 1.0)

    // MARK: - Buttons
    static let jamiButtonPrimary = UIColor(named: "jamiButtonPrimary")!
    static let jamiButtonSecondary = UIColor(named: "jamiButtonSecondary")!
    static let jamiButtonWithOpacity = UIColor(named: "jamiButtonWithOpacity")!

    // MARK: - Controls
    static let jamiPrimaryControl = UIColor(named: "jamiPrimaryControl")!
    static let jamiSecondaryControl = UIColor(named: "jamiSecondaryControl")!
    static let jamiTertiaryControl = UIColor(named: "jamiTertiaryControl")!

    // MARK: - Forms
    static let jamiFormBackground = UIColor(named: "jamiFormBackground")!

    // MARK: - Feature accents
    static let jamiDonation = UIColor(red: 255, green: 0, blue: 69, alpha: 1.0)
    static let jamiRaiseHand = UIColor(red: 0, green: 184, blue: 255, alpha: 1.0)
    static let jamiCallPulse = UIColor(hex: 0x039FDF, alpha: 1.0)
    static let jamiDefaultAvatar = UIColor(hex: 0x039FDF, alpha: 1.0)

    // MARK: - Status
    static let jamiSuccess = UIColor(hex: 0x00b20b, alpha: 1.0)
    static let jamiFailure = UIColor(hex: 0xf00000, alpha: 1.0)
    static let jamiWarning = UIColor.orange

    // MARK: - Messages
    static let jamiMessageCellSent = UIColor(hex: 0x367BC1, alpha: 1.0)
    static var jamiMessageCellReceived: UIColor {
        return UIColor(named: "backgroundMsgReceived") ?? UIColor(red: 231, green: 235, blue: 235, alpha: 1.0)
    }
    static let jamiMessageCellReceivedText = UIColor(red: 48, green: 48, blue: 48, alpha: 1.0)
    static let jamiMessageCellTimeText = UIColor(red: 128, green: 128, blue: 128, alpha: 1.0)
    static var jamiMessageBackground: UIColor {
        return UIColor(named: "messageBackgroundColor") ?? UIColor(red: 252, green: 252, blue: 252, alpha: 1.0)
    }
    static let jamiMessageTextFieldBorder = UIColor(red: 220, green: 220, blue: 220, alpha: 1.0)
    static let unreadMessageText = UIColor(hexString: "CC0022")!
    static let unreadMessageBackground = UIColor(hexString: "EED4D8")!

    // MARK: - Requests
    static let jamiRequestsBackground = UIColor(named: "jamiRequestsBackground")!
    static let requestsBadgeForeground = UIColor(named: "requestsBadgeForeground")!
    static let requestsBadgeBackground = UIColor(named: "requestsBadgeBackground")!

    // MARK: - Alerts
    static let networkAlertBackground = UIColor(red: 245, green: 110, blue: 88, alpha: 1)

    // MARK: - Navigation
    static var jamiNavigationBarShadow: UIColor {
        return UIColor(named: "shadowColor") ?? UIColor.black
    }

    // MARK: - Swarm
    static let defaultSwarmColorHex = "#00BCD4"
    static let defaultSwarmColor = UIColor(hexString: "#00BCD4")!

    // MARK: - Presence
    static let availablePresence = UIColor(hexString: "#E59028")!
    static let onlinePresence = UIColor(hexString: "#0B8271")!
}
