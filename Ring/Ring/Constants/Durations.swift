/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import RxSwift

public enum Durations {
    case textFieldThrottlingDuration
    case alertFlashDuration
    case switchThrottlingDuration

    var value: Double {
        switch self {
        case .textFieldThrottlingDuration:
            return 0.5
        case .alertFlashDuration:
            return 1.0
        case .switchThrottlingDuration:
            return 0.2
        }
    }

    var milliseconds: Int {
        switch self {
        case .textFieldThrottlingDuration:
            return 500
        case .alertFlashDuration:
            return 1000
        case .switchThrottlingDuration:
            return 200
        }
    }

    func toTimeInterval() -> RxTimeInterval {
        return RxTimeInterval.milliseconds(milliseconds)
    }
}
