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
import Network
import RxRelay
import RxSwift
import SwiftyBeaver

enum ConnectionType {
    case none
    case connected
}

class NetworkService {
    private let log = SwiftyBeaver.self

    var connectionState = BehaviorRelay<ConnectionType>(value: .none)

    lazy var connectionStateObservable: Observable<ConnectionType> = self.connectionState
        .asObservable()

    private var monitor: NWPathMonitor?
    private var lastStatus: NWPath.Status = .requiresConnection

    init() {
        monitor = NWPathMonitor()
    }

    func monitorNetworkType() {
        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            if self.lastStatus == path.status { return }
            self.lastStatus = path.status

            switch path.status {
            case .satisfied:
                print("Connected to a network")
                self.connectionState.accept(.connected)
            case .unsatisfied, .requiresConnection:
                print("Disconnected from a network")
                self.connectionState.accept(.none)
            default:
                break
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor?.start(queue: queue)
    }
}
