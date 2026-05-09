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

struct GroupAvatarMember: Equatable {
    let image: UIImage?
    let name: String

    static func resolve(profilePhoto: String?, profileName: String?,
                        registeredName: String?, jamiId: String) -> GroupAvatarMember {
        let image: UIImage?
        if let photo = profilePhoto, !photo.isEmpty,
           let data = Data(base64Encoded: photo, options: .ignoreUnknownCharacters) {
            image = UIImage(data: data)
        } else {
            image = nil
        }

        let name: String
        if let profileName = profileName, !profileName.isEmpty {
            name = profileName
        } else if let registeredName = registeredName, !registeredName.isEmpty {
            name = registeredName
        } else {
            name = jamiId
        }

        return GroupAvatarMember(image: image, name: name)
    }
}

enum GroupAvatarRenderer {

    static func render(members: [GroupAvatarMember], overflowCount: Int = 0,
                       totalSize: CGFloat) -> UIImage {
        guard !members.isEmpty else {
            return renderEmptyGroupIcon(totalSize: totalSize)
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        return renderer.image { ctx in
            let context = ctx.cgContext
            let bounds = CGRect(x: 0, y: 0, width: totalSize, height: totalSize)
            let center = CGPoint(x: totalSize / 2, y: totalSize / 2)

            context.saveGState()
            UIBezierPath(ovalIn: bounds).addClip()

            if members.count == 1 && overflowCount == 0 {
                drawMemberCircle(in: context, member: members[0],
                                 center: center, diameter: totalSize,
                                 shadowRadius: 0, shadowY: 0)
            } else {
                drawBackgroundGradient(in: context, center: center, radius: totalSize / 2)
                drawMultiMemberLayout(in: context, center: center, totalSize: totalSize,
                                      members: members, overflow: overflowCount)
            }

            context.restoreGState()
        }
    }

    // MARK: - Drawing

    private static func drawBackgroundGradient(in context: CGContext, center: CGPoint, radius: CGFloat) {
        let baseColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.systemGray6.lighten(by: 2) ?? .systemGray6
                : UIColor.systemGray6.darker(by: 2) ?? .systemGray6
        }
        let centerColor = baseColor.lighten(by: 1) ?? baseColor
        let edgeColor = baseColor.darker(by: 2) ?? baseColor
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace,
                                     colors: [centerColor.cgColor, edgeColor.cgColor] as CFArray,
                                     locations: [0, 1]) {
            context.drawRadialGradient(gradient,
                                       startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: radius,
                                       options: .drawsAfterEndLocation)
        }
    }

    private static func drawMultiMemberLayout(in context: CGContext, center: CGPoint, totalSize: CGFloat,
                                              members: [GroupAvatarMember], overflow: Int) {
        let count = members.count
        let hasThird = count > 2 || overflow > 0
        let preset = hasThird ? AvatarMetrics.threeCircle : AvatarMetrics.twoCircle
        let adminSize = totalSize * AvatarMetrics.adminDiameterRatio
        let otherSize = totalSize * AvatarMetrics.secondaryDiameterRatio
        let shadowRadius = totalSize * AvatarMetrics.shadowBlurRatio
        let shadowY = totalSize * AvatarMetrics.shadowOffsetYRatio

        let offsets = preset.offsets(margin: AvatarMetrics.edgeMarginRatio)
            .map { (x: totalSize * $0.x, y: totalSize * $0.y) }

        if hasThird {
            let pos = CGPoint(x: center.x + offsets[2].x, y: center.y + offsets[2].y)
            if overflow > 0 {
                drawOverflowBadge(in: context, center: pos, size: otherSize,
                                  count: overflow, shadowRadius: shadowRadius, shadowY: shadowY)
            } else if count > 2 {
                drawMemberCircle(in: context, member: members[2],
                                 center: pos, diameter: otherSize,
                                 shadowRadius: shadowRadius, shadowY: shadowY)
            }
        }

        if count > 1 {
            let pos = CGPoint(x: center.x + offsets[1].x, y: center.y + offsets[1].y)
            drawMemberCircle(in: context, member: members[1],
                             center: pos, diameter: otherSize,
                             shadowRadius: shadowRadius, shadowY: shadowY)
        }

        let pos0 = CGPoint(x: center.x + offsets[0].x, y: center.y + offsets[0].y)
        drawMemberCircle(in: context, member: members[0],
                         center: pos0, diameter: adminSize,
                         shadowRadius: shadowRadius, shadowY: shadowY)
    }

    private static func drawMemberCircle(in context: CGContext, member: GroupAvatarMember,
                                         center: CGPoint, diameter: CGFloat,
                                         shadowRadius: CGFloat, shadowY: CGFloat) {
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                          width: diameter, height: diameter)
        let path = UIBezierPath(ovalIn: rect)

        context.saveGState()
        if shadowRadius > 0 {
            context.setShadow(offset: CGSize(width: 0, height: shadowY), blur: shadowRadius,
                              color: UIColor.black.withAlphaComponent(AvatarMetrics.shadowAlpha).cgColor)
        }

        if let avatarImage = member.image {
            drawPhotoCircle(in: context, image: avatarImage, rect: rect, path: path)
        } else {
            drawMonogramCircle(in: context, name: member.name, center: center,
                               diameter: diameter, rect: rect)
        }
        context.restoreGState()
    }

    private static func drawPhotoCircle(in context: CGContext, image: UIImage,
                                        rect: CGRect, path: UIBezierPath) {
        UIColor.white.setFill()
        path.fill()
        context.setShadow(offset: .zero, blur: 0)
        context.saveGState()
        path.addClip()
        image.draw(in: rect)
        context.restoreGState()
    }

    private static func drawMonogramCircle(in context: CGContext, name: String,
                                           center: CGPoint, diameter: CGFloat, rect: CGRect) {
        let bgColor = avatarBackgroundColor(for: name)

        let inset = AvatarMetrics.borderWidth / 2
        let insetRect = rect.insetBy(dx: inset, dy: inset)
        let insetPath = UIBezierPath(ovalIn: insetRect)

        bgColor.setFill()
        insetPath.fill()
        context.setShadow(offset: .zero, blur: 0)

        if let borderColor = bgColor.darker(by: 1) {
            borderColor.setStroke()
            insetPath.lineWidth = AvatarMetrics.borderWidth
            insetPath.stroke()
        }

        if !isJamiHashId(name) && !name.isEmpty {
            let fontSize = AvatarMetrics.monogramFontSize(for: diameter)
            let letter = String(name.prefix(1)).uppercased()
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let textSize = letter.size(withAttributes: attrs)
            letter.draw(at: CGPoint(x: center.x - textSize.width / 2,
                                    y: center.y - textSize.height / 2),
                        withAttributes: attrs)
        } else {
            let iconSize = AvatarMetrics.iconSize(for: diameter)
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
            if let icon = UIImage(systemName: "person.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(x: center.x - icon.size.width / 2,
                                      y: center.y - icon.size.height / 2))
            }
        }
    }

    private static func drawOverflowBadge(in context: CGContext, center: CGPoint, size: CGFloat,
                                          count: Int, shadowRadius: CGFloat, shadowY: CGFloat) {
        let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        let path = UIBezierPath(ovalIn: rect)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: shadowY), blur: shadowRadius,
                          color: UIColor.black.withAlphaComponent(AvatarMetrics.shadowAlpha).cgColor)
        UIColor.systemGray3.setFill()
        path.fill()
        context.setShadow(offset: .zero, blur: 0)

        let text = "+\(count)"
        let font = UIFont.systemFont(ofSize: AvatarMetrics.monogramFontSize(for: size), weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: center.x - textSize.width / 2,
                              y: center.y - textSize.height / 2),
                  withAttributes: attrs)
        context.restoreGState()
    }

    private static func renderEmptyGroupIcon(totalSize: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        return renderer.image { _ in
            let bounds = CGRect(x: 0, y: 0, width: totalSize, height: totalSize)
            let center = CGPoint(x: totalSize / 2, y: totalSize / 2)
            let path = UIBezierPath(ovalIn: bounds)

            avatarColors[0].setFill()
            path.fill()
            if let borderColor = avatarColors[0].darker(by: 1) {
                borderColor.setStroke()
                path.lineWidth = AvatarMetrics.borderWidth
                path.stroke()
            }

            let config = UIImage.SymbolConfiguration(pointSize: AvatarMetrics.iconSize(for: totalSize), weight: .semibold)
            if let icon = UIImage(systemName: "person.2.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(at: CGPoint(x: center.x - icon.size.width / 2,
                                      y: center.y - icon.size.height / 2))
            }
        }
    }
}
