/*
 *  Copyright (C) 2016-2018 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import SwiftyBeaver

/**
 Errors that can be thrown when trying to start the daemon:

 - DaemonAlreadyRunning: the daemon is already running.
 - InitializationFailure: the daemon failed to initialiaze.
 - StartFailure: the daemon failed to start.
 */
enum StartDaemonError: Error {
    case daemonAlreadyRunning
    case initializationFailure
    case startFailure
}

/**
 Errors that can be thrown when trying to stop the daemon:

 - DaemonNotRunning: the daemon is not running and can not be stopped.
 */
enum StopDaemonError: Error {
    case daemonNotRunning
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

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    /// Indicates whether the daemon is started or not.
    internal private(set) var daemonStarted = false

    /// The DRingAdaptor making the c++ bridge between the deamon and the App Swift source code.
    private let dRingAdaptor: DRingAdapter

    /// The time interval separating each poll.
    private let pollingTimeInterval = 0.01

    /// The timer scheduling the calls to the poll method.
    private var pollingTimer: Timer?

    // MARK: Initialization
    init(dRingAdaptor: DRingAdapter) {
        self.dRingAdaptor = dRingAdaptor
    }

    // MARK: Public API
    /**
     Starts the Ring daemon.

     - Throws: StartDaemonError
     */
    func startDaemon() throws {
        guard !self.daemonStarted else {
            throw StartDaemonError.daemonAlreadyRunning
        }

        log.debug("Starting daemon...")
        if self.dRingAdaptor.initDaemon() {
            log.debug("Daemon initialized.")
            if self.dRingAdaptor.startDaemon() {
                self.daemonStarted = true
                log.debug("Daemon started.")
            } else {
                throw StartDaemonError.startFailure
            }
        } else {
            throw StartDaemonError.initializationFailure
        }
    }

    /**
     Stops the Ring daemon.

     - Throws: StopDaemonError
     */
    func stopDaemon() throws {
        guard self.daemonStarted else {
            throw StopDaemonError.daemonNotRunning
        }

        log.debug("Stopping daemon...")
        self.pollingTimer?.invalidate()
        self.dRingAdaptor.fini()
        self.daemonStarted = false
        log.debug("Daemon stopped.")
    }

    func connectivityChanged() {
        log.debug("connectivity changed")
        self.dRingAdaptor.connectivityChanged()
    }

}
