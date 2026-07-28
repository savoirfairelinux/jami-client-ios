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
import SwiftyBeaver
import RxSwift
import RxRelay

enum ConnectionType {
    case none
    case connected
}

class NetworkService {

    private let log = SwiftyBeaver.self

    var connectionState = BehaviorRelay<ConnectionType>(value: .none)

    lazy var connectionStateObservable: Observable<ConnectionType> = {
        return self.connectionState.asObservable()
    }()

    /*
     Emits only real connectivity transitions, never the first path evaluation.

     NWPathMonitor delivers the current path as soon as it starts. That first
     callback describes the state the daemon already registered with, so
     reporting it as a change makes the daemon unregister and re-register the
     account for nothing. A re-registration tears the DHT down, and every
     in-flight operation dies with it: answers to peer connection requests fail
     to be published, so peers trying to reach us right after launch never get
     our ICE candidates and their connection attempt is lost.
     */
    private let connectivityChanges = PublishRelay<ConnectionType>()

    lazy var connectivityChangedObservable: Observable<ConnectionType> = {
        return self.connectivityChanges.asObservable()
    }()

    private var monitor: NWPathMonitor?
    private var lastStatus: NWPath.Status?

    init() {
        monitor = NWPathMonitor()
    }

    func monitorNetworkType() {
        monitor?.pathUpdateHandler = { [weak self] path in
            self?.handle(status: path.status)
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor?.start(queue: queue)
    }

    func handle(status: NWPath.Status) {
        let isInitialPath = lastStatus == nil
        if lastStatus == status { return }
        lastStatus = status

        let state: ConnectionType
        switch status {
        case .satisfied:
            print("Connected to a network")
            state = .connected
        case .unsatisfied, .requiresConnection:
            print("Disconnected from a network")
            state = .none
        default:
            return
        }

        connectionState.accept(state)
        if !isInitialPath {
            connectivityChanges.accept(state)
        }
    }
}
