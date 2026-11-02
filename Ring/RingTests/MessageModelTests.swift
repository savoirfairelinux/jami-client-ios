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
    func testCallFailureReasonsOverrideGenericCallText() {
        let outcomes = [
            ("busy", "generatedMessage.callBusy", "Busy"),
            ("declined", "generatedMessage.callDeclined", "Call declined"),
            ("no_device", "generatedMessage.callUnreachable", "Unreachable peer")
        ]
        for author in [jamiId1, jamiId2] {
            for (reason, key, fallback) in outcomes {
                for duration: String? in [nil, "0", "-1", "65000"] {
                    var info = ["type": "application/call-history+json", "author": author,
                                "reason": reason]
                    info["duration"] = duration
                    let message = MessageModel(withInfo: info, localJamiId: jamiId1)
                    let expected = NSLocalizedString(key, bundle: Bundle(for: MessageModel.self),
                                                     value: fallback, comment: "")
                    XCTAssertEqual(message.content, expected, "reason \(reason), duration \(String(describing: duration))")
                    XCTAssertEqual(message.accessibilityLabelValue, expected)
                }
            }
        }
    }

    func testCallWithoutRecognizedReasonPreservesExistingText() {
        for author in [jamiId1, jamiId2] {
            let incoming = author != jamiId1
            let label = incoming ? L10n.Global.incomingCall : L10n.GeneratedMessage.outgoingCall
            let missed = incoming ? L10n.GeneratedMessage.missedIncomingCall : L10n.GeneratedMessage.missedOutgoingCall
            let cases: [(String?, String)] = [(nil, missed), ("invalid", missed),
                                              ("-1", label), ("0", label + " - 00:00"),
                                              ("65000", label + " - 01:05")]
            for reason: String? in [nil, "", "unknown"] {
                for (duration, expected) in cases {
                    var info = ["type": "application/call-history+json", "author": author]
                    info["reason"] = reason
                    info["duration"] = duration
                    let message = MessageModel(withInfo: info, localJamiId: jamiId1)
                    XCTAssertEqual(message.content, expected)
                }
            }
        }
    }

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
        panel.configureReplyTo(message: first, quote: MessageReplyTargetVM(contextMenuState: PublishSubject<State>(), localJamiId: jamiId1, isIncoming: true))
        XCTAssertEqual(panel.inReplyTo, first.username)
        first.username = "Alicia".withYourselfSuffix()
        XCTAssertEqual(panel.inReplyTo, first.username)
        let second = replyMessage(author: jamiId2, name: "Bob")
        panel.configureReplyTo(message: second, quote: MessageReplyTargetVM(contextMenuState: PublishSubject<State>(), localJamiId: jamiId1, isIncoming: true))
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

    func testLocalContactEventsHaveTextWithoutNameLookup() {
        for action in [ContactAction.add, .join, .remove, .ban, .unban] {
            let message = MessageModel(withInfo: ["type": "member", "action": action.rawValue,
                                                 "uri": jamiId1, "author": jamiId1],
                                       localJamiId: jamiId1)
            let model = ContactMessageVM(message: message)
            model.setInfoState(state: PublishSubject<State>())

            XCTAssertEqual(model.content, action.getInteractionString(name: jamiId1, isIncomig: false))
            XCTAssertFalse(model.content.isEmpty, "action \(action)")
            XCTAssertEqual(model.observableContent.value, model.content)
        }
    }

    func testIncomingContactEventsHaveTextBeforeNameLookup() {
        for uri in [jamiId2, ""] {
            for action in [ContactAction.add, .join, .remove, .ban, .unban] {
                let message = MessageModel(withInfo: ["type": "member", "action": action.rawValue,
                                                     "uri": uri, "author": jamiId2],
                                           localJamiId: jamiId1)
                let model = ContactMessageVM(message: message)

                XCTAssertEqual(model.content, action.getInteractionString(name: jamiId2, isIncomig: true))
                XCTAssertFalse(model.content.isEmpty, "action \(action)")
                XCTAssertEqual(model.observableContent.value, model.content)
            }
        }
    }

    func testContactEventTextUsesResolvedNameAndFallsBackToMemberURI() {
        let message = MessageModel(withInfo: ["type": "member", "action": "join",
                                             "uri": jamiId2, "author": jamiId1],
                                   localJamiId: jamiId1)
        let model = ContactMessageVM(message: message)
        model.username = "Alice"
        XCTAssertEqual(model.content, L10n.GeneratedMessage.invitationAccepted("Alice"))
        XCTAssertEqual(model.observableContent.value, model.content)

        model.username = ""
        XCTAssertEqual(model.content, L10n.GeneratedMessage.invitationAccepted(jamiId2))
        XCTAssertEqual(model.observableContent.value, model.content)
    }

    func testInitialConversationEventPreservesItsText() {
        let message = MessageModel(withInfo: ["type": "initial", "author": jamiId1],
                                   localJamiId: jamiId1)
        let model = ContactMessageVM(message: message)
        XCTAssertEqual(model.content, L10n.GeneratedMessage.swarmCreated)
        XCTAssertEqual(model.observableContent.value, model.content)
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
