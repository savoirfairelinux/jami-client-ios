/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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
import RxRelay

/// Durable single-call presentation state. Unlike a `PublishSubject`, the
/// relay replays the current call to a presenter created after CallKit answers.
final class CallPresentationState {
    let call = BehaviorRelay<CallState?>(value: nil)
    private var conference: ConferenceState?
    private var lastKnownConference: ConferenceState?

    func present(_ call: CallState) {
        assertMainQueue()
        guard self.call.value?.id != call.id else { return }
        clearConferenceTracking()
        set(call)
    }

    func replace(_ replaced: CallId, with call: CallState) {
        assertMainQueue()
        guard self.call.value?.id == replaced else { return }
        clearConferenceTracking()
        set(call)
    }

    func clear(_ callId: CallId) {
        assertMainQueue()
        guard call.value?.id == callId else { return }
        clearConferenceTracking()
        set(nil)
    }

    func conferenceUpdated(_ conference: ConferenceState) {
        assertMainQueue()
        guard let call = call.value else { return }
        let isTracked = self.conference?.id == conference.id
            || lastKnownConference?.id == conference.id
        let isMember = conference.memberCallIds.contains(call.id)
        let bootstrapsTracking = !isTracked && call.conferenceId == conference.id
        guard isMember || isTracked || bootstrapsTracking else { return }
        lastKnownConference = conference
        self.conference = isMember ? conference : nil
    }

    func conferenceEnded(_ conferenceId: ConfId, remainingCall: CallState?) {
        assertMainQueue()
        let wasMember = conference?.id == conferenceId
        guard wasMember || lastKnownConference?.id == conferenceId else { return }
        clearConferenceTracking()
        guard wasMember, let remainingCall = remainingCall,
              remainingCall.id != call.value?.id else { return }
        set(remainingCall)
    }

    func callEnded(_ endedCall: CallState, availableCalls: [CallId: CallState]) {
        assertMainQueue()
        guard call.value?.id == endedCall.id else { return }
        if endedCall.status != .terminated(.endedLocally),
           let session = conference ?? lastKnownConference,
           let remainingCallId = remainingCallId(in: session, availableCalls: availableCalls),
           let remainingCall = availableCalls[remainingCallId] {
            conference = session
            lastKnownConference = session
            set(remainingCall)
            return
        }
        clear(endedCall.id)
    }

    private func remainingCallId(in session: ConferenceState,
                                 availableCalls: [CallId: CallState]) -> CallId? {
        return session.memberCallIds
            .sorted { $0.raw < $1.raw }
            .first {
                $0 != call.value?.id && availableCalls[$0]?.status.isTerminal == false
            }
    }

    private func clearConferenceTracking() {
        conference = nil
        lastKnownConference = nil
    }

    /// CallKit answers and libjami events both reach the relay on the main
    /// queue; the presenter's replay depends on that single writer.
    private func set(_ call: CallState?) {
        assertMainQueue()
        self.call.accept(call)
    }

    private func assertMainQueue() {
#if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
#endif
    }
}
