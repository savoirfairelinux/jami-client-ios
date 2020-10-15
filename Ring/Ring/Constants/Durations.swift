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
    case oneSecond
    case halfSecond
    case threeSeconds
    case tenSeconds
    case sixtySeconds

    var value: Double {
        switch self {
        case .textFieldThrottlingDuration, .halfSecond:
            return 0.5
        case .alertFlashDuration, .oneSecond:
            return 1.0
        case .switchThrottlingDuration:
            return 0.2
        case .threeSeconds:
            return 3
        case .tenSeconds:
            return 10
        case .sixtySeconds:
            return 60
        }
    }

    var milliseconds: Int {
        return Int(self.value * 1000)
    }

    func toTimeInterval() -> RxTimeInterval {
        return RxTimeInterval.milliseconds(milliseconds)
    }
}
