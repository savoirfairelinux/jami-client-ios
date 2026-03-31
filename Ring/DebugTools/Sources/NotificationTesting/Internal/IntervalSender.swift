/*
 * Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import os

#if DEBUG_TOOLS_ENABLED

/// Internal periodic sender backing the `NotificationTesting` facade.
///
/// Drives a `DispatchSourceTimer` that calls a host-supplied closure with a
/// freshly generated `[TP:<w3c-traceparent>] ping <seq> <localTime>` body on
/// each tick (traceparent continues the `push.test-send` span). The closure
/// is expected to route the message into the host's `ConversationsService.sendSwarmMessage`.
///
/// This indirection (closure instead of a concrete service) keeps DebugTools
/// independent of host-target types.
final class IntervalSender {
    static let shared = IntervalSender()

    private let osLogger = os.Logger(subsystem: "cx.ring.jami", category: "debugTools.intervalSender")
    private var timer: DispatchSourceTimer?
    private var sequence: Int = 0
    private(set) var isRunning = false

    private var daemonLogAutoStopTimer: DispatchSourceTimer?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private init() {}

    /// Start sending test messages at the given interval.
    func start(
        conversationId: String,
        accountId: String,
        interval: TimeInterval,
        send: @escaping (String, String, String, String) -> Void
    ) {
        guard !isRunning else {
            osLogger.warning("IntervalSender already running")
            return
        }

        sequence = 0
        isRunning = true
        enableDaemonLogForwarding(autoStopAfter: nil)

        osLogger.info("Starting interval sender: conv=\(conversationId, privacy: .public) account=\(accountId, privacy: .public) interval=\(interval)s")

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.fire(conversationId: conversationId, accountId: accountId, send: send)
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        guard isRunning else { return }
        osLogger.info("Stopping interval sender")
        timer?.cancel()
        timer = nil
        isRunning = false
        disableDaemonLogForwarding()
    }

    /// Fire a single send immediately, independent of the periodic timer.
    func sendOnce(
        conversationId: String,
        accountId: String,
        send: (String, String, String, String) -> Void
    ) {
        if !isRunning {
            enableDaemonLogForwarding(autoStopAfter: 120)
        }
        fire(conversationId: conversationId, accountId: accountId, send: send)
    }

    // MARK: - Daemon log forwarding

    private func enableDaemonLogForwarding(autoStopAfter seconds: TimeInterval?) {
        LogForwarder.shared.isDaemonLogForwardingEnabled = true
        daemonLogAutoStopTimer?.cancel()
        daemonLogAutoStopTimer = nil
        guard let seconds = seconds else { return }
        let autoStop = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        autoStop.schedule(deadline: .now() + seconds)
        autoStop.setEventHandler {
            LogForwarder.shared.isDaemonLogForwardingEnabled = false
        }
        daemonLogAutoStopTimer = autoStop
        autoStop.resume()
    }

    private func disableDaemonLogForwarding() {
        LogForwarder.shared.isDaemonLogForwardingEnabled = false
        daemonLogAutoStopTimer?.cancel()
        daemonLogAutoStopTimer = nil
    }

    private func fire(
        conversationId: String,
        accountId: String,
        send: (String, String, String, String) -> Void
    ) {
        sequence += 1
        let timestamp = dateFormatter.string(from: Date())

        let (handle, traceparent) = TelemetryService.shared.startSpan(
            name: "push.test-send",
            attributes: [
                "conversation.id": conversationId,
                "sequence": String(sequence)
            ]
        )
        TelemetryService.shared.endSpan(handle: handle)
        // Embed the traceparent in the message body so the receiver
        // extension can extract it and continue the same trace.
        let message = "[TP:\(traceparent)] ping \(sequence) \(timestamp)"

        osLogger.info("Sending: \(message, privacy: .public)")

        send(conversationId, accountId, message, "")
    }

}

#endif
