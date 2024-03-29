/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
 *
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

extension UITextView {
    func adjustHeightFromContentSize(minHeight: CGFloat = 0) {
        let minWidth = self.frame.width
        let newSize = self.sizeThatFits(CGSize(width: minWidth,
                                               height: self.contentSize.height))
        var newFrame = self.frame
        newFrame.size = CGSize(width: max(newSize.width, minWidth), height: max(newSize.height, minHeight))
        self.frame = newFrame
    }
}
