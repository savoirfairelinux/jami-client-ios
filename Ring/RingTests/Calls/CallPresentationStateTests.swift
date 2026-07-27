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

import XCTest
import RxSwift
@testable import Ring

final class CallPresentationStateTests: XCTestCase {

    func testLateObserverReceivesCallWaitingForPresentation() {
        let state = CallPresentationState()
        let call = makeCall(id: CallTestFixtures.callId)
        state.present(call)

        var received: CallState?
        let disposable = state.call
            .compactMap { $0 }
            .take(1)
            .subscribe(onNext: { received = $0 })

        XCTAssertEqual(received, call)
        withExtendedLifetime(disposable) {}
    }

    func testMatchedCallReplacesPlaceholderUntilRealCallEnds() {
        let state = CallPresentationState()
        let placeholder = makeCall(id: CallId.local())
        let matched = makeCall(id: CallTestFixtures.callId)
        state.present(placeholder)

        state.replace(placeholder.id, with: matched)
        state.clear(placeholder.id)

        XCTAssertEqual(state.call.value, matched,
                       "ending the placeholder must not dismiss the matched call")

        state.clear(matched.id)
        XCTAssertNil(state.call.value)
    }

    func testCallWaitingForTheScreenOutlivesTheCallItSuperseded() {
        let state = CallPresentationState()
        let onScreen = makeCall(id: CallTestFixtures.callId)
        let waiting = makeCall(id: CallTestFixtures.secondaryCallId)
        state.present(onScreen)
        state.present(waiting)

        state.clear(onScreen.id)

        XCTAssertEqual(state.call.value, waiting,
                       "the call still waiting must survive the end of the one it replaced")
    }

    func testEndedConferenceLegContinuesOnRemainingCall() {
        let state = CallPresentationState()
        var ended = makeCall(id: CallTestFixtures.callId)
        let remaining = makeCall(id: CallTestFixtures.secondaryCallId)
        var conference = CallTestFixtures.conference()
        conference.memberCallIds = [ended.id, remaining.id]
        state.present(ended)
        state.conferenceUpdated(conference)

        conference.memberCallIds = [remaining.id]
        state.conferenceUpdated(conference)
        ended.status = .terminated(.over)
        state.callEnded(ended, availableCalls: [remaining.id: remaining])

        XCTAssertEqual(state.call.value, remaining,
                       "a late presenter must replay the call that keeps the session alive")
    }

    func testLatePresentationUsesCallsConferenceIdToFollowRemainingCall() {
        let state = CallPresentationState()
        var ended = makeCall(id: CallTestFixtures.callId)
        ended.conferenceId = CallTestFixtures.conferenceId
        let remaining = makeCall(id: CallTestFixtures.secondaryCallId)
        var conference = CallTestFixtures.conference()
        conference.memberCallIds = [remaining.id]
        state.present(ended)

        state.conferenceUpdated(conference)
        ended.status = .terminated(.over)
        state.callEnded(ended, availableCalls: [remaining.id: remaining])

        XCTAssertEqual(state.call.value, remaining,
                       "presentation may begin after the initial conference event")
    }

    func testRemovedConferenceDoesNotRetargetPreviouslyDetachedCall() {
        let state = CallPresentationState()
        var detached = makeCall(id: CallTestFixtures.callId)
        detached.conferenceId = CallTestFixtures.conferenceId
        let remaining = makeCall(id: CallTestFixtures.secondaryCallId)
        var conference = CallTestFixtures.conference()
        conference.memberCallIds = [detached.id, remaining.id]
        state.present(detached)
        state.conferenceUpdated(conference)

        conference.memberCallIds = [remaining.id]
        state.conferenceUpdated(conference)
        state.conferenceEnded(conference.id, remainingCall: remaining)
        detached.status = .terminated(.over)
        state.callEnded(detached, availableCalls: [remaining.id: remaining])

        XCTAssertNil(state.call.value,
                     "conference removal ends the detached call's relationship to its members")
    }

    func testConferenceRemovalRetargetsCallThatWasStillAMember() {
        let state = CallPresentationState()
        let onScreen = makeCall(id: CallTestFixtures.callId)
        let remaining = makeCall(id: CallTestFixtures.secondaryCallId)
        var conference = CallTestFixtures.conference()
        conference.memberCallIds = [onScreen.id, remaining.id]
        state.present(onScreen)
        state.conferenceUpdated(conference)

        state.conferenceEnded(conference.id, remainingCall: remaining)

        XCTAssertEqual(state.call.value, remaining)
    }

    private func makeCall(id: CallId) -> CallState {
        return CallTestFixtures.call(id: id, direction: .incoming,
                                     media: [.audio()], isAudioOnly: true)
    }
}
