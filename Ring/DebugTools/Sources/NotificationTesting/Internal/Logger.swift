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

/// Internal structured logger backing the `NotificationTesting` facade.
///
/// Used by both the main app (sender side) and the notification extension
/// (receiver side). Buffers JSON-lines to a per-process file in the host's
/// shared App Group container, then ships them to a configured collector via
/// HTTP POST. Both processes feed the same collector, which merges them into
/// a single timeline keyed by trace_id.
///
/// This type is `internal` — host code reaches it only through
/// `NotificationTesting.logEvent(...)` and `NotificationTesting.shipLogs()`.
final class Logger {
    static let shared = Logger()

    private static let maxFileSize = 500 * 1024 // 500 KB

    private let queue = DispatchQueue(label: "cx.ring.jami.debugTools.logger")
    private let osLogger = os.Logger(subsystem: "cx.ring.jami", category: "debugTools")

    // Lazy state — populated by `configure(...)`, updated by `setRole` /
    // `setCollectorURL` when the user edits them in the Settings UI.
    private var logFileURL: URL?
    private var serverURLValue: URL?
    private var processSource: String = "unknown"
    private var role: NotificationTesting.Role?
    private(set) var appGroupIdentifier: String?
    private var configured: Bool = false

    func setRole(_ newRole: NotificationTesting.Role) {
        queue.async {
            self.role = newRole
            self.applyDaemonLogForwardingForRole()
        }
    }

    /// Receivers need daemon logs flowing at all times (p2p messages,
    /// background sync, foreground pushes) since there's no interval sender
    /// to toggle forwarding. On senders, IntervalSender owns the flag and
    /// only enables it during active bursts.
    private func applyDaemonLogForwardingForRole() {
        if role == .receiver {
            isDaemonLogForwardingEnabled = true
        } else {
            isDaemonLogForwardingEnabled = false
        }
    }

    func setCollectorURL(_ urlString: String) {
        queue.async {
            self.serverURLValue = URL(string: urlString)
        }
    }

    /// When false, `.daemonLog` events are dropped. Always on for role =
    /// receiver (we want full daemon visibility: pushes, p2p, sync). On
    /// sender, IntervalSender flips this on/off around active bursts so
    /// idle sender daemons don't flood the collector.
    var isDaemonLogForwardingEnabled: Bool = false
    private var flushTimer: DispatchSourceTimer?

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    // MARK: - Configuration

    /// Configure with the host's app group identifier. Initial role and
    /// collector URL come from shared App Group defaults; live UI edits
    /// apply via `setRole` / `setCollectorURL`.
    func configure(appGroupIdentifier: String) {
        queue.sync {
            guard !self.configured else { return }
            self.configured = true
            self.appGroupIdentifier = appGroupIdentifier

            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            ) {
                let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
                let isExtension = bundleId.contains("Extension") || bundleId.contains("extension")
                self.processSource = isExtension ? "extension" : "app"
                let fileName = isExtension ? "debug_tools.ext.log" : "debug_tools.app.log"
                self.logFileURL = container.appendingPathComponent(fileName)
            }

            let shared = UserDefaults(suiteName: appGroupIdentifier)
            if let savedRole = shared?.string(forKey: "DebugToolsRole"),
               let parsed = NotificationTesting.Role(rawValue: savedRole) {
                self.role = parsed
            }
            self.applyDaemonLogForwardingForRole()
            if let raw = shared?.string(forKey: "DebugToolsServerURL"),
               !raw.isEmpty, let url = URL(string: raw) {
                self.serverURLValue = url
            } else {
                #if targetEnvironment(simulator)
                self.serverURLValue = URL(string: "http://localhost:8080/logs")
                #endif
            }

            self.startPeriodicFlush()
        }
    }

    /// Flush buffered logs every 5s — covers daemon log lines that arrive
    /// asynchronously between explicit `shipLogs()` calls.
    private func startPeriodicFlush() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            guard let self = self,
                  let fileURL = self.logFileURL,
                  let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let size = attrs[.size] as? Int,
                  size > 0 else { return }
            // Release the queue lock before shipping (shipLogs re-acquires it).
            DispatchQueue.global(qos: .utility).async {
                self.shipLogs()
            }
        }
        self.flushTimer = timer
        timer.resume()
    }

    private var collectingEnabled: Bool {
        return serverURLValue != nil
    }

    // MARK: - Logging

    func log(_ event: NotificationTesting.Event, message: String = "", traceId: String = "") {
        if event == .daemonLog && !isDaemonLogForwardingEnabled { return }
        let entry = buildEntry(event: event, message: message, traceId: traceId)
        osLogger.debug("\(entry, privacy: .public)")
        guard collectingEnabled else { return }
        queue.async { [weak self] in
            self?.appendToFile(entry + "\n")
        }
    }

    // MARK: - Ship Logs

    /// POST accumulated logs to the configured server URL, then clear the file.
    /// No-op when no server URL was configured.
    func shipLogs(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self,
                  let fileURL = self.logFileURL,
                  let serverURL = self.serverURLValue,
                  let data = try? Data(contentsOf: fileURL),
                  !data.isEmpty else {
                completion?()
                return
            }

            var request = URLRequest(url: serverURL)
            request.httpMethod = "POST"
            request.setValue("application/x-ndjson", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            // Short timeout — the extension calls shipLogs() before
            // contentHandler, so this can't hang if the collector is down.
            request.timeoutInterval = 5
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: request) { [weak self] _, response, error in
                if let http = response as? HTTPURLResponse, http.statusCode == 200, error == nil {
                    self?.queue.async { self?.clearFile() }
                }
                completion?()
            }
            task.resume()
        }
    }

    // MARK: - Private

    private func buildEntry(event: NotificationTesting.Event, message: String, traceId: String) -> String {
        let ts = dateFormatter.string(from: Date())
        let source = event == .daemonLog ? "daemon" : processSource

        // If the caller didn't supply a trace_id, try to recover one from the
        // message body. Daemon log lines that include the plaintext message body
        // (e.g. swarm sends with our `[TRACE:<uuid>] ping ...` prefix) get
        // tagged automatically — that's how sender-side daemon log lines
        // correlate with the rest of the trace.
        var effectiveTraceId = traceId
        if effectiveTraceId.isEmpty,
           let start = message.range(of: "[TRACE:"),
           let end = message[start.upperBound...].firstIndex(of: "]") {
            effectiveTraceId = String(message[start.upperBound..<end])
        }

        // Build JSON manually to avoid JSONSerialization overhead.
        let roleString = role?.rawValue ?? "unknown"
        var json = "{\"ts\":\"\(ts)\",\"event\":\"\(event.rawValue)\",\"source\":\"\(source)\",\"role\":\"\(roleString)\""
        if !effectiveTraceId.isEmpty {
            json += ",\"traceId\":\"\(escapeJSON(effectiveTraceId))\""
        }
        if !message.isEmpty {
            json += ",\"msg\":\"\(escapeJSON(message))\""
        }
        json += "}"
        return json
    }

    private func escapeJSON(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func appendToFile(_ text: String) {
        guard let fileURL = logFileURL else { return }
        let fileManager = FileManager.default

        // Rotate if needed
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int,
           size > Logger.maxFileSize {
            clearFile()
        }

        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { handle.closeFile() }
        handle.seekToEndOfFile()
        if let data = text.data(using: .utf8) {
            handle.write(data)
        }
    }

    private func clearFile() {
        guard let fileURL = logFileURL else { return }
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

#endif
