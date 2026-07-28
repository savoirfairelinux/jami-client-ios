/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

import Network
import RxSwift
import XCTest
@testable import Ring

class NetworkServiceTests: XCTestCase {

    private var service: NetworkService!
    private var disposeBag: DisposeBag!
    private var changes: [ConnectionType]!

    override func setUp() {
        super.setUp()
        service = NetworkService()
        disposeBag = DisposeBag()
        changes = []
        service.connectivityChangedObservable
            .subscribe(onNext: { [weak self] state in
                self?.changes.append(state)
            })
            .disposed(by: disposeBag)
    }

    override func tearDown() {
        service = nil
        disposeBag = nil
        changes = nil
        super.tearDown()
    }

    /// The first path evaluation describes the network the daemon already
    /// registered with; reporting it would restart the DHT for nothing.
    func testInitialPathDoesNotReportAConnectivityChange() {
        service.handle(status: .satisfied)

        XCTAssertTrue(changes.isEmpty)
        XCTAssertEqual(service.connectionState.value, .connected)
    }

    func testInitialPathWithoutNetworkDoesNotReportAConnectivityChange() {
        service.handle(status: .unsatisfied)

        XCTAssertTrue(changes.isEmpty)
        XCTAssertEqual(service.connectionState.value, .none)
    }

    func testLaterTransitionsAreReported() {
        service.handle(status: .satisfied)
        service.handle(status: .unsatisfied)
        service.handle(status: .satisfied)

        XCTAssertEqual(changes, [.none, .connected])
    }

    func testRepeatedStatusIsNotReported() {
        service.handle(status: .satisfied)
        service.handle(status: .unsatisfied)
        service.handle(status: .unsatisfied)

        XCTAssertEqual(changes, [.none])
    }
}
