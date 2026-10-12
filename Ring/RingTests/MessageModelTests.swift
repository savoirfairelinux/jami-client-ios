/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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
@testable import Ring

final class MessageModelTests: XCTestCase {
    func testMemberEventParsesEachDaemonAction() {
        let expected: [String: ContactAction] = [
            "add": .add,
            "join": .join,
            "remove": .remove,
            "ban": .ban,
            "unban": .unban
        ]
        for (action, contactAction) in expected {
            XCTAssertEqual(memberEventAction(action), contactAction, "action \(action)")
        }
    }

    private func memberEventAction(_ action: String) -> ContactAction? {
        let info = [MessageAttributes.type.rawValue: "member",
                    MessageAttributes.action.rawValue: action,
                    MessageAttributes.uri.rawValue: jamiId2]
        let message = MessageData(withInfo: info, localJamiId: jamiId1)
        guard case .contact(let parsed) = message.type else { return nil }
        return parsed
    }
}
