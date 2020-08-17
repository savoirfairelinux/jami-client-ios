/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

class ProfileHeaderView: GSKStretchyHeaderView {

    @IBOutlet var avatarView: UIView!
    @IBOutlet var displayName: UILabel!
    @IBOutlet var userName: UILabel!
    @IBOutlet weak var jamiID: CopyableLabel!
    @IBOutlet weak var background: UIView!

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        self.backgroundColor = UIColor.jamiBackgroundColor
        self.background.backgroundColor = UIColor.jamiBackgroundColor
    }

    override func didChangeStretchFactor(_ stretchFactor: CGFloat) {
        var alpha = CGFloatTranslateRange(stretchFactor, 0.2, 0.7, 0, 1)
        alpha = max(0, min(1, alpha))
        self.avatarView.alpha = alpha
        self.displayName.alpha = alpha
        self.userName.alpha = alpha
        self.jamiID.alpha = alpha

        var scale = CGFloatTranslateRange(stretchFactor, 0.1, 0.9, 0.6, 1)
        scale = max(0.4, min(1, scale))
        self.avatarView.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.displayName.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.userName.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.jamiID.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
