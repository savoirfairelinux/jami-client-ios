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

// swiftlint:disable identifier_name
extension UIColor {
    convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat) {
        let red_ = CGFloat(red) / 255.0
        let green_ = CGFloat(green) / 255.0
        let blue_ = CGFloat(blue) / 255.0
        self.init(red: red_, green: green_, blue: blue_, alpha: alpha)
    }

    convenience init(hex: Int, alpha: CGFloat) {
        self.init(red: (hex >> 16) & 0xFF, green: (hex >> 8) & 0xFF, blue: hex & 0xFF, alpha: alpha)
    }

    func lighten(by percentage: CGFloat = 30.0) -> UIColor? {
        return adjust(by: abs(percentage))
    }

    func darker(by percentage: CGFloat) -> UIColor? {
        return adjust(by: -1 * abs(percentage))
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage / 100, 1.0),
                           green: min(green + percentage / 100, 1.0),
                           blue: min(blue + percentage / 100, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }

    func isLight(threshold: Float) -> Bool? {
        let originalCGColor = cgColor

        let RGBCGColor = originalCGColor.converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        )
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness =
            Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return brightness > threshold
    }

    public convenience init?(hexString: String) {
        let hexString: String = hexString
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if hexString.hasPrefix("#") {
            scanner.currentIndex = hexString.dropFirst().startIndex
        }
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        let mask = 0x0000_00FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue = CGFloat(b) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    static let jamiMain = UIColor(red: 0, green: 86, blue: 153, alpha: 1.0)
    static let jamiDonation = UIColor(red: 255, green: 0, blue: 69, alpha: 1.0)
    static let conferenceRaiseHand = UIColor(red: 0, green: 184, blue: 255, alpha: 1.0)
    static let jamiSecondary = UIColor(hex: 0x1F4971, alpha: 1.0)
    static let jamiButtonLight = UIColor(named: "jamiButtonLight")!
    static let jamiButtonDark = UIColor(named: "jamiButtonDark")!
    static let jamiButtonWithOpacity = UIColor(named: "jamiButtonWithOpacity")!
    static let jamiFormBackgroundColor = UIColor(named: "jamiFormBackgroundColor")!
    static let jamiMsgCellSent = UIColor(hex: 0x367BC1, alpha: 1.0)
    static var jamiMsgCellReceived: UIColor {
        return UIColor(named: "background_msg_received") ??
            UIColor(red: 231, green: 235, blue: 235, alpha: 1.0)
    }

    static var jamiTextBlue: UIColor {
        return UIColor(named: "text_blue_color") ??
            UIColor(red: 231, green: 235, blue: 235, alpha: 1.0)
    }

    static var jamiTextSecondary: UIColor {
        return UIColor(named: "text_secondary_color") ??
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
    }

    static var jamiInputTextBackground: UIColor {
        return UIColor(named: "background_input_text") ??
            UIColor(red: 255, green: 255, blue: 255, alpha: 0.57)
    }

    static let jamiMsgCellReceivedText = UIColor(red: 48, green: 48, blue: 48, alpha: 1.0)
    static let jamiMsgCellTimeText = UIColor(red: 128, green: 128, blue: 128, alpha: 1.0)

    static var jamiMsgBackground: UIColor {
        return UIColor(named: "message_background_color") ??
            UIColor(red: 252, green: 252, blue: 252, alpha: 1.0)
    }

    static var jamiMsgTextFieldBackground: UIColor {
        return UIColor(named: "text_field_background_color") ??
            UIColor(red: 252, green: 252, blue: 252, alpha: 0)
    }

    static let jamiMsgTextFieldBorder = UIColor(red: 220, green: 220, blue: 220, alpha: 1.0)
    static var jamiUITableViewCellSelection: UIColor {
        return UIColor(named: "row_selected") ??
            UIColor(red: 209, green: 210, blue: 210, alpha: 1.0)
    }

    static var jamiNavigationBarShadow: UIColor {
        return UIColor(named: "shadow_color") ?? UIColor.black
    }

    static var jamiBackgroundColor: UIColor {
        return UIColor.systemBackground
    }

    static var jamiBackgroundSecondaryColor: UIColor {
        return UIColor.secondarySystemBackground
    }

    static var jamiLabelColor: UIColor {
        return UIColor.label
    }

    static let jamiCallPulse = UIColor(hex: 0x039FDF, alpha: 1.0)
    static let jamiDefaultAvatar = UIColor(hex: 0x039FDF, alpha: 1.0)
    static let jamiSuccess = UIColor(hex: 0x00B20B, alpha: 1.0)
    static let jamiFailure = UIColor(hex: 0xF00000, alpha: 1.0)
    static let jamiWarning = UIColor.orange

    static let defaultSwarm = "#00BCD4"
    static let defaultSwarmColor = UIColor(hexString: "#00BCD4")!
    static let availablePresenceColor = UIColor(hexString: "#E59028")!
    static let onlinePresenceColor = UIColor(hexString: "#0B8271")!
}
