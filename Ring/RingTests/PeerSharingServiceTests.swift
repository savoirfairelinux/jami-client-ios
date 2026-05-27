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

import Foundation
import XCTest
import RxSwift
import RxRelay
@testable import Ring

class PeerSharingServiceTests: XCTestCase {

    private enum TestConstants {
        static let accountId = "test-account-id"
        static let otherAccountId = "other-test-account-id"
        static let peerId = "test-peer-id"
        static let otherPeerId = "other-test-peer-id"
        static let tunnelId = "test-tunnel-id"
        static let reopenedTunnelId = "test-reopened-tunnel-id"
        static let serviceId = "test-service-id"
        static let serviceName = "Test Web Service"
        static let serviceDescription = "Test service description"
        static let deviceId = "test-device-id"
        static let httpScheme = "http"
        static let httpsScheme = "https"
        static let uppercaseHttpScheme = "HTTP"
        static let uppercaseHttpsScheme = "HTTPS"
        static let unsupportedScheme = "ssh"
        static let loopbackHost = "127.0.0.1"
        static let defaultPort = 8080
        static let alternatePort = 9090
        static let securePort = 8443
        static let invalidPort = 0
        static let proactiveRequestId: UInt32 = 0
        static let queryRequestId: UInt32 = 42
        static let successStatus: Int32 = 0
        static let failedTunnelId = ""
        static let userCloseReason = "user"
        static let reconnectReason = "reconnect"
        static let completedReason = "done"
        static let peerDisconnectedReason = "peer_disconnected"

        static func loopbackURL(scheme: String, port: Int) -> String {
            "\(scheme)://\(loopbackHost):\(port)"
        }
    }

    private var service: PeerSharingService!
    private var mockAdapter: ObjCMockPeerServicesAdapter!
    private var disposeBag: DisposeBag!

    private var testService: PeerServiceInfo {
        PeerServiceInfo(
            id: TestConstants.serviceId,
            name: TestConstants.serviceName,
            description: TestConstants.serviceDescription,
            scheme: TestConstants.httpScheme,
            device: TestConstants.deviceId
        )
    }

    private func makeService(scheme: String) -> PeerServiceInfo {
        PeerServiceInfo(
            id: TestConstants.serviceId,
            name: TestConstants.serviceName,
            description: TestConstants.serviceDescription,
            scheme: scheme,
            device: TestConstants.deviceId
        )
    }

    private func makeTunnel(scheme: String = TestConstants.httpScheme,
                            localPort: Int = TestConstants.defaultPort) -> PeerTunnelInfo {
        PeerTunnelInfo(
            tunnelId: TestConstants.tunnelId,
            accountId: TestConstants.accountId,
            peerId: TestConstants.peerId,
            serviceId: TestConstants.serviceId,
            serviceName: TestConstants.serviceName,
            scheme: scheme,
            localPort: localPort
        )
    }

    override func setUp() {
        super.setUp()
        mockAdapter = ObjCMockPeerServicesAdapter()
        mockAdapter.openTunnelReturnValue = TestConstants.tunnelId
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

        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { state in
                stateHistory.append(state)

                if state.pendingServices.contains(TestConstants.serviceId) && state.activeTunnels.isEmpty {
                    pendingExpectation.fulfill()
                }
                if let tunnel = state.activeTunnels[TestConstants.serviceId],
                   tunnel.tunnelId == TestConstants.tunnelId {
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

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)

        wait(for: [pendingExpectation], timeout: 2.0)

        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))

        wait(for: [activeExpectation], timeout: 2.0)

        service.serviceTunnelClosed(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.userCloseReason)

        wait(for: [emptyExpectation], timeout: 2.0)
    }

    // MARK: - Test 2: Open failure cleans up

    func testOpenTunnelFailure_CleansUpOrphanState() {
        mockAdapter.openTunnelReturnValue = TestConstants.failedTunnelId

        let cleanedUpExpectation = XCTestExpectation(description: "State returns to empty after failure")

        var sawPending = false

        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { state in
                if state.pendingServices.contains(TestConstants.serviceId) {
                    sawPending = true
                }
                if sawPending && state.pendingServices.isEmpty && state.activeTunnels.isEmpty {
                    cleanedUpExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)

        wait(for: [cleanedUpExpectation], timeout: 2.0)
        XCTAssertTrue(sawPending, "Service should have briefly entered pending state")
    }

    // MARK: - Test 3: TunnelClosed before TunnelOpened cleans pending

    func testTunnelClosedWhilePending_CleansPendingServices() {
        let pendingExpectation = XCTestExpectation(description: "Pending state emitted")
        let cleanedExpectation = XCTestExpectation(description: "Pending cleaned up by TunnelClosed")

        var sawPending = false

        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { state in
                if state.pendingServices.contains(TestConstants.serviceId) {
                    sawPending = true
                    pendingExpectation.fulfill()
                }
                if sawPending && state.pendingServices.isEmpty && state.activeTunnels.isEmpty {
                    cleanedExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)

        wait(for: [pendingExpectation], timeout: 2.0)

        service.serviceTunnelClosed(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.peerDisconnectedReason)

        wait(for: [cleanedExpectation], timeout: 2.0)
        XCTAssertTrue(sawPending, "Service should have been in pending state before close")
    }

    // MARK: - observePeerServices

    private var sampleServicesJson: String {
        let service: [String: String] = [
            "id": TestConstants.serviceId,
            "name": TestConstants.serviceName,
            "description": TestConstants.serviceDescription,
            "scheme": TestConstants.httpScheme,
            "device": TestConstants.deviceId
        ]
        let data = try? JSONSerialization.data(withJSONObject: [service])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private func emitPeerServices(requestId: UInt32,
                                  accountId: String = TestConstants.accountId,
                                  peerId: String = TestConstants.peerId,
                                  status: Int32 = TestConstants.successStatus) {
        service.peerServicesReceived(withRequestId: requestId,
                                     accountId: accountId,
                                     peerId: peerId,
                                     status: status,
                                     servicesJson: sampleServicesJson)
    }

    func testObservePeerServices_emitsProactiveUpdate_requestIdZero() {
        let expectation = XCTestExpectation(description: "Proactive update received")

        service.observePeerServices(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { result in
                XCTAssertEqual(result.requestId, TestConstants.proactiveRequestId)
                XCTAssertTrue(result.hasExposedServices)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        emitPeerServices(requestId: TestConstants.proactiveRequestId)

        wait(for: [expectation], timeout: 2.0)
    }

    func testObservePeerServices_filtersByAccountAndPeer() {
        let expectation = XCTestExpectation(description: "Only matching peer received")
        expectation.expectedFulfillmentCount = 1

        service.observePeerServices(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { result in
                XCTAssertEqual(result.accountId, TestConstants.accountId)
                XCTAssertEqual(result.peerId, TestConstants.peerId)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        emitPeerServices(requestId: TestConstants.proactiveRequestId, accountId: TestConstants.otherAccountId)
        emitPeerServices(requestId: TestConstants.proactiveRequestId, peerId: TestConstants.otherPeerId)
        emitPeerServices(requestId: TestConstants.proactiveRequestId)

        wait(for: [expectation], timeout: 2.0)
    }

    func testObservePeerServices_replaysLastValueToNewSubscriber() {
        emitPeerServices(requestId: TestConstants.proactiveRequestId)

        let firstExpectation = XCTestExpectation(description: "First subscriber")
        let secondExpectation = XCTestExpectation(description: "Second subscriber replays")

        service.observePeerServices(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .take(1)
            .subscribe(onNext: { _ in firstExpectation.fulfill() })
            .disposed(by: disposeBag)

        wait(for: [firstExpectation], timeout: 2.0)

        service.observePeerServices(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .take(1)
            .subscribe(onNext: { result in
                XCTAssertEqual(result.requestId, TestConstants.proactiveRequestId)
                XCTAssertTrue(result.hasExposedServices)
                secondExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [secondExpectation], timeout: 2.0)
    }

    func testQueryPeerServices_stillFiltersByRequestId() {
        mockAdapter.queryReturnValue = TestConstants.queryRequestId

        let queryExpectation = XCTestExpectation(description: "Query completes only for matching requestId")
        var receivedRequestIds = [UInt32]()

        service.queryPeerServices(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { result in
                receivedRequestIds.append(result.requestId)
                queryExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        emitPeerServices(requestId: TestConstants.proactiveRequestId)
        emitPeerServices(requestId: TestConstants.queryRequestId)

        wait(for: [queryExpectation], timeout: 2.0)
        XCTAssertEqual(receivedRequestIds, [TestConstants.queryRequestId])
    }

    // MARK: - Tunnel endpoint URL

    func testBrowsableURL_buildsLoopbackURLsForWebSchemes() {
        let httpTunnel = makeTunnel(scheme: TestConstants.uppercaseHttpScheme,
                                    localPort: TestConstants.defaultPort)
        let httpsTunnel = makeTunnel(scheme: TestConstants.httpsScheme,
                                     localPort: TestConstants.alternatePort)

        XCTAssertTrue(httpTunnel.isWebEndpoint)
        XCTAssertEqual(httpTunnel.browsableURL?.absoluteString,
                       TestConstants.loopbackURL(scheme: TestConstants.httpScheme,
                                                 port: TestConstants.defaultPort))
        XCTAssertEqual(httpsTunnel.browsableURL?.absoluteString,
                       TestConstants.loopbackURL(scheme: TestConstants.httpsScheme,
                                                 port: TestConstants.alternatePort))
    }

    func testBrowsableURL_nilForUnsupportedSchemeAndInvalidPort() {
        // Non-web scheme: not browsable (WKWebView loads only http/https)...
        XCTAssertNil(makeTunnel(scheme: TestConstants.unsupportedScheme).browsableURL)
        XCTAssertFalse(makeTunnel(scheme: TestConstants.unsupportedScheme).isWebEndpoint)
        // ...invalid ports are rejected for every scheme.
        XCTAssertNil(makeTunnel(localPort: TestConstants.invalidPort).browsableURL)
        XCTAssertNil(makeTunnel(localPort: Int(UInt16.max) + 1).browsableURL)
    }

    func testLoopbackURL_buildsCopyableEndpointForAnyScheme() {
        // Web scheme: same loopback form as browsableURL.
        XCTAssertEqual(makeTunnel(scheme: TestConstants.httpScheme,
                                  localPort: TestConstants.defaultPort).loopbackURL?.absoluteString,
                       TestConstants.loopbackURL(scheme: TestConstants.httpScheme,
                                                 port: TestConstants.defaultPort))

        // Non-web scheme: not browsable, but still has a copyable loopback URL
        // (regression: copy was a no-op for these).
        let sshTunnel = makeTunnel(scheme: TestConstants.unsupportedScheme,
                                   localPort: TestConstants.defaultPort)
        XCTAssertNil(sshTunnel.browsableURL)
        XCTAssertEqual(sshTunnel.loopbackURL?.absoluteString,
                       TestConstants.loopbackURL(scheme: TestConstants.unsupportedScheme,
                                                 port: TestConstants.defaultPort))
    }

    func testLoopbackURL_rejectsInvalidPort() {
        XCTAssertNil(makeTunnel(localPort: TestConstants.invalidPort).loopbackURL)
        XCTAssertNil(makeTunnel(localPort: Int(UInt16.max) + 1).loopbackURL)
    }

    func testLoopbackURL_rejectsMalformedPeerScheme() {
        // Scheme is peer-supplied. Illegal characters must yield nil rather than crash
        // (URLComponents.scheme setter raises on invalid characters).
        for scheme in ["ht tp", "1http", "ht/tp", "javascript:", "", "ht\ttp"] {
            XCTAssertNil(makeTunnel(scheme: scheme).loopbackURL,
                         "scheme \"\(scheme)\" should not produce a URL")
        }
        // A well-formed custom scheme still works.
        XCTAssertEqual(makeTunnel(scheme: "ssh+git").loopbackURL?.scheme, "ssh+git")
    }

    func testObserveTunnelUrl_emitsTypedLoopbackURLForWebTunnel() {
        let expectation = XCTestExpectation(description: "Typed tunnel URL emitted")

        service.observeTunnelUrl(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { url in
                XCTAssertEqual(url.absoluteString,
                               TestConstants.loopbackURL(scheme: TestConstants.httpsScheme,
                                                         port: TestConstants.securePort))
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: TestConstants.accountId,
                           peerId: TestConstants.peerId,
                           service: makeService(scheme: TestConstants.uppercaseHttpsScheme))
        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.securePort))

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Close-then-open on reconnect

    func testOpenTunnel_closesActiveTunnelBeforeReopening() {
        let activeExpectation = XCTestExpectation(description: "First tunnel active")
        let reopenedExpectation = XCTestExpectation(description: "Second tunnel active")

        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { state in
                if let tunnel = state.activeTunnels[TestConstants.serviceId],
                   tunnel.tunnelId == TestConstants.tunnelId {
                    activeExpectation.fulfill()
                }
                if let tunnel = state.activeTunnels[TestConstants.serviceId],
                   tunnel.tunnelId == TestConstants.reopenedTunnelId {
                    reopenedExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))

        wait(for: [activeExpectation], timeout: 2.0)
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 1)
        XCTAssertEqual(mockAdapter.closeServiceTunnelCallCount, 0)

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)

        let closeExpectation = XCTestExpectation(description: "Close before reopen")
        func waitForClose(attempts: Int = 0) {
            if mockAdapter.closeServiceTunnelCallCount >= 1 {
                closeExpectation.fulfill()
            } else if attempts < 40 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    waitForClose(attempts: attempts + 1)
                }
            }
        }
        waitForClose()
        wait(for: [closeExpectation], timeout: 2.0)
        XCTAssertEqual(mockAdapter.lastClosedTunnelId, TestConstants.tunnelId)
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 1)

        service.serviceTunnelClosed(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.reconnectReason)

        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.reopenedTunnelId,
                                    localPort: UInt16(TestConstants.alternatePort))

        wait(for: [reopenedExpectation], timeout: 2.0)
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 2)
    }

    func testObserveTunnelState_survivesTunnelCloseAndReopen() {
        let firstOpenExpectation = XCTestExpectation(description: "First tunnel active")
        let closedExpectation = XCTestExpectation(description: "Tunnel closed")
        let secondOpenExpectation = XCTestExpectation(description: "Second tunnel active on same subscription")

        var openCount = 0

        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { state in
                if let tunnel = state.activeTunnels[TestConstants.serviceId],
                   tunnel.tunnelId == TestConstants.tunnelId {
                    openCount += 1
                    firstOpenExpectation.fulfill()
                }
                if openCount >= 1,
                   state.activeTunnels.isEmpty,
                   state.pendingServices.isEmpty {
                    closedExpectation.fulfill()
                }
                if let tunnel = state.activeTunnels[TestConstants.serviceId],
                   tunnel.tunnelId == TestConstants.reopenedTunnelId {
                    secondOpenExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))
        wait(for: [firstOpenExpectation], timeout: 2.0)

        service.closeTunnel(accountId: TestConstants.accountId,
                            peerId: TestConstants.peerId,
                            serviceId: TestConstants.serviceId)
        service.serviceTunnelClosed(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.completedReason)
        wait(for: [closedExpectation], timeout: 2.0)

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.reopenedTunnelId,
                                    localPort: UInt16(TestConstants.alternatePort))
        wait(for: [secondOpenExpectation], timeout: 2.0)
    }

    // MARK: - tunnel lifecycle cleanup

    private func waitForServiceQueue(attempts: Int = 0, completion: @escaping () -> Void) {
        if attempts >= 40 {
            completion()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.waitForServiceQueue(attempts: attempts + 1, completion: completion)
        }
    }

    private func waitForServiceQueue() {
        let expectation = XCTestExpectation(description: "service queue settled")
        waitForServiceQueue { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
    }

    func testCloseAllTunnels_closesPendingOpen() {
        let pendingExpectation = XCTestExpectation(description: "Pending state emitted")
        let cleanedExpectation = XCTestExpectation(description: "Pending cleared after close-all")

        var sawPending = false

        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { state in
                if state.pendingServices.contains(TestConstants.serviceId) && state.activeTunnels.isEmpty {
                    sawPending = true
                    pendingExpectation.fulfill()
                }
                if sawPending
                    && state.pendingServices.isEmpty
                    && state.activeTunnels.isEmpty {
                    cleanedExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        wait(for: [pendingExpectation], timeout: 2.0)

        service.closeAllTunnels()
        waitForServiceQueue()

        XCTAssertEqual(mockAdapter.lastClosedTunnelId, TestConstants.tunnelId)
        XCTAssertGreaterThanOrEqual(mockAdapter.closeServiceTunnelCallCount, 1)
        wait(for: [cleanedExpectation], timeout: 2.0)
    }

    func testLateTunnelOpened_afterCloseAll_isClosedNotActive() {
        var tunnelUrlEmissions = 0

        service.observeTunnelUrl(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { _ in tunnelUrlEmissions += 1 })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        waitForServiceQueue()

        let closeCountBeforeLateOpen = mockAdapter.closeServiceTunnelCallCount
        service.closeAllTunnels()
        waitForServiceQueue()

        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))
        waitForServiceQueue()

        XCTAssertGreaterThan(mockAdapter.closeServiceTunnelCallCount, closeCountBeforeLateOpen)
        XCTAssertEqual(tunnelUrlEmissions, 0)

        let emptyExpectation = XCTestExpectation(description: "Relay stays empty")
        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .filter { $0.activeTunnels.isEmpty && $0.pendingServices.isEmpty }
            .take(1)
            .subscribe(onNext: { _ in emptyExpectation.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [emptyExpectation], timeout: 2.0)
    }

    func testCloseAllTunnels_peerScoped_affectsOnlyTargetPeer() {
        let otherPeerId = TestConstants.otherPeerId

        let targetPendingExpectation = XCTestExpectation(description: "Target peer pending")
        let otherPendingExpectation = XCTestExpectation(description: "Other peer pending")
        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .filter { $0.pendingServices.contains(TestConstants.serviceId) }
            .take(1)
            .subscribe(onNext: { _ in targetPendingExpectation.fulfill() })
            .disposed(by: disposeBag)
        service.observeTunnelState(accountId: TestConstants.accountId, peerId: otherPeerId)
            .filter { $0.pendingServices.contains(TestConstants.serviceId) }
            .take(1)
            .subscribe(onNext: { _ in otherPendingExpectation.fulfill() })
            .disposed(by: disposeBag)

        mockAdapter.openTunnelReturnValue = TestConstants.tunnelId
        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        waitForServiceQueue()

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: TestConstants.accountId, peerId: otherPeerId, service: testService)
        waitForServiceQueue()

        wait(for: [targetPendingExpectation, otherPendingExpectation], timeout: 2.0)

        let closesBefore = mockAdapter.closeServiceTunnelCallCount
        service.closeAllTunnels(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
        waitForServiceQueue()

        XCTAssertEqual(mockAdapter.closeServiceTunnelCallCount - closesBefore, 1)
        XCTAssertEqual(mockAdapter.lastClosedTunnelId, TestConstants.tunnelId)

        let targetClearedExpectation = XCTestExpectation(description: "Target peer cleared")
        let otherStillPendingExpectation = XCTestExpectation(description: "Other peer still pending")

        service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .filter { $0.pendingServices.isEmpty && $0.activeTunnels.isEmpty }
            .take(1)
            .subscribe(onNext: { _ in targetClearedExpectation.fulfill() })
            .disposed(by: disposeBag)
        service.observeTunnelState(accountId: TestConstants.accountId, peerId: otherPeerId)
            .filter { $0.pendingServices.contains(TestConstants.serviceId) }
            .take(1)
            .subscribe(onNext: { _ in otherStillPendingExpectation.fulfill() })
            .disposed(by: disposeBag)

        wait(for: [targetClearedExpectation, otherStillPendingExpectation], timeout: 2.0)
    }

    func testCloseAllTunnels_global_affectsAllPeers() {
        let otherPeerId = TestConstants.otherPeerId

        mockAdapter.openTunnelReturnValue = TestConstants.tunnelId
        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: TestConstants.accountId, peerId: otherPeerId, service: testService)
        waitForServiceQueue()

        let closesBefore = mockAdapter.closeServiceTunnelCallCount
        service.closeAllTunnels()
        waitForServiceQueue()

        XCTAssertGreaterThanOrEqual(mockAdapter.closeServiceTunnelCallCount - closesBefore, 2)
    }

    func testServiceTunnelClosed_afterCloseAll_doesNotReopen() {
        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))
        waitForServiceQueue()

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        waitForServiceQueue()
        XCTAssertEqual(mockAdapter.closeServiceTunnelCallCount, 1)

        service.closeAllTunnels()
        waitForServiceQueue()

        let opensBeforeClosed = mockAdapter.openServiceTunnelCallCount
        service.serviceTunnelClosed(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.userCloseReason)
        waitForServiceQueue()

        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, opensBeforeClosed)
    }

    // MARK: - Disposal race

    /// Subscription is created asynchronously on the service queue while the
    /// teardown runs synchronously on the caller thread. Disposing before the
    /// async subscribe lands must still tear the inner subscription down so a
    /// later emission is never delivered.
    func testObservePeerServices_disposeBeforeEmit_noDelivery() {
        var received = 0
        let subscription = service.observePeerServices(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { _ in received += 1 })
        subscription.dispose()

        emitPeerServices(requestId: TestConstants.proactiveRequestId)

        let settle = XCTestExpectation(description: "queue settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settle.fulfill() }
        wait(for: [settle], timeout: 2.0)
        XCTAssertEqual(received, 0, "Disposed observer must not receive emissions")
    }

    func testObserveTunnelState_disposeBeforeEmit_noActiveTunnelDelivery() {
        // The initial empty PeerTunnelState may replay synchronously on subscribe;
        // assert only that no post-dispose state change (an active tunnel) arrives.
        var sawActiveTunnel = false
        let subscription = service.observeTunnelState(accountId: TestConstants.accountId, peerId: TestConstants.peerId)
            .subscribe(onNext: { state in
                if !state.activeTunnels.isEmpty { sawActiveTunnel = true }
            })
        subscription.dispose()

        service.openTunnel(accountId: TestConstants.accountId, peerId: TestConstants.peerId, service: testService)
        service.serviceTunnelOpened(withAccountId: TestConstants.accountId,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))

        let settle = XCTestExpectation(description: "queue settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settle.fulfill() }
        wait(for: [settle], timeout: 2.0)
        XCTAssertFalse(sawActiveTunnel, "Disposed observer must not receive post-dispose state changes")
    }
}
