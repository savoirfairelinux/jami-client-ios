/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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
import RxCocoa
import RxSwift

/**
 Errors that can be thrown when trying to start the daemon:

 - DaemonAlreadyRunning: the daemon is already running.
 - InitializationFailure: the daemon failed to initialiaze.
 - StartFailure: the daemon failed to start.
 */
enum StartDaemonError: Error {
    case DaemonAlreadyRunning
    case InitializationFailure
    case StartFailure
}

/**
 Errors that can be thrown when trying to stop the daemon:

 - DaemonNotRunning: the daemon is not running and can not be stopped.
 */
enum StopDaemonError: Error {
    case DaemonNotRunning
}

/**
 A service managing the daemon main features and lifecycle.
 Its responsabilities:
    - start the deamon
    - stop the daemon
    - orchestrate the poll events calls of the deamon
 Its callbacks:
    - does not currently expose any signal or callback of any kind.
 */
class DaemonService {
    // MARK: Private members
    /// Indicates whether the daemon is started or not.
    fileprivate(set) internal var daemonStarted = false

    /// The DRingAdaptor making the c++ bridge between the deamon and the App Swift source code.
    fileprivate let dRingAdaptor: DRingAdapter

    /// The time interval separating each poll.
    fileprivate var pollingTimeInterval = 0.05

    /// The timer scheduling the calls to the poll method.
    fileprivate var pollingTimer: Timer?

    /// Rx DisposeBag
    fileprivate let disposeBag = DisposeBag()

    // MARK: Initialization
    init(dRingAdaptor: DRingAdapter) {
        self.dRingAdaptor = dRingAdaptor

        NotificationCenter.default
            .rx
            .notification(Notification.Name.UIApplicationDidEnterBackground)
            .subscribe(onNext: { [weak self] event in
                self?.pollingTimer?.invalidate()
                self?.pollingTimeInterval = 1.0
                self?.startRingServicePolling()
            })
            .addDisposableTo(disposeBag)

        NotificationCenter.default
            .rx
            .notification(Notification.Name.UIApplicationDidBecomeActive)
            .subscribe(onNext: { [weak self] event in
                self?.pollingTimer?.invalidate()
                self?.pollingTimeInterval = 0.05
                self?.startRingServicePolling()
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: Public API
    /**
     Starts the Ring daemon.

     - Throws: StartDaemonError
     */
    func startDaemon() throws {
        guard !self.daemonStarted else {
            throw StartDaemonError.DaemonAlreadyRunning
        }

        print("Starting daemon...")
        if self.dRingAdaptor.initDaemon() {
            print("Daemon initialized.")
            if self.dRingAdaptor.startDaemon() {
                self.startRingServicePolling()
                self.daemonStarted = true
                print("Daemon started.")
            }
            else {
                throw StartDaemonError.StartFailure
            }
        }
        else {
            throw StartDaemonError.InitializationFailure
        }
    }

    /**
     Stops the Ring daemon.

     - Throws: StopDaemonError
     */
    func stopDaemon() throws {
        guard self.daemonStarted else {
            throw StopDaemonError.DaemonNotRunning
        }

        print("Stopping daemon...")
        self.pollingTimer?.invalidate()
        self.dRingAdaptor.fini()
        self.daemonStarted = false
        print("Daemon stopped.")
    }

    // MARK: Private Core
    /**
     Initiates the timer scheduling the calls to the daemon poll event method. It then starts it.
     */
    func startRingServicePolling() {
        self.pollingTimer = Timer.scheduledTimer(timeInterval: pollingTimeInterval,
                                                 target: self,
                                                 selector: #selector(self.pollFunction),
                                                 userInfo: nil,
                                                 repeats: true)
    }

    /**
     Performs the call to the daemon pollEvents method each time the pollingTimer decides to.
     This method must be @objc exposed to be called by the timer.
     */
    @objc func pollFunction() {
        print("Poll event", NSDate())
        self.dRingAdaptor.pollEvents()
    }
}
