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

#if DEBUG_TOOLS_ENABLED

/// Public facade for the push-notification testing tool inside DebugTools.
///
/// ## Lifecycle
///
/// 1. **Configure** once per process at launch:
///
///        NotificationTesting.configureLogger(
///            appGroupIdentifier: Constants.appGroupIdentifier
///        )
///
/// 2. **Emit spans** for lifecycle events:
///
///        NotificationTesting.emitInstantSpan(name: "push.received", attributes: [...])
///
/// 3. **Flush** before process suspension:
///
///        NotificationTesting.flushPendingSpans(timeout: 2.0)
///
/// ## Sender-side automation
///
/// On the sender side, the interval sender automates periodic test messages
/// on a swarm conversation. Each message carries a unique trace_id so the
/// sender's events correlate with the receiver extension's events in the
/// collector's timeline view.
///
///     NotificationTesting.startIntervalSender(
///         conversationId: conversation.id,
///         accountId: account.id,
///         interval: 30
///     ) { convId, accId, message, parentId in
///         conversationsService.sendSwarmMessage(
///             conversationId: convId,
///             accountId: accId,
///             message: message,
///             parentId: parentId
///         )
///     }
///
public enum NotificationTesting {

    // MARK: - Role

    /// Device role in a two-sided test session. Persisted as the rawValue
    /// string in shared App Group defaults under key `DebugToolsRole`.
    public enum Role: String, CaseIterable {
        case sender
        case receiver
    }

    // MARK: - Endpoint type

    /// Whether the configured endpoint is a standard OTel server (Jaeger)
    /// or the custom collector that also accepts daemon logs.
    public enum EndpointType: String, CaseIterable {
        case otel
        case collector
    }

    // MARK: - Event taxonomy

    /// Event types used by LogForwarder for NDJSON log shipping.
    public enum Event: String {
        case daemonLog
    }

    // MARK: - Logger configuration

    /// Configure the structured logger with the host's shared App Group identifier.
    /// Must be called once per process at startup; subsequent calls are no-ops.
    ///
    /// The collector URL is resolved automatically using a three-tier lookup:
    ///
    ///   1. **Launch argument** — the main app reads `-DebugToolsServerURL <url>`
    ///      from `UserDefaults.standard`, populated by Xcode from the
    ///      Jami-TestingTools scheme's Run action. This is how a developer
    ///      changes the URL for an on-device session: edit the scheme, ⌘R.
    ///
    ///   2. **Shared App Group defaults** — when the main app resolves a URL
    ///      from its launch argument, it writes that URL into the App Group's
    ///      shared `UserDefaults` under key `DebugToolsServerURL`. The
    ///      notification extension (a separate process that cannot see launch
    ///      arguments) reads from the same shared defaults on its next wake-up
    ///      by iOS, so it picks up whatever URL the main app was last configured
    ///      with.
    ///
    ///   3. **Simulator fallback** — when neither 1 nor 2 yields a URL and the
    ///      code is running on the iOS Simulator, the logger defaults to
    ///      `http://localhost:8080/logs`. This gives zero-setup operation for
    ///      the most common dev case: Simulator reaching the host Mac's
    ///      collector via localhost.
    ///
    ///   4. **Otherwise** — no URL, no shipping. Events are still written to
    ///      the local log file in the App Group container and to `os.Logger`.
    ///
    /// - Parameter appGroupIdentifier: The App Group both host targets share.
    ///     Used as the container for the buffered log file **and** as the
    ///     suite name for shared defaults between app and extension.
    private static var _appGroupIdentifier: String?

    public static func configureLogger(appGroupIdentifier: String) {
        _appGroupIdentifier = appGroupIdentifier

        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        var urlString = defaults?.string(forKey: "DebugToolsServerURL") ?? ""
        #if targetEnvironment(simulator)
        if urlString.isEmpty {
            urlString = "http://localhost:8080/logs"
            defaults?.set(urlString, forKey: "DebugToolsServerURL")
        }
        if defaults?.string(forKey: "DebugToolsRole") == nil {
            defaults?.set(Role.sender.rawValue, forKey: "DebugToolsRole")
        }
        #endif
        let url = urlString.isEmpty ? nil : URL(string: urlString)
        let type = defaults?.string(forKey: "DebugToolsEndpointType")
            .flatMap(EndpointType.init(rawValue:)) ?? .collector
        let role = defaults?.string(forKey: "DebugToolsRole")
            .flatMap(Role.init(rawValue:))

        TelemetryService.shared.configure(
            appGroupIdentifier: appGroupIdentifier,
            endpointURL: url,
            role: role
        )
        LogForwarder.shared.configure(
            appGroupIdentifier: appGroupIdentifier,
            serverURL: url,
            role: role
        )
        LogForwarder.shared.isEnabled = (type == .collector)
    }

    /// Shared App Group UserDefaults used by the main app and extension to
    /// exchange collector URL + device role. Returns `nil` until
    /// `configureLogger` has been called.
    public static var sharedDefaults: UserDefaults? {
        guard let group = _appGroupIdentifier else { return nil }
        return UserDefaults(suiteName: group)
    }

    /// Update the collector URL live. Persists to shared defaults so the
    /// notification extension inherits the change on its next wake.
    public static func setCollectorURL(_ urlString: String) {
        sharedDefaults?.set(urlString, forKey: "DebugToolsServerURL")
        let url = URL(string: urlString)
        TelemetryService.shared.updateEndpoint(url)
        LogForwarder.shared.updateServerURL(url)
        LogForwarder.shared.isEnabled = (currentEndpointType == .collector)
    }

    /// Update the endpoint type. Persists to shared defaults.
    public static func setEndpointType(_ type: EndpointType) {
        sharedDefaults?.set(type.rawValue, forKey: "DebugToolsEndpointType")
        let url = sharedDefaults?.string(forKey: "DebugToolsServerURL").flatMap(URL.init(string:))
        TelemetryService.shared.updateEndpoint(url)
        LogForwarder.shared.isEnabled = (type == .collector)
    }

    static var currentEndpointType: EndpointType {
        sharedDefaults?.string(forKey: "DebugToolsEndpointType")
            .flatMap(EndpointType.init(rawValue:)) ?? .collector
    }

    /// Update the device role live. Persists to shared defaults so the
    /// notification extension inherits the change on its next wake.
    public static func setRole(_ role: Role) {
        sharedDefaults?.set(role.rawValue, forKey: "DebugToolsRole")
        TelemetryService.shared.updateRole(role)
        LogForwarder.shared.updateRole(role)
    }

    // MARK: - Daemon log forwarding

    /// Forward a daemon log line to the collector (NDJSON shipping).
    /// Only active when the endpoint type is `.collector`.
    public static func forwardDaemonLog(_ message: String) {
        LogForwarder.shared.log(.daemonLog, message: message)
    }

    // MARK: - Flush

    /// Drain the OTel SimpleSpanProcessor and ship any buffered logs.
    public static func flushPendingSpans(timeout: TimeInterval = 2.0) {
        TelemetryService.shared.flushPendingSpans(timeout: timeout)
        if LogForwarder.shared.isEnabled {
            LogForwarder.shared.shipLogs()
        }
    }

    // MARK: - OTel span emission

    @discardableResult
    public static func emitInstantSpan(
        name: String,
        parentTraceparent: String? = nil,
        errorMessage: String? = nil,
        attributes: [String: String] = [:]
    ) -> String {
        return TelemetryService.shared.emitInstantSpan(
            name: name,
            parentTraceparent: parentTraceparent,
            errorMessage: errorMessage,
            attributes: attributes
        )
    }

    // MARK: - Duration spans

    /// Start a span that will be ended later via `endSpan(handle:)`.
    /// Returns the handle and a W3C traceparent for passing to child spans.
    public static func startSpan(
        name: String,
        parentTraceparent: String? = nil,
        attributes: [String: String] = [:]
    ) -> (handle: String, traceparent: String) {
        return TelemetryService.shared.startSpan(
            name: name,
            parentTraceparent: parentTraceparent,
            attributes: attributes
        )
    }

    /// End a span previously started with `startSpan(name:)`.
    public static func endSpan(
        handle: String,
        attributes: [String: String] = [:],
        errorMessage: String? = nil
    ) {
        TelemetryService.shared.endSpan(
            handle: handle,
            attributes: attributes,
            errorMessage: errorMessage
        )
    }

    // MARK: - Daemon span ingestion

    /// Ingest spans drained from the daemon's ring buffer (JSON array).
    /// Re-emits them through the Swift OTel pipeline.
    public static func ingestDaemonSpans(json: String) {
        TelemetryService.shared.ingestDaemonSpans(json: json)
    }

    /// Extract a W3C traceparent from a push notification's userInfo
    /// dictionary. The proxy server's `otel.traceparent` field is
    /// placed inside the `data` sub-dictionary of the APNs payload;
    /// returns nil when no traceparent is present or the shape is
    /// unexpected. Helper for the notification extension:
    ///
    ///     let traceparent = NotificationTesting.traceparent(from: request.content.userInfo)
    ///     NotificationTesting.emitSpan(name: "push.receive-extension",
    ///                                  parentTraceparent: traceparent)
    public static func traceparent(from userInfo: [AnyHashable: Any]) -> String? {
        if let traceparent = userInfo["otel.traceparent"] as? String, !traceparent.isEmpty {
            return traceparent
        }
        if let data = userInfo["data"] as? [AnyHashable: Any],
           let traceparent = data["otel.traceparent"] as? String, !traceparent.isEmpty {
            return traceparent
        }
        return nil
    }

    /// Extract the 32-character lowercase hex trace id from a W3C ``traceparent``
    /// string (`version-traceid-spanid-flags`). Returns nil when malformed.
    public static func traceIdHex(from traceparent: String) -> String? {
        let parts = traceparent.split(separator: "-")
        guard parts.count >= 3 else { return nil }
        let tid = String(parts[1])
        guard tid.count == 32,
              tid.range(of: "^[0-9a-fA-F]{32}$", options: .regularExpression) != nil
        else { return nil }
        return tid.lowercased()
    }

    // MARK: - Interval sender

    /// Start sending periodic test messages on a swarm conversation.
    ///
    /// Each tick generates a unique trace_id, records a `.testSent` event, then
    /// invokes the `send` closure with the formatted message body. The host is
    /// responsible for routing `send` into `ConversationsService.sendSwarmMessage`
    /// (or any equivalent channel). This indirection keeps DebugTools independent
    /// of host-target types.
    ///
    /// - Parameters:
    ///   - conversationId: Target swarm conversation.
    ///   - accountId: Account to send from.
    ///   - interval: Seconds between sends. Defaults to 30.
    ///   - send: Closure invoked on each tick, receiving
    ///           `(conversationId, accountId, message, parentId)`.
    public static func startIntervalSender(
        conversationId: String,
        accountId: String,
        interval: TimeInterval = 30,
        send: @escaping (_ conversationId: String, _ accountId: String, _ message: String, _ parentId: String) -> Void
    ) {
        IntervalSender.shared.start(
            conversationId: conversationId,
            accountId: accountId,
            interval: interval,
            send: send
        )
    }

    /// Stop the interval sender.
    public static func stopIntervalSender() {
        IntervalSender.shared.stop()
    }

    /// Whether the interval sender is currently running.
    public static var isIntervalSenderRunning: Bool {
        IntervalSender.shared.isRunning
    }

    /// Fire a single test message immediately, independent of the periodic
    /// timer. Safe to call whether or not the interval sender is running.
    /// Uses the same trace_id format as scheduled sends so the resulting
    /// event lands in the collector timeline alongside any ongoing periodic
    /// traffic.
    public static func sendTestMessageNow(
        conversationId: String,
        accountId: String,
        send: @escaping (_ conversationId: String, _ accountId: String, _ message: String, _ parentId: String) -> Void
    ) {
        IntervalSender.shared.sendOnce(
            conversationId: conversationId,
            accountId: accountId,
            send: send
        )
    }

    // MARK: - Trace ID parser

    /// Extract a `[TRACE:<uuid>]` payload from a message body, if present (legacy format).
    /// Returns `nil` if the message does not contain that substring.
    public static func extractTraceId(from message: String) -> String? {
        return TraceIdParser.extract(from: message)
    }

    /// Extract a W3C traceparent from `[TP:<traceparent>]` in the message body, if present.
    /// Used by the receiver app and notification extension to continue the sender trace.
    public static func extractTraceparent(from message: String) -> String? {
        return TraceIdParser.extractTraceparent(from: message)
    }
}

#endif
