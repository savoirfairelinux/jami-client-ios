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
import simd
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

    private static func linearized(_ component: CGFloat) -> CGFloat {
        component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }

    private var relativeLuminance: CGFloat? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return 0.2126 * Self.linearized(red) + 0.7152 * Self.linearized(green) + 0.0722 * Self.linearized(blue)
    }

    func contrastRatio(with other: UIColor) -> CGFloat {
        guard let first = relativeLuminance, let second = other.relativeLuminance else { return 1 }
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private var screenLuminance: CGFloat? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        let luminance = 0.2126729 * pow(max(red, 0), 2.4) + 0.7151522 * pow(max(green, 0), 2.4) + 0.0721750 * pow(max(blue, 0), 2.4)
        return luminance < 0.022 ? luminance + pow(0.022 - luminance, 1.414) : luminance
    }

    private func lightnessContrast(ofText text: UIColor) -> CGFloat {
        guard let background = screenLuminance, let foreground = text.screenLuminance else { return 0 }
        let contrast = background > foreground
            ? pow(background, 0.56) - pow(foreground, 0.57)
            : pow(background, 0.65) - pow(foreground, 0.62)
        return abs(contrast) * 1.14
    }

    func mixed(with other: UIColor, fraction: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        var otherRed: CGFloat = 0, otherGreen: CGFloat = 0, otherBlue: CGFloat = 0, otherAlpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              other.getRed(&otherRed, green: &otherGreen, blue: &otherBlue, alpha: &otherAlpha) else { return self }
        return UIColor(red: red + (otherRed - red) * fraction,
                       green: green + (otherGreen - green) * fraction,
                       blue: blue + (otherBlue - blue) * fraction,
                       alpha: alpha + (otherAlpha - alpha) * fraction)
    }

    private func composited(over background: UIColor) -> UIColor {
        UIColor.resolvedPerStyle { traitCollection in
            self.resolvedColor(with: traitCollection).blended(over: background.resolvedColor(with: traitCollection))
        }
    }

    private func blended(over background: UIColor) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        var backRed: CGFloat = 0, backGreen: CGFloat = 0, backBlue: CGFloat = 0, backAlpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              background.getRed(&backRed, green: &backGreen, blue: &backBlue, alpha: &backAlpha) else { return self }
        let outAlpha = alpha + backAlpha * (1 - alpha)
        guard outAlpha > 0 else { return .clear }
        func blend(_ front: CGFloat, _ back: CGFloat) -> CGFloat {
            (front * alpha + back * backAlpha * (1 - alpha)) / outAlpha
        }
        return UIColor(red: blend(red, backRed), green: blend(green, backGreen), blue: blend(blue, backBlue), alpha: outAlpha)
    }

    private var chroma: CGFloat {
        OklabColor(self)?.chroma ?? 0
    }

    func rotatingHue(by degrees: CGFloat) -> UIColor {
        OklabColor(self)?.rotatingHue(by: degrees).uiColor ?? self
    }

    func withLightness(of reference: UIColor, chromaScale: CGFloat) -> UIColor {
        guard let tint = OklabColor(self), let target = OklabColor(reference) else { return reference }
        return OklabColor(lightness: target.lightness,
                          greenRed: tint.greenRed * chromaScale,
                          blueYellow: tint.blueYellow * chromaScale,
                          alpha: target.alpha).uiColor
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
    static let conversationSecondaryText = UIColor(named: "conversationSecondaryText")!
    static let messageTextDark = UIColor(named: "messageTextDark")!
    static let jamiMessageCellTimeText = UIColor(red: 128, green: 128, blue: 128, alpha: 1.0)

    private static func messageBubbleReceived(tintedWith conversationColor: UIColor) -> UIColor {
        resolvedPerStyle { traitCollection in
            conversationColor.withLightness(of: messageBubbleReceivedBase.resolvedColor(with: traitCollection),
                                            chromaScale: traitCollection.userInterfaceStyle == .dark ? 0.3 : 0.35)
        }
    }

    private static func resolvedPerStyle(_ resolve: (UITraitCollection) -> UIColor) -> UIColor {
        let light = resolve(UITraitCollection(userInterfaceStyle: .light))
        let dark = resolve(UITraitCollection(userInterfaceStyle: .dark))
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }

    private static func messageBubbleSent(for conversationColor: UIColor) -> UIColor {
        resolvedPerStyle { traitCollection in
            let screen = UIColor.systemBackground.resolvedColor(with: traitCollection)
            let away: UIColor = traitCollection.userInterfaceStyle == .dark ? .white : .black
            var bubble = conversationColor
            for _ in 0..<50 where bubble.contrastRatio(with: screen) < 1.2 {
                bubble = bubble.mixed(with: away, fraction: 0.04)
            }
            return bubble
        }
    }

    private static let whiteTextMinimumLead: CGFloat = 0.08

    private static func messageTextSent(on sentBubble: UIColor) -> UIColor {
        resolvedPerStyle { traitCollection in
            let bubble = sentBubble.resolvedColor(with: traitCollection)
            let dark = messageTextDark.resolvedColor(with: traitCollection)
            let whiteContrast = bubble.lightnessContrast(ofText: .white)
            let darkContrast = bubble.lightnessContrast(ofText: dark)
            return whiteContrast >= darkContrast + whiteTextMinimumLead ? .white : dark
        }
    }

    private static let tintableMinimumChroma: CGFloat = 0.03
    private static let tintableMinimumContrast: CGFloat = 1.5

    private static func isTintable(_ conversationColor: UIColor, with traitCollection: UITraitCollection) -> Bool {
        let screen = UIColor.systemBackground.resolvedColor(with: traitCollection)
        return conversationColor.chroma >= tintableMinimumChroma && conversationColor.contrastRatio(with: screen) >= tintableMinimumContrast
    }

    private static func messagePlaybackTint(for conversationColor: UIColor) -> UIColor {
        resolvedPerStyle { traitCollection in
            isTintable(conversationColor, with: traitCollection) ? conversationColor : UIColor.label.resolvedColor(with: traitCollection)
        }
    }

    private static let darkControlContrast: CGFloat = 4.5
    private static let untintedControlOpacity: CGFloat = 0.7
    private static let controlShadeStep: CGFloat = 0.04
    private static let controlShadeMaximumSteps = 50

    private static func messageControl(matching text: UIColor, conversationColor: UIColor, on bubble: UIColor) -> UIColor {
        resolvedPerStyle { traitCollection in
            let resolvedText = text.resolvedColor(with: traitCollection)
            guard !(resolvedText.isLight(threshold: 0.5) ?? false) else { return resolvedText }
            guard isTintable(conversationColor, with: traitCollection) else {
                return resolvedText.withAlphaComponent(untintedControlOpacity)
            }
            let background = bubble.resolvedColor(with: traitCollection)
            var shade = conversationColor
            for _ in 0..<controlShadeMaximumSteps where shade.contrastRatio(with: background) < darkControlContrast {
                shade = shade.mixed(with: .black, fraction: controlShadeStep)
            }
            return shade
        }
    }

    private static let lightTextProgressOpacity: CGFloat = 0.3
    private static let darkTextProgressOpacity: CGFloat = 0.12

    private static func messagePlaybackProgressSent(matching text: UIColor) -> UIColor {
        resolvedPerStyle { traitCollection in
            let resolvedText = text.resolvedColor(with: traitCollection)
            let isLightText = resolvedText.isLight(threshold: 0.5) ?? false
            return resolvedText.withAlphaComponent(isLightText ? lightTextProgressOpacity : darkTextProgressOpacity)
        }
    }

    private func withAlphaComponent(_ alpha: CGFloat, dark darkAlpha: CGFloat) -> UIColor {
        UIColor.resolvedPerStyle { traitCollection in
            self.resolvedColor(with: traitCollection)
                .withAlphaComponent(traitCollection.userInterfaceStyle == .dark ? darkAlpha : alpha)
        }
    }

    private func multiplyingAlpha(by factor: CGFloat) -> UIColor {
        UIColor.resolvedPerStyle { traitCollection in
            let resolved = self.resolvedColor(with: traitCollection)
            return resolved.withAlphaComponent(resolved.cgColor.alpha * factor)
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

extension UIColor {
    final class MessageBubblePalette {
        let receivedBackground: UIColor
        let receivedContrastBackground: UIColor
        let receivedControl: UIColor
        let receivedPlaybackControl: UIColor
        let receivedPlaybackProgress: UIColor
        let sentBackground: UIColor
        let sentText: UIColor
        let sentControl: UIColor
        let sentPlaybackControl: UIColor
        let sentPlaybackProgress: UIColor
        let sentTime: UIColor

        private static let receivedPlaybackControlOpacity: (light: CGFloat, dark: CGFloat) = (0.22, 0.32)
        private static let receivedPlaybackProgressOpacity: (light: CGFloat, dark: CGFloat) = (0.16, 0.24)
        private static let sentPlaybackControlOpacity: CGFloat = 0.15
        private static let sentTimeOpacity: CGFloat = 0.7

        private static let cache = NSCache<UIColor, MessageBubblePalette>()

        static func palette(for conversationColor: UIColor) -> MessageBubblePalette {
            if let palette = cache.object(forKey: conversationColor) {
                return palette
            }
            let palette = MessageBubblePalette(conversationColor: conversationColor)
            cache.setObject(palette, forKey: conversationColor)
            return palette
        }

        private init(conversationColor: UIColor) {
            let playbackTint = UIColor.messagePlaybackTint(for: conversationColor)
            receivedBackground = .messageBubbleReceived(tintedWith: conversationColor)
            receivedContrastBackground = receivedBackground.composited(over: .systemBackground)
            receivedControl = .messageControl(matching: .label, conversationColor: conversationColor, on: receivedContrastBackground)
            receivedPlaybackControl = playbackTint.withAlphaComponent(Self.receivedPlaybackControlOpacity.light,
                                                                      dark: Self.receivedPlaybackControlOpacity.dark)
            receivedPlaybackProgress = playbackTint.withAlphaComponent(Self.receivedPlaybackProgressOpacity.light,
                                                                       dark: Self.receivedPlaybackProgressOpacity.dark)
            sentBackground = .messageBubbleSent(for: conversationColor)
            sentText = .messageTextSent(on: sentBackground)
            sentControl = .messageControl(matching: sentText, conversationColor: conversationColor, on: sentBackground)
            sentPlaybackControl = sentControl.multiplyingAlpha(by: Self.sentPlaybackControlOpacity)
            sentPlaybackProgress = .messagePlaybackProgressSent(matching: sentText)
            sentTime = sentText.multiplyingAlpha(by: Self.sentTimeOpacity)
        }
    }
}

struct OklabColor {
    var lightness: CGFloat
    var greenRed: CGFloat
    var blueYellow: CGFloat
    var alpha: CGFloat

    private static let linearSRGBToLMS = simd_double3x3(rows: [
        simd_double3(0.4122214708, 0.5363325363, 0.0514459929),
        simd_double3(0.2119034982, 0.6806995451, 0.1073969566),
        simd_double3(0.0883024619, 0.2817188376, 0.6299787005)
    ])

    private static let lmsToOklab = simd_double3x3(rows: [
        simd_double3(0.2104542553, 0.7936177850, -0.0040720468),
        simd_double3(1.9779984951, -2.4285922050, 0.4505937099),
        simd_double3(0.0259040371, 0.7827717662, -0.8086757660)
    ])

    private static let oklabToLMS = simd_double3x3(rows: [
        simd_double3(1, 0.3963377774, 0.2158037573),
        simd_double3(1, -0.1055613458, -0.0638541728),
        simd_double3(1, -0.0894841775, -1.2914855480)
    ])

    private static let lmsToLinearSRGB = simd_double3x3(rows: [
        simd_double3(4.0767416621, -3.3077115913, 0.2309699292),
        simd_double3(-1.2684380046, 2.6097574011, -0.3413193965),
        simd_double3(-0.0041960863, -0.7034186147, 1.7076147010)
    ])

    var chroma: CGFloat {
        hypot(greenRed, blueYellow)
    }

    init(lightness: CGFloat, greenRed: CGFloat, blueYellow: CGFloat, alpha: CGFloat) {
        self.lightness = lightness
        self.greenRed = greenRed
        self.blueYellow = blueYellow
        self.alpha = alpha
    }

    init?(_ color: UIColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        let linearRGB = simd_double3(Self.sRGBToLinear(red), Self.sRGBToLinear(green), Self.sRGBToLinear(blue))
        let lms = Self.linearSRGBToLMS * linearRGB
        let oklab = Self.lmsToOklab * simd_double3(cbrt(lms.x), cbrt(lms.y), cbrt(lms.z))
        self.init(lightness: oklab.x, greenRed: oklab.y, blueYellow: oklab.z, alpha: alpha)
    }

    var uiColor: UIColor {
        let lmsRoot = Self.oklabToLMS * simd_double3(lightness, greenRed, blueYellow)
        let linearRGB = Self.lmsToLinearSRGB * (lmsRoot * lmsRoot * lmsRoot)
        return UIColor(red: Self.linearToSRGB(linearRGB.x),
                       green: Self.linearToSRGB(linearRGB.y),
                       blue: Self.linearToSRGB(linearRGB.z),
                       alpha: alpha)
    }

    func rotatingHue(by degrees: CGFloat) -> OklabColor {
        let angle = degrees * .pi / 180
        return OklabColor(lightness: lightness,
                          greenRed: greenRed * cos(angle) - blueYellow * sin(angle),
                          blueYellow: greenRed * sin(angle) + blueYellow * cos(angle),
                          alpha: alpha)
    }

    private static func sRGBToLinear(_ component: Double) -> Double {
        component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ component: Double) -> Double {
        let clamped = min(max(component, 0), 1)
        return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}
