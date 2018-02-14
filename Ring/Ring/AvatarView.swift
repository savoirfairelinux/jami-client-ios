/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

class AvatarView: UIView {

    init(profileImageData: Data?,
         username: String,
         size: CGFloat = 32.0,
         offset: CGPoint = CGPoint(x: 0.0, y: 0.0)) {

        let frame = CGRect(x: 0, y: 0, width: size, height: size)

        super.init(frame: frame)
        self.frame = CGRect(x: 0, y: 0, width: size, height: size)

        let avatarImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        if let imageData = profileImageData, let image = UIImage(data: imageData) {
            (avatarImageView as UIImageView).image = image.circleMasked
            self.addSubview(avatarImageView)
        } else {
            // use fallback avatars
            let scanner = Scanner(string: username.toMD5HexString().prefixString())
            var index: UInt64 = 0
            if scanner.scanHexInt64(&index) {
                let fbaBGColor = avatarColors[Int(index)]
                let circle = UIView(frame: CGRect(x: offset.x, y: offset.y, width: size, height: size))
                circle.center = CGPoint.init(x: size / 2, y: self.center.y)
                circle.layer.cornerRadius = size / 2
                circle.backgroundColor = fbaBGColor
                circle.clipsToBounds = true
                self.addSubview(circle)
                if !username.isSHA1() {
                    // use g-style fallback avatar
                    let initialLabel: UILabel = UILabel.init(frame: CGRect.init(x: offset.x, y: offset.y, width: size, height: size))
                    initialLabel.center = circle.center
                    initialLabel.text = username.prefixString().capitalized
                    initialLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                    initialLabel.textColor = UIColor.white
                    initialLabel.textAlignment = .center
                    self.addSubview(initialLabel)
                } else {
                    // ringId only, so fallback fallback avatar
                    if let image = UIImage(asset: Asset.fallbackAvatar) {
                        (avatarImageView as UIImageView).image = image.circleMasked
                        self.addSubview(avatarImageView)
                    }
                }
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
