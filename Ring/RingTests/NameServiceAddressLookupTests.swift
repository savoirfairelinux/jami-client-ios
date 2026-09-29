/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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
import RxSwift
@testable import Ring

final class NameServiceAddressLookupTests: XCTestCase {
    private var adapter: MockNameRegistrationAdapter!
    private var service: NameService!
    private var now = Date(timeIntervalSince1970: 1_000_000)
    private var disposeBag = DisposeBag()

    override func setUp() {
        super.setUp()
        adapter = MockNameRegistrationAdapter()
        service = NameService(withNameRegistrationAdapter: adapter, currentDate: { [unowned self] in self.now })
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = DisposeBag()
        service = nil
        adapter = nil
        super.tearDown()
    }

    func testConcurrentRequestsShareOneLookup() {
        let (first, second) = expectLookups(1) {
            (self.collectNames(accountId: accountId1), self.collectNames(accountId: accountId1))
        }

        answer(accountId: accountId1, state: .found, name: registeredName1)

        XCTAssertEqual(first(), [registeredName1])
        XCTAssertEqual(second(), [registeredName1])
        XCTAssertEqual(adapter.addressLookupCount, 1)
    }

    func testFoundNameIsReusedWithoutNewLookup() {
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }
        answer(accountId: accountId1, state: .found, name: registeredName1)
        now += 24 * 60 * 60

        let names = expectLookups(0) { self.collectNames(accountId: accountId1) }

        XCTAssertEqual(names(), [registeredName1])
    }

    func testLaterAnswersDoNotReplaceFoundName() {
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }
        answer(accountId: accountId1, state: .found, name: registeredName1)

        answer(accountId: accountId1, state: .notFound, name: "")
        answer(accountId: accountId1, state: .error, name: "")
        let names = expectLookups(0) { self.collectNames(accountId: accountId1) }

        XCTAssertEqual(names(), [registeredName1])
    }

    func testNotFoundIsRequestedAgainOnlyAfterFiveMinutes() {
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }
        answer(accountId: accountId1, state: .notFound, name: "")

        now += 5 * 60 - 1
        expectLookups(0) { _ = self.collectNames(accountId: accountId1) }
        now += 2
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }
    }

    func testUnansweredLookupIsRetriedAfterThirtySeconds() {
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }

        now += 29
        expectLookups(0) { _ = self.collectNames(accountId: accountId1) }
        now += 2
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }
    }

    func testFailedLookupIsRetriedAfterThirtySeconds() {
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }
        answer(accountId: accountId1, state: .error, name: "")

        now += 29
        expectLookups(0) { _ = self.collectNames(accountId: accountId1) }
        now += 2
        expectLookups(1) { _ = self.collectNames(accountId: accountId1) }
    }

    func testLookupsAreSeparatePerAccount() {
        let names = expectLookups(1) { self.collectNames(accountId: accountId1) }
        let otherNames = expectLookups(1) { self.collectNames(accountId: accountId2) }

        answer(accountId: accountId1, state: .found, name: registeredName1)

        XCTAssertEqual(names(), [registeredName1])
        XCTAssertEqual(otherNames(), [])
    }

    // MARK: helpers

    private func collectNames(accountId: String) -> () -> [String] {
        var names = [String]()
        service.registeredName(forAddress: jamiId1, accountId: accountId)
            .subscribe(onNext: { names.append($0) })
            .disposed(by: disposeBag)
        return { names }
    }

    @discardableResult
    private func expectLookups<T>(_ count: Int, file: StaticString = #filePath, line: UInt = #line,
                                  _ action: () -> T) -> T {
        let expected = adapter.addressLookupCount + count
        let result = action()
        let deadline = Date().addingTimeInterval(2)
        while adapter.addressLookupCount < expected && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        let settled = expectation(description: "no further address lookups")
        settled.isInverted = true
        wait(for: [settled], timeout: 0.2)
        XCTAssertEqual(adapter.addressLookupCount, expected, file: file, line: line)
        return result
    }

    private func answer(accountId: String, state: LookupNameState, name: String) {
        let response = LookupNameResponse()
        response.accountId = accountId
        response.requestedName = jamiId1
        response.address = jamiId1
        response.state = state
        response.name = name
        service.registeredNameFound(with: response)
    }
}
