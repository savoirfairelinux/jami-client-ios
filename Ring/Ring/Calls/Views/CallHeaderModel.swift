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

struct CallHeaderModel: Equatable {

    private static let maximumAvatars = 3
    static let empty = CallHeaderModel(call: nil, isConference: false,
                                       rows: [], pending: [], peerName: "")

    let title: String
    /// A Jami id carries meaning at both ends, a name does not — it picks the truncation.
    let titleIsIdentifier: Bool
    let isRecording: Bool
    let showsRoster: Bool
    let avatarURIs: [String]

    init(call: CallState?,
         isConference: Bool,
         rows: [ConferenceParticipantRow],
         pending: [PendingParticipantRow],
         peerName: String) {
        self.isRecording = call?.peerIsRecording == true
        self.showsRoster = isConference || !pending.isEmpty
        let joinedURIs = Self.uniqueURIs(rows.map(\.uri))

        // The header stops naming a person exactly when the call stops being two people —
        // an unanswered invite is already more than that.
        if self.showsRoster {
            self.title = L10n.Calls.participantsInCall("\(joinedURIs.count)")
            self.titleIsIdentifier = false
            self.avatarURIs = Self.avatarURIs(rows: rows, pending: pending)
        } else {
            self.title = Self.peerTitle(call: call, peerName: peerName)
            self.titleIsIdentifier = self.title.isSHA1()
            self.avatarURIs = []
        }
    }

    /// Whoever is here, then whoever is on the way — an invitee's face is the clearest
    /// sign that the call is growing. One face per person: the same peer can be in a
    /// conference from several devices, and a repeated uri is not a second participant.
    private static func avatarURIs(rows: [ConferenceParticipantRow],
                                   pending: [PendingParticipantRow]) -> [String] {
        let candidates = rows.filter { !$0.isLocal }.map(\.uri) + pending.map(\.uri)
        return Array(uniqueURIs(candidates).prefix(maximumAvatars))
    }

    /// Preserve the daemon's first row for a uri while collapsing its per-device rows.
    private static func uniqueURIs(_ uris: [String]) -> [String] {
        var seen = Set<String>()
        return uris.filter { seen.insert($0).inserted }
    }

    /// An unresolved profile reports the peer's hash as its name, which must never
    /// displace a name the daemon already gave us.
    private static func peerTitle(call: CallState?, peerName: String) -> String {
        if !peerName.isEmpty && !peerName.isSHA1() { return peerName }
        return call?.bestName ?? peerName
    }
}

extension CallHeaderModel {

    /// The header's second line: what the call is doing, or how long it has been doing it.
    static func statusLine(for call: CallState?, now: Date = Date()) -> String {
        guard let call = call else { return "" }
        let description = statusDescription(for: call.status)
        guard description.isEmpty else { return description }
        if !call.pendingInvites.isEmpty { return L10n.Calls.inviting }
        guard let startedAt = call.startedAt else { return "" }
        return String.durationFormatted(seconds: Int(now.timeIntervalSince(startedAt)))
    }

    private static func statusDescription(for status: CallStatus) -> String {
        switch status {
        case .incoming: return L10n.Global.incomingCall
        case .connecting: return L10n.Calls.connecting
        case .ringing: return L10n.Calls.ringing
        case .current: return ""
        case .held: return L10n.Accessibility.Calls.Default.pauseCall
        case .terminated(.endedLocally): return ""
        case .terminated: return L10n.Calls.callFinished
        }
    }
}
