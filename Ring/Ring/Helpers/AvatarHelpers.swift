/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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
import CryptoKit

// MARK: - Avatar Metrics

enum AvatarMetrics {

    struct LayoutPreset {
        let directions: [(x: CGFloat, y: CGFloat)]

        func offsets(margin: CGFloat) -> [(x: CGFloat, y: CGFloat)] {
            directions.enumerated().map { index, dir in
                let radius = (index == 0 ? AvatarMetrics.adminDiameterRatio : AvatarMetrics.secondaryDiameterRatio) / 2
                let dist = 0.5 - radius - margin
                let len = sqrt(dir.x * dir.x + dir.y * dir.y)
                return (x: dist * dir.x / len, y: dist * dir.y / len)
            }
        }
    }

    static let edgeMarginRatio: CGFloat = 0.07
    static let adminDiameterRatio: CGFloat = 0.46
    static let secondaryDiameterRatio: CGFloat = 0.34

    static let twoCircle = LayoutPreset(
        directions: [(-1, -1),
                     ( 1, 1)]
    )
    static let threeCircle = LayoutPreset(
        directions: [(-7, -8),
                     ( 1, 0),
                     (-1, 6)]
    )

    static let shadowOffsetYRatio: CGFloat = 0.015
    static let shadowBlurRatio: CGFloat = shadowOffsetYRatio * 2
    static let shadowAlpha: CGFloat = 0.18

    static let monogramFontRatio: CGFloat = 0.44
    static let iconSizeRatio: CGFloat = 0.40
    static let minMonogramFontSize: CGFloat = 8
    static let maxMonogramFontSize: CGFloat = 50
    static let minIconSize: CGFloat = 6

    static let borderWidth: CGFloat = 1

    static func monogramFontSize(for diameter: CGFloat) -> CGFloat {
        min(max((diameter * monogramFontRatio).rounded(), minMonogramFontSize), maxMonogramFontSize)
    }

    static func iconSize(for diameter: CGFloat) -> CGFloat {
        max((diameter * iconSizeRatio).rounded(), minIconSize)
    }
}

// MARK: - Avatar Background Color

func avatarBackgroundColor(for name: String) -> UIColor {
    let md5Data = Insecure.MD5.hash(data: Data(name.utf8))
    let hex = String(md5Data.map { String(format: "%02hhx", $0) }.joined().prefix(1))
    var idxValue: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&idxValue)
    let colorIndex = Int(idxValue) % avatarColors.count
    return avatarColors[colorIndex]
}

// MARK: - Member Roles

enum MemberRoles {
    static let admin = "admin"
    static let member = "member"
    static let invited = "invited"
    static let banned = "banned"
    static let left = "left"

    static let active: Set<String> = [admin, member, invited]
}

// MARK: - Hash Detection

private let hashRegex = try? NSRegularExpression(pattern: "(ring:)?([0-9a-f]{40})", options: [])

func isJamiHashId(_ string: String) -> Bool {
    return hashRegex?.firstMatch(
        in: string,
        options: .reportCompletion,
        range: NSRange(location: 0, length: string.utf16.count)
    ) != nil
}

// MARK: - UIColor Adjustments

extension UIColor {
    func lighten(by percentage: CGFloat = 30.0) -> UIColor? {
        return self.adjust(by: abs(percentage))
    }

    func darker(by percentage: CGFloat) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage))
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
}
