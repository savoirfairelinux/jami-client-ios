/*
 *  Copyright (C) 2020-2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import XCTest
import CallKit
@testable import Ring

final class CallProviderDelegateTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    func testStopCall_WhenPendingCallExists() {
        let callProviderDelegate = CallsProviderDelegate()
        let unhandeledCall = UnhandeledCall(peerId: jamiId1)
        callProviderDelegate.unhandeledCalls.insert(unhandeledCall)
        callProviderDelegate.stopCall(callUUID: unhandeledCall.uuid, participant: jamiId1)

        let result = callProviderDelegate.getUnhandeledCall(peerId: jamiId1)
        XCTAssertNil(result)
    }
}
