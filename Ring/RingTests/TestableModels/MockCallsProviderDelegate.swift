/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

import Foundation
@testable import Ring

class MocSystemCalls {
    var calls = [MockCall]()
    
    func reportCall(call: MockCall) {
        self.calls.append(call)
    }
    
    func removeCall(uuid: UUID) {
        if let index = calls.firstIndex(where: { call in
            call.uuid == uuid
        }) {
            calls.remove(at: index)
        }
    }
    
    func getCalls() -> [MockCall] {
        return self.calls
    }
}

class MockCall {
    let uuid: UUID
    let jamiId: String
    
    init(uuid: UUID, jamiId: String) {
        self.uuid = uuid
        self.jamiId = jamiId
    }
}

class MockCXProvider: CXProvider {
    var systemCalls: MocSystemCalls
    
    init(systemCalls: MocSystemCalls) {
        self.systemCalls = systemCalls
        super.init(configuration: CallsHelpers.providerConfiguration())
    }
    
    override func reportNewIncomingCall(with UUID: UUID, update: CXCallUpdate, completion: ((Error?) -> Void)? = nil) {
        if let handle = update.remoteHandle {
            let call = MockCall(uuid: UUID, jamiId: handle.value)
            self.systemCalls.reportCall(call: call)
        }
    }
}

class MockCallsProviderDelegate: NSObject, CXProviderDelegate {
    var systemCalls: MocSystemCalls
    
    init(systemCalls: MocSystemCalls) {
        self.systemCalls = systemCalls
        super.init()
    }
    
    func providerDidReset(_ provider: CXProvider) {
    }
    
    func getCalls(jamiId: String) -> [MockCall]? {
        return self.systemCalls.getCalls().filter { call in
            call.jamiId == jamiId
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuid = action.callUUID
        self.systemCalls.removeCall(uuid: uuid)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let uuid = action.callUUID
        let jamiId = action.contactIdentifier!
        let newCall = MockCall(uuid: uuid, jamiId: jamiId)
        self.systemCalls.reportCall(call: newCall)
        action.fulfill()
    }
}
