/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

import UIKit

class ConferenceLayoutHelper {
    private var videoWidth: CGFloat = 0
    private var videoHeight: CGFloat = 0

    private var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    private var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }

    private var widthToHeightRatio: CGFloat {
        if videoHeight == 0 { return 0 }
        return videoWidth / videoHeight
    }

    private var heightToWidthRatio: CGFloat {
        if videoWidth == 0 { return 0 }
        return videoHeight / videoWidth
    }

    func setVideoSize(size: CGSize) {
        self.videoWidth = size.width
        self.videoHeight = size.height
    }

    func getWidthConstraint() -> CGFloat {
        if UIDevice.current.orientation == .landscapeRight || UIDevice.current.orientation == .landscapeLeft {
            return screenHeight * widthToHeightRatio
        }
        return screenWidth
    }

    func getHeightConstraint() -> CGFloat {
        if UIDevice.current.orientation == .landscapeRight || UIDevice.current.orientation == .landscapeLeft {
            return screenHeight
        }
        return screenWidth * heightToWidthRatio
    }

    func getHeightRatio() -> CGFloat {
        guard self.videoHeight != 0 else { return 0 }
        return self.getHeightConstraint() / self.videoHeight
    }

    func getWidthRatio() -> CGFloat {
        guard self.videoWidth != 0 else { return 0 }
        return self.getWidthConstraint() / self.videoWidth
    }
}
