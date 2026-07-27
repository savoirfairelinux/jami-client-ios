/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

struct CallId: Hashable, Sendable, CustomStringConvertible {
    let raw: String
    var description: String { raw }

    /// Stands for a call the user started before libjami confirmed one;
    /// never valid as a libjami argument.
    static func local() -> CallId {
        return CallId(raw: localPrefix + UUID().uuidString)
    }

    var isLocal: Bool { raw.hasPrefix(Self.localPrefix) }

    private static let localPrefix = "local:"
}

struct ConfId: Hashable, Sendable, CustomStringConvertible {
    let raw: String
    var description: String { raw }
}

enum ConferenceLifecycle: String, Sendable {
    case activeAttached = "ACTIVE_ATTACHED"
    case activeDetached = "ACTIVE_DETACHED"
    case hold = "HOLD"
    case unknown

    init(libJamiState: String) {
        self = ConferenceLifecycle(rawValue: libJamiState) ?? .unknown
    }
}

enum CallDirection: Sendable, Equatable {
    case incoming
    case outgoing
}

/// Value-type snapshot of one call. Owned and mutated exclusively by
/// `CallStore`; everyone else receives copies via events.
struct CallState: Sendable, Identifiable, Equatable {
    let id: CallId
    let accountId: String
    let direction: CallDirection

    var peerUri: String = ""
    var displayName: String = ""
    var registeredName: String?
    var status: CallStatus
    /// libjami-confirmed media list — flips only on MediaNegotiationStatus.
    var media: [MediaItem] = []
    /// Re-invite we sent and are waiting on; cleared on negotiation result.
    var pendingMediaRequest: [MediaItem]?
    /// When the call became CURRENT (history duration counts from here).
    var startedAt: Date?
    var isAudioOnly: Bool = false
    var callKitUUID: UUID?
    var conferenceId: ConfId?
    var peerIsRecording: Bool = false
    var videoCodec: String?
    /// Tracked separately from `status` so local and peer hold can be
    /// merged into `held(side:)` and correctly unwound.
    var peerHolding: Bool = false
    var conversationId: String?
    var joinsExistingCall: Bool = false
    var pendingInvites: [PendingConferenceInvite] = []

    var bestName: String {
        if !displayName.isEmpty { return displayName }
        if let registeredName = registeredName, !registeredName.isEmpty {
            return registeredName
        }
        return peerHash
    }

    var peerHash: String {
        return peerUri.filterOutHost()
            .replacingOccurrences(of: "jami:", with: "")
            .replacingOccurrences(of: "sip:", with: "")
    }

    var isAudioMuted: Bool {
        media.isAudioMuted
    }

    var isVideoMuted: Bool {
        media.isVideoMuted
    }

    var hasVideo: Bool {
        media.hasVideo
    }

    var hasNegotiatedVideo: Bool {
        media.hasNegotiatedVideo
    }

    /// The attached locally hosted conference that owns this call's media.
    func mediaOwningHostedConference(in conference: ConferenceState?) -> ConferenceState? {
        guard let conference = conference,
              conference.id == conferenceId,
              conference.isHost,
              conference.hasAttachedHost else { return nil }
        return conference
    }

    /// Media owned by this call, or by its locally hosted conference.
    func effectiveMedia(in conference: ConferenceState?) -> [MediaItem] {
        return mediaOwningHostedConference(in: conference)?.media ?? media
    }

    func effectiveAudioMuted(in conference: ConferenceState?) -> Bool {
        return mediaOwningHostedConference(in: conference)?.isAudioMuted ?? isAudioMuted
    }
}

/// Conference layout as sent to `setConferenceLayout` (values are the
/// libjami's int encoding — do not renumber).
enum ConferenceLayoutMode: Int, Sendable {
    case grid = 0
    case oneWithSmall = 1
    case one = 2
}

/// A participant we invited who has not joined yet; the join is deferred
/// until their sub-call reaches `.current`.
struct PendingConferenceInvite: Sendable, Equatable {
    let callId: CallId
    let peerUri: String
    let status: CallStatus
}

struct ConferenceState: Sendable, Identifiable, Equatable {
    let id: ConfId
    let accountId: String
    /// libjami-confirmed media owned by the local conference host.
    var media: [MediaItem] = []
    /// Host media re-invite awaiting MediaNegotiationStatus.
    var pendingMediaRequest: [MediaItem]?
    var participants: [ConferenceParticipantInfo] = []
    var memberCallIds: Set<CallId> = []
    var layout: ConferenceLayoutMode = .grid
    var isHost: Bool = false
    var lifecycle: ConferenceLifecycle = .unknown
    var conversationId: String?

    var hasAttachedHost: Bool {
        return lifecycle == .activeAttached
    }

    var isAudioMuted: Bool {
        if let localHost = participants.first(where: { $0.uri.isEmpty }) {
            return localHost.isAudioLocallyMuted || localHost.isAudioModeratorMuted
        }
        return media.isAudioMuted
    }

    var isVideoMuted: Bool {
        media.isVideoMuted
    }

    var hasVideo: Bool {
        media.hasVideo
    }
}

struct CallSystemState: Sendable {
    var calls: [CallId: CallState] = [:]
    var conferences: [ConfId: ConferenceState] = [:]

    var ongoingCalls: [CallState] {
        calls.values.filter { $0.status.isOngoing }
    }

    func call(_ id: CallId) -> CallState? {
        return calls[id]
    }

    func call(withPeer peerHash: String, accountId: String) -> CallState? {
        return calls.values.first {
            $0.accountId == accountId && !$0.status.isTerminal && $0.peerHash == peerHash
        }
    }
}
