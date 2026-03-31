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
        NotificationTesting.configureLogger(appGroupIdentifier: Constants.appGroupIdentifier)
        NotificationTesting.emitInstantSpan(
            name: "app.launch",
            attributes: ["process": "main", "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"]
        )
        NotificationTesting.flushPendingSpans(timeout: 2.0)
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
        NotificationTesting.forwardDaemonLog(message)
        #endif
        guard isMonitoring.value else { return }
        currentLog += "\n" + message
        newMessage.accept(message)
    }
}
