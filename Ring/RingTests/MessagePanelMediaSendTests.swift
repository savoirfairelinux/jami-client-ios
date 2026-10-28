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

    private var model: MessagePanelVM!
    private var disposeBag: DisposeBag!
    private var states: [MessagePanelState]!
    private var stateArrived: XCTestExpectation?

    override func setUp() {
        super.setUp()
        let panelState = PublishSubject<State>()
        model = MessagePanelVM(messagePanelState: panelState)
        disposeBag = DisposeBag()
        states = []
        panelState
            .subscribe(onNext: { [weak self] state in
                guard let state = state as? MessagePanelState else { return }
                self?.states.append(state)
                self?.stateArrived?.fulfill()
            })
            .disposed(by: disposeBag)
    }

    override func tearDown() {
        model = nil
        disposeBag = nil
        states = nil
        stateArrived = nil
        super.tearDown()
    }

    private static func content(_ name: String?) -> OutgoingMessage.Content? {
        name.map { .data(displayName: $0, data: Data()) }
    }

    private func loaded(_ name: String?) -> MessagePanelVM.ContentLoader {
        return { completion in completion(Self.content(name)) }
    }

    /// A loader that finishes only when the test calls `finish`.
    private func deferred() -> (load: MessagePanelVM.ContentLoader, finish: (String?) -> Void) {
        var completion: ((OutgoingMessage.Content?) -> Void)?
        return ({ completion = $0 }, { name in completion?(Self.content(name)) })
    }

    private func expectStates(_ count: Int, while action: () -> Void) {
        stateArrived = expectation(description: "panel state")
        stateArrived?.expectedFulfillmentCount = count
        action()
        wait(for: [stateArrived!], timeout: 1)
    }

    private var sent: [OutgoingMessage] {
        states.flatMap { state -> [OutgoingMessage] in
            if case .send(let messages) = state {
                return messages
            }
            return []
        }
    }

    private var sentNames: [String] {
        sent.compactMap { message in
            if case .data(let displayName, _) = message.content {
                return displayName
            }
            return nil
        }
    }

    private var failureCount: Int {
        states.filter { state in
            if case .attachmentFailed = state { return true }
            return false
        }.count
    }

    @discardableResult
    private func reply(to text: String) -> MessageContentVM {
        let message = MessageModel(withId: UUID().uuidString, receivedDate: Date(),
                                   content: text, authorURI: jamiId1, incoming: true)
        let target = MessageContentVM(message: message, contextMenuState: PublishSubject<State>(),
                                      transferState: PublishSubject<State>(), isHistory: false,
                                      preferencesColor: .defaultSwarmColor)
        let quote = MessageReplyTargetVM(contextMenuState: PublishSubject<State>(),
                                         localJamiId: jamiId2, isIncoming: true)
        quote.target = target
        model.configureReplyTo(message: target, quote: quote)
        return target
    }

    func testMediaKeepsSelectionOrderWhenLoadsFinishOutOfOrder() {
        let first = deferred()
        let second = deferred()

        expectStates(1) {
            model.send(media: [first.load, second.load])
            second.finish("b.mov")
            first.finish("a.jpeg")
        }

        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(sentNames, ["a.jpeg", "b.mov"])
    }

    func testFailedItemIsReportedAndTheRestIsSent() {
        expectStates(3) {
            model.send(media: [loaded("a.jpeg"), loaded(nil), loaded("c.jpeg")])
        }

        XCTAssertEqual(sentNames, ["a.jpeg", "c.jpeg"])
        XCTAssertEqual(failureCount, 1)
    }

    func testSentMediaRepliesAndEndsTheReply() {
        let target = reply(to: "Lake?")

        expectStates(2) {
            model.send(media: [loaded("a.jpeg"), loaded("b.jpeg")])
        }

        XCTAssertTrue(sent.allSatisfy { $0.parentId == target.message.id })
        XCTAssertNil(model.messageToReply)
    }

    func testFailedExportSendsNothingAndKeepsTheReply() {
        let target = reply(to: "Lake?")

        expectStates(1) {
            model.send(media: [loaded(nil)])
        }

        XCTAssertTrue(sent.isEmpty)
        XCTAssertEqual(failureCount, 1)
        XCTAssertEqual(model.messageToReply?.message.id, target.message.id)
    }

    func testPendingSendDoesNotKeepThePanelAlive() {
        let panelState = PublishSubject<State>()
        var panel: MessagePanelVM? = MessagePanelVM(messagePanelState: panelState)
        weak var weakPanel = panel
        var emitted = false
        let subscription = panelState.subscribe(onNext: { _ in emitted = true })
        let pending = deferred()

        panel?.send(media: [{ [panel] completion in
            _ = panel
            pending.load(completion)
        }])
        panel = nil

        XCTAssertNil(weakPanel)
        let settled = expectation(description: "main queue settled")
        pending.finish("a.mov")
        DispatchQueue.main.async { DispatchQueue.main.async { settled.fulfill() } }
        wait(for: [settled], timeout: 1)
        XCTAssertFalse(emitted)
        subscription.dispose()
    }

    func testReplyIsKeptForDraftAttachments() {
        let target = reply(to: "Lake?")
        model.attach(displayName: "notes.pdf", kind: .document) { $0(Self.content("notes.pdf")) }

        expectStates(1) {
            model.send(media: [loaded("a.jpeg")])
        }

        XCTAssertTrue(sent.allSatisfy { $0.parentId == target.message.id })
        XCTAssertEqual(model.messageToReply?.message.id, target.message.id)
        XCTAssertEqual(model.attachments.count, 1)
    }

    func testReplyChosenWhileLoadingIsKept() {
        let first = reply(to: "Lake?")
        let pending = deferred()
        model.send(media: [pending.load])
        let second = reply(to: "Mountains?")

        expectStates(1) {
            pending.finish("a.jpeg")
        }

        XCTAssertTrue(sent.allSatisfy { $0.parentId == first.message.id })
        XCTAssertEqual(model.messageToReply?.message.id, second.message.id)
    }
}
