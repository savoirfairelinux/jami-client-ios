/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import RxRelay
#if DEBUG_TOOLS_ENABLED
import DebugTools
#endif

class SystemService: SystemAdapterDelegate {

    private let systemAdapter: SystemAdapter
    var newMessage = BehaviorRelay(value: "")
    var currentLog = ""
    var isMonitoring = BehaviorRelay(value: false)

    init(withSystemAdapter systemAdapter: SystemAdapter) {
        self.systemAdapter = systemAdapter
        SystemAdapter.delegate = self
        #if DEBUG_TOOLS_ENABLED
        // Configure the DebugTools logger once per process, then start daemon
        // log streaming so it receives every JAMI_LOG line. The collector URL
        // is discovered automatically by NotificationTesting — scheme launch
        // argument → shared App Group defaults → simulator localhost fallback.
        // References NotificationTesting (a DebugTools-only symbol) so this
        // gate cascades through an excluded file in non-test configs.
        NotificationTesting.configureLogger(appGroupIdentifier: Constants.appGroupIdentifier)
        isMonitoring.accept(true)
        systemAdapter.triggerLog(true)
        #endif
    }

    func triggerLog() {
        isMonitoring.accept(!isMonitoring.value)
        systemAdapter.triggerLog(isMonitoring.value)
    }

    func clearLog(force: Bool = false) {
        if !isMonitoring.value || force {
            currentLog = ""
            newMessage.accept("")
        }
    }

    @objc
    func messageReceived(message: String) {
        #if DEBUG_TOOLS_ENABLED
        NotificationTesting.logEvent(.daemonLog, message: message)
        #endif
        guard isMonitoring.value else { return }
        currentLog += "\n" + message
        newMessage.accept(message)
    }
}
