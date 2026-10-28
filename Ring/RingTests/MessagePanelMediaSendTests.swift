/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

@testable import Ring
import XCTest
import RxSwift

class MessagePanelMediaSendTests: XCTestCase {

    private var panelState: PublishSubject<State>!
    private var model: MessagePanelVM!
    private var disposeBag: DisposeBag!
    private var states: [MessagePanelState]!

    override func setUp() {
        super.setUp()
        panelState = PublishSubject<State>()
        model = MessagePanelVM(messagePanelState: panelState)
        disposeBag = DisposeBag()
        states = []
        panelState
            .subscribe(onNext: { [weak self] state in
                if let state = state as? MessagePanelState {
                    self?.states.append(state)
                }
            })
            .disposed(by: disposeBag)
    }

    override func tearDown() {
        panelState = nil
        model = nil
        disposeBag = nil
        states = nil
        super.tearDown()
    }

    private func loader(_ name: String?, delay: TimeInterval = 0) -> MessagePanelVM.ContentLoader {
        return { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                completion(name.map { .data(displayName: $0, data: Data()) })
            }
        }
    }

    private func waitForState() {
        let done = expectation(description: "panel state")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    private var sentNames: [String] {
        states.flatMap { state -> [String] in
            guard case .send(let messages) = state else { return [] }
            return messages.map { message in
                switch message.content {
                case .data(let displayName, _):
                    return displayName
                case .text(let text):
                    return "text:" + text
                case .file(_, let displayName, _):
                    return displayName
                }
            }
        }
    }

    private var failureCount: Int {
        states.filter { state in
            if case .attachmentFailed = state { return true }
            return false
        }.count
    }

    func testMediaKeepsSelectionOrderWhenLoadsFinishOutOfOrder() {
        model.send(media: [loader("a.jpeg", delay: 0.1), loader("b.mov")])
        waitForState()

        XCTAssertEqual(sentNames, ["a.jpeg", "b.mov"])
    }

    func testMediaIsSentInOneBatch() {
        model.send(media: [loader("a.jpeg"), loader("b.jpeg")])
        waitForState()

        XCTAssertEqual(states.count, 1)
    }

    func testFailedItemIsReportedAndTheRestIsSent() {
        model.send(media: [loader("a.jpeg"), loader(nil), loader("c.jpeg")])
        waitForState()

        XCTAssertEqual(sentNames, ["a.jpeg", "c.jpeg"])
        XCTAssertEqual(failureCount, 1)
    }

    func testNothingIsSentWhenEveryItemFails() {
        model.send(media: [loader(nil)])
        waitForState()

        XCTAssertTrue(sentNames.isEmpty)
        XCTAssertEqual(failureCount, 1)
    }

    private func reply(to content: String) -> MessageContentVM {
        let message = MessageModel(withId: UUID().uuidString, receivedDate: Date(),
                                   content: content, authorURI: jamiId1, incoming: true)
        let target = MessageContentVM(message: message, contextMenuState: PublishSubject<State>(),
                                      transferState: PublishSubject<State>(), isHistory: false,
                                      preferencesColor: .defaultSwarmColor)
        let quote = MessageReplyTargetVM(contextMenuState: PublishSubject<State>(),
                                         localJamiId: jamiId2, isIncoming: true)
        quote.target = target
        model.configureReplyTo(message: target, quote: quote)
        return target
    }

    func testSentMediaRepliesAndEndsTheReply() {
        let target = reply(to: "Lake?")

        model.send(media: [loader("a.jpeg"), loader("b.jpeg")])
        waitForState()

        guard case .send(let messages)? = states.first else {
            return XCTFail("Expected a send state")
        }
        XCTAssertTrue(messages.allSatisfy { $0.parentId == target.message.id })
        XCTAssertNil(model.messageToReply)
    }

    func testFailedExportKeepsTheReply() {
        let target = reply(to: "Lake?")

        model.send(media: [loader(nil)])
        waitForState()

        XCTAssertTrue(sentNames.isEmpty)
        XCTAssertEqual(model.messageToReply?.message.id, target.message.id)
        XCTAssertNotNil(model.quote)
    }

    func testReplyChosenWhileLoadingIsKept() {
        let first = reply(to: "Lake?")

        model.send(media: [loader("a.jpeg", delay: 0.1)])
        let second = reply(to: "Mountains?")
        waitForState()

        guard case .send(let messages)? = states.first else {
            return XCTFail("Expected a send state")
        }
        XCTAssertTrue(messages.allSatisfy { $0.parentId == first.message.id })
        XCTAssertEqual(model.messageToReply?.message.id, second.message.id)
    }

    func testMessagesHaveNoParentOutsideReply() {
        model.send(media: [loader("a.jpeg")])
        waitForState()

        guard case .send(let messages)? = states.first else {
            return XCTFail("Expected a send state")
        }
        XCTAssertTrue(messages.allSatisfy { $0.parentId.isEmpty })
    }
}
