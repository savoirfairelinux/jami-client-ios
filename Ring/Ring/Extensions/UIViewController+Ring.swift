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

extension UIViewController {
    func configureNavigationBar() {
        navigationController?.navigationBar.tintColor = UIColor.jami
        navigationController?.navigationBar.prefersLargeTitles = false
    }
}

extension UINavigationController {
    public static func navBarHeight() -> CGFloat {
        let nVc = UINavigationController(rootViewController: UIViewController(nibName: nil, bundle: nil))
        let navBarHeight = nVc.navigationBar.frame.size.height
        return navBarHeight
    }
}
