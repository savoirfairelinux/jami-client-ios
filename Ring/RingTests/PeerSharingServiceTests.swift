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

import XCTest
import RxSwift
import RxRelay
@testable import Ring

class PeerSharingServiceTests: XCTestCase {

    private let testAccountId = "acc-001"
    private let testPeerUri = "jami:peer-001"
    private let testTunnelId = "tunnel-001"

    private var service: PeerSharingService!
    private var mockAdapter: ObjCMockPeerServicesAdapter!
    private var disposeBag: DisposeBag!

    private var testService: PeerServiceInfo {
        PeerServiceInfo(
            id: "svc-001",
            name: "My Web App",
            description: "A test service",
            scheme: "http",
            device: "device-001"
        )
    }

    override func setUp() {
        super.setUp()
        mockAdapter = ObjCMockPeerServicesAdapter()
        disposeBag = DisposeBag()
        service = PeerSharingService(withPeerServicesAdapter: mockAdapter)
    }

    override func tearDown() {
        disposeBag = nil
        service = nil
        mockAdapter = nil
        super.tearDown()
    }

    // MARK: - Test 1: Full tunnel lifecycle

    func testTunnelLifecycle_PendingToActiveToClosedCleansUp() {
        let pendingExpectation = XCTestExpectation(description: "Pending state emitted")
        let activeExpectation = XCTestExpectation(description: "Active state emitted")
        let emptyExpectation = XCTestExpectation(description: "Empty state emitted after close")

        var stateHistory = [PeerTunnelState]()

        service.observeTunnelState(accountId: testAccountId, peerUri: testPeerUri)
            .subscribe(onNext: { state in
                stateHistory.append(state)

                if state.pendingServices.contains("svc-001") && state.activeTunnels.isEmpty {
                    pendingExpectation.fulfill()
                }
                if let tunnel = state.activeTunnels["svc-001"], tunnel.tunnelId == "tunnel-001" {
                    activeExpectation.fulfill()
                }
                if stateHistory.count >= 3
                    && state.activeTunnels.isEmpty
                    && state.pendingServices.isEmpty
                    && stateHistory.contains(where: { !$0.activeTunnels.isEmpty }) {
                    emptyExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: testAccountId, peerUri: testPeerUri, service: testService)

        wait(for: [pendingExpectation], timeout: 2.0)

        service.serviceTunnelOpened(withAccountId: testAccountId,
                                   tunnelId: testTunnelId,
                                   localPort: 8080)

        wait(for: [activeExpectation], timeout: 2.0)

        service.serviceTunnelClosed(withAccountId: testAccountId,
                                   tunnelId: testTunnelId,
                                   reason: "user")

        wait(for: [emptyExpectation], timeout: 2.0)
    }

    // MARK: - Test 2: Open failure cleans up

    func testOpenTunnelFailure_CleansUpOrphanState() {
        mockAdapter.openTunnelReturnValue = ""

        let cleanedUpExpectation = XCTestExpectation(description: "State returns to empty after failure")

        var sawPending = false

        service.observeTunnelState(accountId: testAccountId, peerUri: testPeerUri)
            .subscribe(onNext: { state in
                if state.pendingServices.contains("svc-001") {
                    sawPending = true
                }
                if sawPending && state.pendingServices.isEmpty && state.activeTunnels.isEmpty {
                    cleanedUpExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: testAccountId, peerUri: testPeerUri, service: testService)

        wait(for: [cleanedUpExpectation], timeout: 2.0)
        XCTAssertTrue(sawPending, "Service should have briefly entered pending state")
    }

    // MARK: - Test 3: TunnelClosed before TunnelOpened cleans pending

    func testTunnelClosedWhilePending_CleansPendingServices() {
        let pendingExpectation = XCTestExpectation(description: "Pending state emitted")
        let cleanedExpectation = XCTestExpectation(description: "Pending cleaned up by TunnelClosed")

        var sawPending = false

        service.observeTunnelState(accountId: testAccountId, peerUri: testPeerUri)
            .subscribe(onNext: { state in
                if state.pendingServices.contains("svc-001") {
                    sawPending = true
                    pendingExpectation.fulfill()
                }
                if sawPending && state.pendingServices.isEmpty && state.activeTunnels.isEmpty {
                    cleanedExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: testAccountId, peerUri: testPeerUri, service: testService)

        wait(for: [pendingExpectation], timeout: 2.0)

        service.serviceTunnelClosed(withAccountId: testAccountId,
                                   tunnelId: testTunnelId,
                                   reason: "peer_disconnected")

        wait(for: [cleanedExpectation], timeout: 2.0)
        XCTAssertTrue(sawPending, "Service should have been in pending state before close")
    }
}
