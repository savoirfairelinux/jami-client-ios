/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

/* Work around to avoid table view move down when keyboard
 * is shown. This problem arrive when adding text field to
 * GSKStretchyHeaderView
 */

final class SettingsTableView: UITableView {
    override var contentOffset: CGPoint {
        didSet {
            if contentOffset.x != 0 && !alwaysBounceHorizontal {
                print("********* Unexpected horizontal scroll detected!")
                contentOffset.x = 0
            }
        }
    }

    override func scrollRectToVisible(_: CGRect, animated _: Bool) {
        // Don'd do anything here to prevent autoscrolling.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        superview?.touchesBegan(touches, with: event)
    }
}
