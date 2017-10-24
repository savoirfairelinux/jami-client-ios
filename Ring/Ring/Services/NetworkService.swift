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
import CoreTelephony
import Reachability
import SwiftyBeaver
import RxSwift
import RealmSwift

class NetworkService {

    private let log = SwiftyBeaver.self

    fileprivate let disposeBag = DisposeBag()

    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    private var realm: Realm!

    let reachability: Reachability!

    init() {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        reachability = Reachability()!
    }

    func monitorNetworkType() {
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi {
                self.log.debug("WiFi")
            } else {
                self.log.debug("cellular")
                let networkInfo = CTTelephonyNetworkInfo()
                let carrierType = networkInfo.currentRadioAccessTechnology
                switch carrierType {
                case CTRadioAccessTechnologyGPRS?, CTRadioAccessTechnologyEdge?, CTRadioAccessTechnologyCDMA1x?:
                    self.log.debug("2G")
                case CTRadioAccessTechnologyWCDMA?, CTRadioAccessTechnologyHSDPA?, CTRadioAccessTechnologyHSUPA?, CTRadioAccessTechnologyCDMAEVDORev0?,
                     CTRadioAccessTechnologyCDMAEVDORevA?, CTRadioAccessTechnologyCDMAEVDORevB?, CTRadioAccessTechnologyeHRPD?:
                    self.log.debug("3G")
                case CTRadioAccessTechnologyLTE?:
                    self.log.debug("4G")
                default:
                    self.log.debug("unknown connectivity")
                }
            }
        }

        reachability.whenUnreachable = { _ in
            self.log.debug("not reachable")
        }

        do {
            try reachability.startNotifier()
            self.log.debug("notifier started")
        } catch {
            self.log.debug("unable to start notifier")
        }
    }
}
