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
        calls.append(call)
    }

    func removeCall(uuid: UUID) {
        if let index = calls.firstIndex(where: { call in
            call.uuid == uuid
        }) {
            calls.remove(at: index)
        }
    }

    func getCalls(jamiId: String) -> [MockCall]? {
        return calls.filter { call in
            call.jamiId == jamiId
        }
    }

    func getCalls() -> [MockCall] {
        return calls
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

    override func reportNewIncomingCall(
        with UUID: UUID,
        update: CXCallUpdate,
        completion _: ((Error?) -> Void)? = nil
    ) {
        if let handle = update.remoteHandle {
            let call = MockCall(uuid: UUID, jamiId: handle.value)
            systemCalls.reportCall(call: call)
        }
    }
}

class MockCallController: CXCallController {
    var systemCalls: MocSystemCalls

    init(systemCalls: MocSystemCalls) {
        self.systemCalls = systemCalls
        super.init(queue: DispatchQueue(label: "MockCallController"))
    }

    override func request(_ transaction: CXTransaction, completion: @escaping (Error?) -> Void) {
        for action in transaction.actions {
            if let startCallAction = action as? CXStartCallAction {
                let uuid = startCallAction.callUUID
                let jamiId = startCallAction.contactIdentifier!
                let newCall = MockCall(uuid: uuid, jamiId: jamiId)
                systemCalls.reportCall(call: newCall)
            } else if let endCallAction = action as? CXEndCallAction {
                let uuid = endCallAction.callUUID
                systemCalls.removeCall(uuid: uuid)
            }
        }
        completion(nil)
    }
}
