/*
 * Copyright (C) 2025 Savoir-faire Linux Inc.
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

#if DEBUG

// MARK: - NotificationEvent

enum NotificationEvent: String {
    case received
    case appIsActive
    case shareExtensionActive
    case resubscribe
    case streamStarted
    case lineReceived
    case decryptedCall
    case decryptedGitMessage
    case decryptedClone
    case decryptedUnknown
    case backendStarted
    case eventMessage
    case eventFileTransferDone
    case eventFileTransferInProgress
    case eventSyncCompleted
    case eventConversationCloned
    case eventInvitation
    case eventActiveCall
    case notificationPresented
    case callReported
    case timeout
    case finished
    case daemonLog
    case error
}

// MARK: - NotificationLogger

final class NotificationLogger {
    static let shared = NotificationLogger()

    private static let maxFileSize = 500 * 1024 // 500 KB
    private static let logFileName = "notification_debug.log"
    /// Info.plist key whose value is set via the NOTIFICATION_LOG_SERVER_URL build setting.
    private static let plistKey = "NotificationLogServerURL"

    private let queue = DispatchQueue(label: "cx.ring.jamiNotificationExtension.logger")
    private let osLogger = Logger(subsystem: "cx.ring.jamiNotificationExtension", category: "notif")
    private let logFileURL: URL?
    /// Resolved once at init from Info.plist → build setting.
    private let serverURLValue: URL?
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) {
            self.logFileURL = container.appendingPathComponent(NotificationLogger.logFileName)
        } else {
            self.logFileURL = nil
        }
        // Read server URL from Info.plist (populated from NOTIFICATION_LOG_SERVER_URL build setting)
        if let urlString = Bundle.main.object(forInfoDictionaryKey: NotificationLogger.plistKey) as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            self.serverURLValue = url
        } else {
            self.serverURLValue = nil
        }
    }

    /// File collection + HTTP shipping is enabled only when NOTIFICATION_LOG_SERVER_URL is set
    /// in Xcode build settings. When empty, only os.Logger output is produced (Xcode console).
    private var collectingEnabled: Bool {
        return serverURLValue != nil
    }

    // MARK: - Logging

    func log(_ event: NotificationEvent, message: String = "", traceId: String = "") {
        let entry = buildEntry(event: event, message: message, traceId: traceId)
        osLogger.debug("\(entry, privacy: .public)")
        guard collectingEnabled else { return }
        queue.async { [weak self] in
            self?.appendToFile(entry + "\n")
        }
    }

    // MARK: - Ship Logs

    /// POST accumulated logs to the configured server URL, then clear the file.
    /// Call this at the end of each notification processing cycle.
    /// No-op when no server URL is configured.
    func shipLogs(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self,
                  let fileURL = self.logFileURL,
                  let serverURL = self.serverURL(),
                  let data = try? Data(contentsOf: fileURL),
                  !data.isEmpty else {
                completion?()
                return
            }

            var request = URLRequest(url: serverURL)
            request.httpMethod = "POST"
            request.setValue("application/x-ndjson", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            let session = URLSession(configuration: .ephemeral)
            let task = session.dataTask(with: request) { [weak self] _, response, error in
                if let http = response as? HTTPURLResponse, http.statusCode == 200, error == nil {
                    // Successfully shipped — clear the log file
                    self?.queue.async {
                        self?.clearFile()
                    }
                }
                // On failure, logs are retained for next cycle
                completion?()
            }
            task.resume()
        }
    }

    // MARK: - Private

    private func buildEntry(event: NotificationEvent, message: String, traceId: String) -> String {
        let ts = dateFormatter.string(from: Date())
        let source = event == .daemonLog ? "daemon" : "extension"
        // Build JSON manually to avoid JSONSerialization overhead
        var json = "{\"ts\":\"\(ts)\",\"event\":\"\(event.rawValue)\",\"source\":\"\(source)\""
        if !traceId.isEmpty {
            json += ",\"traceId\":\"\(escapeJSON(traceId))\""
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
           size > NotificationLogger.maxFileSize {
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

    private func serverURL() -> URL? {
        return serverURLValue
    }
}

#endif
