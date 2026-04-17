/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import SwiftUI

extension Color: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue) else {
            self = .black
            return
        }
        do {
            let color = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? UIColor ?? .black
            self = Color(color)
        } catch {
            self = .black
        }
    }
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            red = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
    public func isLight(threshold: Float) -> Bool? {
        let originalCGColor = self.cgColor
        guard let originalCGColor = originalCGColor else { return nil }

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

    public var rawValue: String {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: false) as Data
            return data.base64EncodedString()
        } catch {
            return ""
        }
    }
}

// SwiftUI mirrors of UIColor+Ring. Values live in UIColor+Ring (and the
// asset catalog); this extension only bridges UIColor → Color so both APIs
// expose every constant with the same name.
extension Color {
    static let jami = Color(UIColor.jami)
    static let jamiSecondary = Color(UIColor.jamiSecondary)

    static let jamiButtonPrimary = Color(UIColor.jamiButtonPrimary)
    static let jamiButtonSecondary = Color(UIColor.jamiButtonSecondary)
    static let jamiButtonWithOpacity = Color(UIColor.jamiButtonWithOpacity)

    static let jamiPrimaryControl = Color(UIColor.jamiPrimaryControl)
    static let jamiSecondaryControl = Color(UIColor.jamiSecondaryControl)
    static let jamiTertiaryControl = Color(UIColor.jamiTertiaryControl)

    static let jamiFormBackground = Color(UIColor.jamiFormBackground)

    static let jamiDonation = Color(UIColor.jamiDonation)
    static let jamiRaiseHand = Color(UIColor.jamiRaiseHand)
    static let jamiCallPulse = Color(UIColor.jamiCallPulse)
    static let jamiDefaultAvatar = Color(UIColor.jamiDefaultAvatar)

    static let jamiSuccess = Color(UIColor.jamiSuccess)
    static let jamiFailure = Color(UIColor.jamiFailure)
    static let jamiWarning = Color(UIColor.jamiWarning)

    static let jamiMessageCellSent = Color(UIColor.jamiMessageCellSent)
    static let jamiMessageCellReceived = Color(UIColor.jamiMessageCellReceived)
    static let jamiMessageCellReceivedText = Color(UIColor.jamiMessageCellReceivedText)
    static let jamiMessageCellTimeText = Color(UIColor.jamiMessageCellTimeText)
    static let jamiMessageBackground = Color(UIColor.jamiMessageBackground)
    static let jamiMessageTextFieldBorder = Color(UIColor.jamiMessageTextFieldBorder)
    static let unreadMessageText = Color(UIColor.unreadMessageText)
    static let unreadMessageBackground = Color(UIColor.unreadMessageBackground)

    static let jamiRequestsBackground = Color(UIColor.jamiRequestsBackground)
    static let requestsBadgeForeground = Color(UIColor.requestsBadgeForeground)
    static let requestsBadgeBackground = Color(UIColor.requestsBadgeBackground)

    static let networkAlertBackground = Color(UIColor.networkAlertBackground)

    static let jamiNavigationBarShadow = Color(UIColor.jamiNavigationBarShadow)

    static let defaultSwarmColor = Color(UIColor.defaultSwarmColor)

    static let availablePresence = Color(UIColor.availablePresence)
    static let onlinePresence = Color(UIColor.onlinePresence)
}
