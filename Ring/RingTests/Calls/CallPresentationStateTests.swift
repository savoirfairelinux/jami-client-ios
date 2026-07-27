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
        let call = makeCall(id: "call-1")
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
        let placeholder = makeCall(id: "local:placeholder")
        let matched = makeCall(id: "call-1")
        state.present(placeholder)

        state.replace(placeholder.id, with: matched)
        state.clear(placeholder.id)

        XCTAssertEqual(state.call.value, matched,
                       "ending the placeholder must not dismiss the matched call")

        state.clear(matched.id)
        XCTAssertNil(state.call.value)
    }

    private func makeCall(id: String) -> CallState {
        return CallState(id: CallId(raw: id), accountId: "account",
                         direction: .incoming, peerUri: "bob",
                         status: .current, media: [.audio()], isAudioOnly: true)
    }
}
