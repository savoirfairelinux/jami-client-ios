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
class DaemonService: NSObject, DRingDelegate {
    // MARK: Private members
    /// Indicates whether the daemon is started or not.
    fileprivate(set) internal var daemonStarted = false

    /// The DRingAdaptor making the c++ bridge between the deamon and the App Swift source code.
    fileprivate let dRingAdaptor:DRingAdaptator

    /// The time interval separating each poll.
    fileprivate let pollingTimeInterval = 0.05

    /// The timer scheduling the calls to the poll method.
    fileprivate var pollingTimer:Timer?

    // MARK: - Singleton
    static let sharedInstance = DaemonService(dRingAdaptor: DRingAdaptator())

    fileprivate init(dRingAdaptor:DRingAdaptator) {
        self.dRingAdaptor = dRingAdaptor
        super.init()
        self.dRingAdaptor.delegate = self
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

        print("Initialize daemon...")

        self.dRingAdaptor.initDaemon()

        /*if self.dRingAdaptor.initDaemon() {
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
         }*/
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
    fileprivate func startRingServicePolling() {
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
    @objc fileprivate func pollFunction() {
        print("Poll function")
        self.dRingAdaptor.pollEvents()
    }

    func daemonInitialized(success: Bool) {
        if success {
            print("Start deamon...")
            self.dRingAdaptor.startDaemon { (success) in
                if success {
                    self.startRingServicePolling()
                    self.daemonStarted = true
                    print("Daemon started.")
                }
                else {
                    print("Daemon failed to start.")
                }
            }
        }
        else {
            print("Daemon failed to initialize.")
        }
    }

    func daemonStarted(success: Bool) {

    }

    func daemonStopped(success: Bool) {

    }
}
