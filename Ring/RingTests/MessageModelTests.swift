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
import RxSwift
import RxRelay
import Combine
@testable import Ring

final class MessageModelTests: XCTestCase {
    private func replyMessage(author: String, name: String) -> MessageContentVM {
        let message = MessageModel(withId: UUID().uuidString, receivedDate: Date(),
                                   content: "Hello", authorURI: author, incoming: false)
        let model = MessageContentVM(message: message, contextMenuState: PublishSubject<State>(),
                                     transferState: PublishSubject<State>(), isHistory: false,
                                     preferencesColor: .defaultSwarmColor)
        model.username = name
        return model
    }

    func testReplyQuotePreservesResolvedLocalNameIncludingLegacyAuthor() {
        for author in [jamiId1, ""] {
            let quote = MessageReplyTargetVM(contextMenuState: PublishSubject<State>(),
                                             localJamiId: jamiId1, isIncoming: true)
            quote.target = replyMessage(author: author, name: "Alice".withYourselfSuffix())
            XCTAssertEqual(quote.authorName, "Alice".withYourselfSuffix())
            XCTAssertEqual(quote.accessibilitySummary, "\("Alice".withYourselfSuffix()): Hello")
        }
    }

    func testReplyQuoteDoesNotMarkAnotherAuthorAsLocal() {
        let quote = MessageReplyTargetVM(contextMenuState: PublishSubject<State>(),
                                         localJamiId: jamiId1, isIncoming: true)
        quote.target = replyMessage(author: jamiId2, name: "Alice")
        XCTAssertEqual(quote.authorName, "Alice")
    }

    func testReplyQuoteTracksLateResolvedName() {
        let target = replyMessage(author: jamiId1, name: "")
        let quote = MessageReplyTargetVM(contextMenuState: PublishSubject<State>(),
                                         localJamiId: jamiId1, isIncoming: true)
        quote.target = target
        let updated = expectation(description: "Quote receives resolved name")
        let subscription = quote.$authorName
            .filter { $0 == "Alice".withYourselfSuffix() }
            .prefix(1)
            .sink { _ in updated.fulfill() }
        target.username = "Alice".withYourselfSuffix()
        wait(for: [updated], timeout: 2)
        withExtendedLifetime(subscription) {}
    }

    func testReplyComposerTracksResolvedNameAndReleasesPreviousTarget() {
        let panel = MessagePanelVM(messagePanelState: PublishSubject<State>())
        let first = replyMessage(author: jamiId1, name: "Alice".withYourselfSuffix())
        panel.configureReplyTo(message: first)
        XCTAssertEqual(panel.inReplyTo, first.username)
        first.username = "Alicia".withYourselfSuffix()
        XCTAssertEqual(panel.inReplyTo, first.username)
        let second = replyMessage(author: jamiId2, name: "Bob")
        panel.configureReplyTo(message: second)
        first.username = "Changed"
        XCTAssertEqual(panel.inReplyTo, "Bob")
        panel.cancelReply()
        second.username = "Changed too"
        XCTAssertEqual(panel.inReplyTo, "")
    }

    func testRepeatedNameRequestsShareOneSubscriptionIncludingEmptyAuthor() {
        let message = replyMessage(author: "", name: "")
        let state = PublishSubject<State>()
        let bag = DisposeBag()
        var requests = 0
        message.infoState = state
        message.updateUserName()
        state.subscribe(onNext: { _ in
            requests += 1
            message.subscribeToNameObservable(BehaviorRelay(value: "Alice"))
        }).disposed(by: bag)
        message.updateUserName()
        message.updateUserName()
        XCTAssertEqual(requests, 1)
    }

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
