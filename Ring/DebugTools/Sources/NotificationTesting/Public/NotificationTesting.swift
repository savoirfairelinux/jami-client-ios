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
/// 1. **Configure** the logger once per process at launch, inside a
///    `#if DEBUG_TOOLS_ENABLED` block in your AppDelegate / NotificationService:
///
///        NotificationTesting.configureLogger(
///            appGroupIdentifier: Constants.appGroupIdentifier
///        )
///
///    The collector URL is discovered automatically — see
///    `configureLogger(appGroupIdentifier:)` below for the three-tier lookup.
///
/// 2. **Log events** throughout the lifecycle of interesting operations:
///
///        NotificationTesting.logEvent(.received, message: "didReceive entry")
///
/// 3. **Ship logs** to the configured collector at the end of a work unit
///    (extension's `didReceive` completion, or after each interval send):
///
///        NotificationTesting.shipLogs()
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

    // MARK: - Event taxonomy

    /// Every event type this tool can record. Events are written to the
    /// structured logger and show up in the collector's `/timeline` endpoint.
    public enum Event: String {
        // Receiver-side lifecycle
        case received
        case appIsActive
        case shareExtensionActive
        case resubscribe
        case streamStarted
        case streamEmpty
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

        // Sender-side lifecycle
        case testSent
        case testStarted
        case testStopped
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
    public static func configureLogger(appGroupIdentifier: String) {
        Logger.shared.configure(appGroupIdentifier: appGroupIdentifier)
    }

    /// Shared App Group UserDefaults used by the main app and extension to
    /// exchange collector URL + device role. Returns `nil` until
    /// `configureLogger` has been called.
    public static var sharedDefaults: UserDefaults? {
        guard let group = Logger.shared.appGroupIdentifier else { return nil }
        return UserDefaults(suiteName: group)
    }

    /// Update the collector URL live. Persists to shared defaults so the
    /// notification extension inherits the change on its next wake.
    public static func setCollectorURL(_ urlString: String) {
        sharedDefaults?.set(urlString, forKey: "DebugToolsServerURL")
        Logger.shared.setCollectorURL(urlString)
    }

    /// Update the device role live. Persists to shared defaults so the
    /// notification extension inherits the change on its next wake.
    public static func setRole(_ role: Role) {
        sharedDefaults?.set(role.rawValue, forKey: "DebugToolsRole")
        Logger.shared.setRole(role)
    }

    // MARK: - Logging

    /// Record an event.
    ///
    /// - Parameters:
    ///   - event: The event taxonomy member.
    ///   - message: Free-form detail string. Daemon log lines pass through here.
    ///     If this string contains a `[TRACE:<uuid>]` substring and no explicit
    ///     `traceId` is supplied, the tool will auto-extract the trace_id and
    ///     tag the event.
    ///   - traceId: Optional explicit trace identifier for end-to-end correlation.
    public static func logEvent(_ event: Event, message: String = "", traceId: String = "") {
        Logger.shared.log(event, message: message, traceId: traceId)
    }

    /// Flush the buffered log file to the configured collector URL.
    /// Called at the end of each notification processing cycle (extension)
    /// or after each test send (main app).
    /// No-op when no server URL was set via `configureLogger(appGroupIdentifier:serverURL:)`.
    public static func shipLogs(completion: (() -> Void)? = nil) {
        Logger.shared.shipLogs(completion: completion)
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

    /// Extract a `[TRACE:<uuid>]` prefix from a message body, if present.
    /// Returns `nil` if the message does not contain a trace prefix.
    public static func extractTraceId(from message: String) -> String? {
        return TraceIdParser.extract(from: message)
    }
}

#endif
