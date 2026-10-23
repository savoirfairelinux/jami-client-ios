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

    func rotatingHue(by degrees: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        let rotated = (hue + degrees / 360).truncatingRemainder(dividingBy: 1)
        return UIColor(hue: rotated < 0 ? rotated + 1 : rotated, saturation: saturation, brightness: brightness, alpha: alpha)
    }

    private struct Oklab {
        var lightness: CGFloat
        var greenRed: CGFloat
        var blueYellow: CGFloat
    }

    private var oklab: Oklab? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = (linear(red), linear(green), linear(blue))
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return Oklab(lightness: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     greenRed: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     blueYellow: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    private convenience init(oklab: Oklab, alpha: CGFloat) {
        let l = pow(oklab.lightness + 0.3963377774 * oklab.greenRed + 0.2158037573 * oklab.blueYellow, 3)
        let m = pow(oklab.lightness - 0.1055613458 * oklab.greenRed - 0.0638541728 * oklab.blueYellow, 3)
        let s = pow(oklab.lightness - 0.0894841775 * oklab.greenRed - 1.2914855480 * oklab.blueYellow, 3)
        func gamma(_ value: CGFloat) -> CGFloat {
            let clamped = min(max(value, 0), 1)
            return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        }
        self.init(red: gamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                  green: gamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                  blue: gamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
                  alpha: alpha)
    }

    func withLightness(of reference: UIColor, chromaScale: CGFloat, alpha: CGFloat) -> UIColor {
        guard let tint = oklab, let target = reference.oklab else { return reference.withAlphaComponent(alpha) }
        return UIColor(oklab: Oklab(lightness: target.lightness,
                                    greenRed: tint.greenRed * chromaScale,
                                    blueYellow: tint.blueYellow * chromaScale),
                       alpha: alpha)
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
    static let jamiOnVideoScrim = UIColor(named: "jamiOnVideoScrim")!
    static let jamiOnVideoGlass = UIColor(named: "jamiOnVideoGlass")!
    static let jamiCallBackdrop = UIColor(named: "jamiCallBackdrop")!
    static let jamiCallCanvas = UIColor(named: "jamiCallCanvas")!

    // MARK: - Status
    static let jamiSuccess = UIColor(hex: 0x00b20b, alpha: 1.0)
    static let jamiFailure = UIColor(hex: 0xf00000, alpha: 1.0)
    static let jamiWarning = UIColor.orange

    // MARK: - Messages
    static let jamiMessageCellSent = UIColor(hex: 0x367BC1, alpha: 1.0)
    static var jamiMessageCellReceived: UIColor {
        return UIColor(named: "backgroundMsgReceived") ?? UIColor(red: 231, green: 235, blue: 235, alpha: 1.0)
    }

    /// Resolves `.systemBlue` / `.white` from bubble background luminance per trait collection.
    static func adaptiveMessageLinkColor(on background: UIColor) -> UIColor {
        UIColor { traitCollection in
            let resolved = background.resolvedColor(with: traitCollection)
            let isLight = resolved.isLight(threshold: 0.8) ?? true
            return isLight ? .systemBlue : .white
        }
    }

    static let jamiMessageCellReceivedText = UIColor(red: 48, green: 48, blue: 48, alpha: 1.0)
    static let messageBubbleReceivedBase = UIColor(named: "messageBubbleReceivedBase")!
    static let messageBubbleHighlight = UIColor(named: "messageBubbleHighlight")!
    static let messageBubbleShade = UIColor(named: "messageBubbleShade")!
    static let jamiMessageCellTimeText = UIColor(red: 128, green: 128, blue: 128, alpha: 1.0)

    static func messageBubbleReceived(tintedWith conversationColor: UIColor) -> UIColor {
        UIColor { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            return conversationColor.withLightness(of: messageBubbleReceivedBase.resolvedColor(with: traitCollection),
                                                   chromaScale: isDark ? 0.3 : 0.35,
                                                   alpha: isDark ? 0.36 : 0.24)
        }
    }

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
