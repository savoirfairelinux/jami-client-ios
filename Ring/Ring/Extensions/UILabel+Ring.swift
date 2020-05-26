/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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

extension UILabel {
    func setTextWithLineSpacing(withText: String, withLineSpacing: CGFloat) {
        let attrString = NSMutableAttributedString(string: withText)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = withLineSpacing
        attrString.addAttribute(NSAttributedString.Key.paragraphStyle,
                                value: style,
                                range: NSRange(location: 0, length: withText.utf16.count))
        self.attributedText = attrString
    }

    func ajustToTextSize() {
        self.minimumScaleFactor = 0.5
        self.numberOfLines = 0
        self.adjustsFontSizeToFitWidth = true
        self.textAlignment = .center
        self.lineBreakMode = .byWordWrapping
    }
}
