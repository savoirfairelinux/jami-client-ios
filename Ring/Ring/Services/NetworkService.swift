/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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
import RealmSwift

enum ConnectionType {
    case none
    case wifi
    case cellular
}

class NetworkService {

    private let log = SwiftyBeaver.self

    fileprivate let disposeBag = DisposeBag()

    private var realm: Realm!

    let reachability: Reachability!

    var connectionState = Variable<ConnectionType>(.none)

    lazy var connectionStateObservable: Observable<ConnectionType> = {
        return self.connectionState.asObservable()
    }()

    init() {
        reachability = Reachability()!
    }

    func monitorNetworkType() {
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi {
                self.connectionState.value = ConnectionType.wifi
            } else {
                self.connectionState.value = ConnectionType.cellular
            }
        }

        reachability.whenUnreachable = { _ in
            self.log.debug("not reachable")
            self.connectionState.value = ConnectionType.none
        }

        do {
            try reachability.startNotifier()
            self.log.debug("notifier started")
        } catch {
            self.log.debug("unable to start notifier")
        }

        let when = DispatchTime.now() + 2 // change 2 to desired number of seconds
        DispatchQueue.main.asyncAfter(deadline: when) {
            self.connectionState.value = ConnectionType.none
        }
    }
}
