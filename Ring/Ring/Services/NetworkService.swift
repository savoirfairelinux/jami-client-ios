/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
import Reachability
import SwiftyBeaver
import RxSwift

enum ConnectionType {
    case none
    case wifi
    case cellular
}

class NetworkService {

    private let log = SwiftyBeaver.self

    let reachability: Reachability?

    var connectionState = Variable<ConnectionType>(.none)

    lazy var connectionStateObservable: Observable<ConnectionType> = {
        return self.connectionState.asObservable()
    }()

    init() {
        reachability = try? Reachability()
    }

    func monitorNetworkType() {

        reachability?.whenReachable = { reachability in
            if reachability.connection == .wifi {
                self.connectionState.value = .wifi
            } else {
                self.connectionState.value = .cellular
            }
        }

        reachability?.whenUnreachable = { _ in
            self.connectionState.value = .none
        }

        do {
            try reachability?.startNotifier()
            self.log.debug("network notifier started")
        } catch {
            self.log.debug("unable to start network notifier")
        }

    }
}
