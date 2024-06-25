/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

class ScreenHelper {
    class func currentOrientation() -> UIInterfaceOrientation {
        guard let orientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?
                .windowScene?.interfaceOrientation
        else {
            return .unknown
        }
        return orientation
    }

    class func welcomeFormPresentationStyle() -> UIModalPresentationStyle {
        switch ScreenHelper.currentOrientation() {
        case .landscapeLeft, .landscapeRight:
            return .fullScreen
        case .portrait, .portraitUpsideDown:
            return .formSheet
        default:
            return .fullScreen
        }
    }
}
