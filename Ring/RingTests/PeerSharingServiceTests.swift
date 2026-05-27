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
@testable import Ring

class PeerSharingServiceTests: XCTestCase {

    private enum TestConstants {
        static let tunnelId = "test-tunnel-id"
        static let reopenedTunnelId = "test-reopened-tunnel-id"
        static let serviceId = "test-service-id"
        static let secondServiceId = "test-service-id-2"
        static let serviceName = "Test Web Service"
        static let serviceDescription = "Test service description"
        static let httpScheme = "http"
        static let httpsScheme = "https"
        static let nonWebScheme = "ssh"
        static let loopbackHost = "127.0.0.1"
        static let defaultPort = 8080
        static let alternatePort = 9090
        static let proactiveRequestId: UInt32 = 0
        static let queryRequestId: UInt32 = 1
        static let successStatus: Int32 = 0
        static let emptyServicesJson = "[]"
        static let tunnelClosedReason = "test-close-reason"
        static let defaultTimeout: TimeInterval = 2.0
        static let pollingInterval: TimeInterval = 0.05
        static let maxPollingAttempts = 40
        static let settleDelay: TimeInterval = 0.3
        static let closedCallbackSettleDelay: TimeInterval = 0.2

        static func loopbackURL(scheme: String, port: Int) -> String {
            "\(scheme)://\(loopbackHost):\(port)"
        }
    }

    private enum ServiceJsonKey {
        static let id = "id"
        static let name = "name"
        static let description = "description"
        static let scheme = "scheme"
        static let device = "device"
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
            device: deviceId1
        )
    }

    private func makeService(scheme: String) -> PeerServiceInfo {
        PeerServiceInfo(
            id: TestConstants.serviceId,
            name: TestConstants.serviceName,
            description: TestConstants.serviceDescription,
            scheme: scheme,
            device: deviceId1
        )
    }

    private func makeTunnel(scheme: String = TestConstants.httpScheme,
                            localPort: Int = TestConstants.defaultPort) -> PeerTunnelInfo {
        PeerTunnelInfo(
            tunnelId: TestConstants.tunnelId,
            accountId: accountId1,
            peerId: jamiId1,
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

    // MARK: - Tunnel Lifecycle

    func testTunnelLifecycle_PendingToActiveToClosedCleansUp() {
        let pendingExpectation = XCTestExpectation(description: "Pending state emitted")
        let activeExpectation = XCTestExpectation(description: "Active state emitted")
        let emptyExpectation = XCTestExpectation(description: "Empty state emitted after close")

        var stateHistory = [PeerTunnelState]()

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
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

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)

        wait(for: [pendingExpectation], timeout: TestConstants.defaultTimeout)

        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))

        wait(for: [activeExpectation], timeout: TestConstants.defaultTimeout)

        service.serviceTunnelClosed(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.tunnelClosedReason)

        wait(for: [emptyExpectation], timeout: TestConstants.defaultTimeout)
    }

    func testOpenTunnelFailure_CleansUpOrphanState() {
        mockAdapter.openTunnelReturnValue = ""

        let cleanedUpExpectation = XCTestExpectation(description: "State returns to empty after failure")

        var sawPending = false

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { state in
                if state.pendingServices.contains(TestConstants.serviceId) {
                    sawPending = true
                }
                if sawPending && state.pendingServices.isEmpty && state.activeTunnels.isEmpty {
                    cleanedUpExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)

        wait(for: [cleanedUpExpectation], timeout: TestConstants.defaultTimeout)
        XCTAssertTrue(sawPending, "Service should have briefly entered pending state")
    }

    func testTunnelClosedWhilePending_CleansPendingServices() {
        let pendingExpectation = XCTestExpectation(description: "Pending state emitted")
        let cleanedExpectation = XCTestExpectation(description: "Pending cleaned up by TunnelClosed")

        var sawPending = false

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
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
        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)

        wait(for: [pendingExpectation], timeout: TestConstants.defaultTimeout)

        service.serviceTunnelClosed(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.tunnelClosedReason)

        wait(for: [cleanedExpectation], timeout: TestConstants.defaultTimeout)
        XCTAssertTrue(sawPending, "Service should have been in pending state before close")
    }

    // MARK: - Peer Service Discovery

    private var sampleServicesJson: String {
        let service: [String: String] = [
            ServiceJsonKey.id: TestConstants.serviceId,
            ServiceJsonKey.name: TestConstants.serviceName,
            ServiceJsonKey.description: TestConstants.serviceDescription,
            ServiceJsonKey.scheme: TestConstants.httpScheme,
            ServiceJsonKey.device: deviceId1
        ]
        return jsonString(from: [service])
    }

    private func emitPeerServices(requestId: UInt32,
                                  accountId: String = accountId1,
                                  peerId: String = jamiId1,
                                  status: Int32 = TestConstants.successStatus) {
        service.peerServicesReceived(withRequestId: requestId,
                                     accountId: accountId,
                                     peerId: peerId,
                                     status: status,
                                     servicesJson: sampleServicesJson)
    }

    private func jsonString(from object: Any) -> String {
        let data = try? JSONSerialization.data(withJSONObject: object)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? TestConstants.emptyServicesJson
    }

    private func waitUntil(_ description: String,
                           timeout: TimeInterval = TestConstants.defaultTimeout,
                           condition: @escaping () -> Bool) {
        let expectation = XCTestExpectation(description: description)
        var isWaiting = true
        var didFulfill = false

        func poll(attempts: Int = 0) {
            guard isWaiting && !didFulfill else { return }

            if condition() {
                didFulfill = true
                expectation.fulfill()
            } else if attempts < TestConstants.maxPollingAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + TestConstants.pollingInterval) {
                    poll(attempts: attempts + 1)
                }
            }
        }
        poll()
        wait(for: [expectation], timeout: timeout)
        isWaiting = false
    }

    func testObservePeerServices_emitsProactiveUpdate_requestIdZero() {
        let expectation = XCTestExpectation(description: "Proactive update received")

        service.observePeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { result in
                XCTAssertEqual(result.requestId, TestConstants.proactiveRequestId)
                XCTAssertTrue(result.hasExposedServices)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        emitPeerServices(requestId: TestConstants.proactiveRequestId)

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func testObservePeerServices_filtersByAccountAndPeer() {
        let expectation = XCTestExpectation(description: "Only matching peer received")
        expectation.expectedFulfillmentCount = 1

        service.observePeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { result in
                XCTAssertEqual(result.accountId, accountId1)
                XCTAssertEqual(result.peerId, jamiId1)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        emitPeerServices(requestId: TestConstants.proactiveRequestId, accountId: accountId2)
        emitPeerServices(requestId: TestConstants.proactiveRequestId, peerId: jamiId2)
        emitPeerServices(requestId: TestConstants.proactiveRequestId)

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    func testQueryPeerServices_stillFiltersByRequestId() {
        mockAdapter.queryReturnValue = TestConstants.queryRequestId

        let queryExpectation = XCTestExpectation(description: "Query completes only for matching requestId")
        var receivedRequestIds = [UInt32]()

        service.queryPeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { result in
                receivedRequestIds.append(result.requestId)
                queryExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        emitPeerServices(requestId: TestConstants.proactiveRequestId)
        emitPeerServices(requestId: TestConstants.queryRequestId)

        wait(for: [queryExpectation], timeout: TestConstants.defaultTimeout)
        XCTAssertEqual(receivedRequestIds, [TestConstants.queryRequestId])
    }

    func testQueryPeerServices_deliversResponseReceivedDuringQuerySetup() {
        // Some adapter implementations can synchronously report the daemon response while
        // queryPeerServices is still setting up. The observable should still complete.
        mockAdapter.queryReturnValue = TestConstants.queryRequestId
        mockAdapter.onQueryPeerServices = { [weak self] _, _ in
            self?.emitPeerServices(requestId: TestConstants.queryRequestId)
        }

        let queryExpectation = XCTestExpectation(description: "Query setup response delivered")
        service.queryPeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { result in
                XCTAssertEqual(result.requestId, TestConstants.queryRequestId)
                XCTAssertTrue(result.hasExposedServices)
                queryExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [queryExpectation], timeout: TestConstants.defaultTimeout)
    }

    func testParseServices_deduplicatesByIdKeepingFirst() {
        let expectation = XCTestExpectation(description: "Deduplicated services received")

        // servicesJson is peer-controlled. A malicious/buggy peer can send two entries
        // sharing one id (different device/name). Duplicate Identifiable ids break SwiftUI
        // List(id:) / fullScreenCover(item:), so parse must collapse them keeping the first,
        // while preserving a genuinely distinct id.
        let ignoredDuplicateName = "Ignored duplicate service"
        let duplicateServices: [[String: String]] = [
            [
                ServiceJsonKey.id: TestConstants.serviceId,
                ServiceJsonKey.name: TestConstants.serviceName,
                ServiceJsonKey.scheme: TestConstants.httpScheme,
                ServiceJsonKey.device: deviceId1
            ],
            [
                ServiceJsonKey.id: TestConstants.serviceId,
                ServiceJsonKey.name: ignoredDuplicateName,
                ServiceJsonKey.scheme: TestConstants.httpScheme,
                ServiceJsonKey.device: deviceId2
            ],
            [
                ServiceJsonKey.id: TestConstants.secondServiceId,
                ServiceJsonKey.name: TestConstants.serviceName,
                ServiceJsonKey.scheme: TestConstants.httpsScheme,
                ServiceJsonKey.device: deviceId1
            ]
        ]
        let json = jsonString(from: duplicateServices)

        service.observePeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { result in
                XCTAssertEqual(result.services.count, 2, "Duplicate id collapsed, distinct id kept")
                let first = result.services.first { $0.id == TestConstants.serviceId }
                XCTAssertEqual(first?.name, TestConstants.serviceName, "First occurrence wins")
                XCTAssertEqual(first?.device, deviceId1)
                XCTAssertTrue(result.services.contains { $0.id == TestConstants.secondServiceId },
                              "Distinct id survives dedup")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        service.peerServicesReceived(withRequestId: TestConstants.proactiveRequestId,
                                     accountId: accountId1,
                                     peerId: jamiId1,
                                     status: TestConstants.successStatus,
                                     servicesJson: json)

        wait(for: [expectation], timeout: TestConstants.defaultTimeout)
    }

    // MARK: - Endpoint URLs

    func testBrowsableURL_buildsLoopbackURLsForWebSchemes() {
        let httpTunnel = makeTunnel(scheme: TestConstants.httpScheme.uppercased(),
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
        let invalidLowPort = 0
        let invalidHighPort = Int(UInt16.max) + 1

        // Non-web scheme: not browsable (WKWebView loads only http/https)...
        XCTAssertNil(makeTunnel(scheme: TestConstants.nonWebScheme).browsableURL)
        XCTAssertFalse(makeTunnel(scheme: TestConstants.nonWebScheme).isWebEndpoint)
        // ...invalid ports are rejected for every scheme.
        XCTAssertNil(makeTunnel(localPort: invalidLowPort).browsableURL)
        XCTAssertNil(makeTunnel(localPort: invalidHighPort).browsableURL)
    }

    func testLoopbackURL_buildsCopyableEndpointForAnyScheme() {
        // Web scheme: same loopback form as browsableURL.
        XCTAssertEqual(makeTunnel(scheme: TestConstants.httpScheme,
                                  localPort: TestConstants.defaultPort).loopbackURL?.absoluteString,
                       TestConstants.loopbackURL(scheme: TestConstants.httpScheme,
                                                 port: TestConstants.defaultPort))

        // Non-web scheme: not browsable, but still has a copyable loopback URL
        // (regression: copy was a no-op for these).
        let sshTunnel = makeTunnel(scheme: TestConstants.nonWebScheme,
                                   localPort: TestConstants.defaultPort)
        XCTAssertNil(sshTunnel.browsableURL)
        XCTAssertEqual(sshTunnel.loopbackURL?.absoluteString,
                       TestConstants.loopbackURL(scheme: TestConstants.nonWebScheme,
                                                 port: TestConstants.defaultPort))
    }

    func testLoopbackURL_rejectsInvalidPort() {
        let invalidLowPort = 0
        let invalidHighPort = Int(UInt16.max) + 1

        XCTAssertNil(makeTunnel(localPort: invalidLowPort).loopbackURL)
        XCTAssertNil(makeTunnel(localPort: invalidHighPort).loopbackURL)
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

    // MARK: - Reopen Behavior
}

extension PeerSharingServiceTests {

    func testOpenTunnel_closesActiveTunnelBeforeReopening() {
        let activeExpectation = XCTestExpectation(description: "First tunnel active")
        let reopenedExpectation = XCTestExpectation(description: "Second tunnel active")

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
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

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))

        wait(for: [activeExpectation], timeout: TestConstants.defaultTimeout)
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 1)
        XCTAssertEqual(mockAdapter.closeServiceTunnelCallCount, 0)

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)

        waitUntil("Close before reopen") {
            self.mockAdapter.closeServiceTunnelCallCount >= 1
        }
        XCTAssertEqual(mockAdapter.lastClosedTunnelId, TestConstants.tunnelId)
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 1)

        service.serviceTunnelClosed(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.tunnelClosedReason)

        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.reopenedTunnelId,
                                    localPort: UInt16(TestConstants.alternatePort))

        wait(for: [reopenedExpectation], timeout: TestConstants.defaultTimeout)
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 2)
    }

    func testReopen_whenCloseFails_recoversInsteadOfStuckPending() {
        let activeExpectation = XCTestExpectation(description: "First tunnel active")
        let reopenedExpectation = XCTestExpectation(description: "Reopened tunnel active, not stuck pending")

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { state in
                if state.activeTunnels[TestConstants.serviceId]?.tunnelId == TestConstants.tunnelId {
                    activeExpectation.fulfill()
                }
                if let tunnel = state.activeTunnels[TestConstants.serviceId],
                   tunnel.tunnelId == TestConstants.reopenedTunnelId,
                   state.pendingServices.isEmpty {
                    reopenedExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))
        wait(for: [activeExpectation], timeout: TestConstants.defaultTimeout)
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 1)

        // Daemon refuses the close (tunnel already gone) and emits no ServiceTunnelClosed.
        // The close-then-reopen must NOT wait for a callback that will never arrive.
        mockAdapter.closeTunnelReturnValue = false
        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)

        waitUntil("Direct re-open issued after failed close") {
            self.mockAdapter.openServiceTunnelCallCount >= 2
        }
        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, 2,
                       "Failed close must trigger a direct re-open, not a stuck pending wait")

        // The reopened tunnel lands; the service ends active with no lingering pending flag.
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.reopenedTunnelId,
                                    localPort: UInt16(TestConstants.alternatePort))
        wait(for: [reopenedExpectation], timeout: TestConstants.defaultTimeout)
    }

    func testObserveTunnelState_survivesTunnelCloseAndReopen() {
        let firstOpenExpectation = XCTestExpectation(description: "First tunnel active")
        let closedExpectation = XCTestExpectation(description: "Tunnel closed")
        let secondOpenExpectation = XCTestExpectation(description: "Second tunnel active on same subscription")

        var openCount = 0

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
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

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))
        wait(for: [firstOpenExpectation], timeout: TestConstants.defaultTimeout)

        service.closeTunnel(accountId: accountId1,
                            peerId: jamiId1,
                            serviceId: TestConstants.serviceId)
        service.serviceTunnelClosed(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.tunnelClosedReason)
        wait(for: [closedExpectation], timeout: TestConstants.defaultTimeout)

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.reopenedTunnelId,
                                    localPort: UInt16(TestConstants.alternatePort))
        wait(for: [secondOpenExpectation], timeout: TestConstants.defaultTimeout)
    }

    // MARK: - Close All Tunnels

    func testCloseAllTunnels_closesPendingOpen() {
        let pendingExpectation = XCTestExpectation(description: "Pending state emitted")
        let cleanedExpectation = XCTestExpectation(description: "Pending cleared after close-all")

        var sawPending = false

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
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

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        wait(for: [pendingExpectation], timeout: TestConstants.defaultTimeout)

        service.closeAllTunnels()

        waitUntil("Pending tunnel close requested") {
            self.mockAdapter.closeServiceTunnelCallCount >= 1
        }
        XCTAssertEqual(mockAdapter.lastClosedTunnelId, TestConstants.tunnelId)
        wait(for: [cleanedExpectation], timeout: TestConstants.defaultTimeout)
    }

    func testLateTunnelOpened_afterCloseAll_isClosedNotActive() {
        var everActive = false

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { state in
                if !state.activeTunnels.isEmpty { everActive = true }
            })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        waitUntil("Pending open requested") {
            self.mockAdapter.openServiceTunnelCallCount >= 1
        }

        let closeCountBeforeCloseAll = mockAdapter.closeServiceTunnelCallCount
        service.closeAllTunnels()
        waitUntil("Pending tunnel closed by closeAll") {
            self.mockAdapter.closeServiceTunnelCallCount > closeCountBeforeCloseAll
        }

        let closeCountAfterCloseAll = mockAdapter.closeServiceTunnelCallCount
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))
        waitUntil("Late-opened tunnel closed") {
            self.mockAdapter.closeServiceTunnelCallCount > closeCountAfterCloseAll
        }

        XCTAssertFalse(everActive, "Late-opened tunnel after closeAll must never become active")

        let emptyExpectation = XCTestExpectation(description: "Tunnel state stays empty")
        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .filter { $0.activeTunnels.isEmpty && $0.pendingServices.isEmpty }
            .take(1)
            .subscribe(onNext: { _ in emptyExpectation.fulfill() })
            .disposed(by: disposeBag)
        wait(for: [emptyExpectation], timeout: TestConstants.defaultTimeout)
    }

    func testCloseAllTunnels_peerScoped_affectsOnlyTargetPeer() {
        let targetPendingExpectation = XCTestExpectation(description: "Target peer pending")
        let otherPendingExpectation = XCTestExpectation(description: "Other peer pending")
        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .filter { $0.pendingServices.contains(TestConstants.serviceId) }
            .take(1)
            .subscribe(onNext: { _ in targetPendingExpectation.fulfill() })
            .disposed(by: disposeBag)
        service.observeTunnelState(accountId: accountId1, peerId: jamiId2)
            .filter { $0.pendingServices.contains(TestConstants.serviceId) }
            .take(1)
            .subscribe(onNext: { _ in otherPendingExpectation.fulfill() })
            .disposed(by: disposeBag)

        mockAdapter.openTunnelReturnValue = TestConstants.tunnelId
        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        waitUntil("Target peer pending open requested") {
            self.mockAdapter.openServiceTunnelCallCount >= 1
        }

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: accountId1, peerId: jamiId2, service: testService)
        waitUntil("Other peer pending open requested") {
            self.mockAdapter.openServiceTunnelCallCount >= 2
        }

        wait(for: [targetPendingExpectation, otherPendingExpectation], timeout: TestConstants.defaultTimeout)

        let closesBefore = mockAdapter.closeServiceTunnelCallCount
        service.closeAllTunnels(accountId: accountId1, peerId: jamiId1)
        waitUntil("Target peer close requested") {
            self.mockAdapter.closeServiceTunnelCallCount - closesBefore == 1
        }

        XCTAssertEqual(mockAdapter.closeServiceTunnelCallCount - closesBefore, 1)
        XCTAssertEqual(mockAdapter.lastClosedTunnelId, TestConstants.tunnelId)

        let targetClearedExpectation = XCTestExpectation(description: "Target peer cleared")
        let otherStillPendingExpectation = XCTestExpectation(description: "Other peer still pending")

        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .filter { $0.pendingServices.isEmpty && $0.activeTunnels.isEmpty }
            .take(1)
            .subscribe(onNext: { _ in targetClearedExpectation.fulfill() })
            .disposed(by: disposeBag)
        service.observeTunnelState(accountId: accountId1, peerId: jamiId2)
            .filter { $0.pendingServices.contains(TestConstants.serviceId) }
            .take(1)
            .subscribe(onNext: { _ in otherStillPendingExpectation.fulfill() })
            .disposed(by: disposeBag)

        wait(for: [targetClearedExpectation, otherStillPendingExpectation], timeout: TestConstants.defaultTimeout)
    }

    func testCloseAllTunnels_global_affectsAllPeers() {
        mockAdapter.openTunnelReturnValue = TestConstants.tunnelId
        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        waitUntil("First pending open requested") {
            self.mockAdapter.openServiceTunnelCallCount >= 1
        }

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: accountId1, peerId: jamiId2, service: testService)
        waitUntil("Both pending opens requested") {
            self.mockAdapter.openServiceTunnelCallCount >= 2
        }

        let closesBefore = mockAdapter.closeServiceTunnelCallCount
        service.closeAllTunnels()
        waitUntil("All pending tunnels closed") {
            self.mockAdapter.closeServiceTunnelCallCount - closesBefore >= 2
        }

        XCTAssertGreaterThanOrEqual(mockAdapter.closeServiceTunnelCallCount - closesBefore, 2)

        let targetClearedExpectation = XCTestExpectation(description: "Target peer cleared by global close")
        let otherClearedExpectation = XCTestExpectation(description: "Other peer cleared by global close")
        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .filter { $0.pendingServices.isEmpty && $0.activeTunnels.isEmpty }
            .take(1)
            .subscribe(onNext: { _ in targetClearedExpectation.fulfill() })
            .disposed(by: disposeBag)
        service.observeTunnelState(accountId: accountId1, peerId: jamiId2)
            .filter { $0.pendingServices.isEmpty && $0.activeTunnels.isEmpty }
            .take(1)
            .subscribe(onNext: { _ in otherClearedExpectation.fulfill() })
            .disposed(by: disposeBag)

        wait(for: [targetClearedExpectation, otherClearedExpectation],
             timeout: TestConstants.defaultTimeout)
    }

    func testServiceTunnelClosed_afterCloseAll_doesNotReopen() {
        let activeExpectation = XCTestExpectation(description: "Initial tunnel active")
        service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .filter { $0.activeTunnels[TestConstants.serviceId]?.tunnelId == TestConstants.tunnelId }
            .take(1)
            .subscribe(onNext: { _ in activeExpectation.fulfill() })
            .disposed(by: disposeBag)

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))
        wait(for: [activeExpectation], timeout: TestConstants.defaultTimeout)

        mockAdapter.openTunnelReturnValue = TestConstants.reopenedTunnelId
        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        waitUntil("Existing tunnel close requested before reopen") {
            self.mockAdapter.closeServiceTunnelCallCount >= 1
        }
        XCTAssertEqual(mockAdapter.closeServiceTunnelCallCount, 1)

        service.closeAllTunnels()
        waitUntil("Queued reopen canceled by closeAll") {
            self.mockAdapter.closeServiceTunnelCallCount >= 2
        }

        let opensBeforeClosed = mockAdapter.openServiceTunnelCallCount
        service.serviceTunnelClosed(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.tunnelClosedReason)

        let settle = XCTestExpectation(description: "closed callback processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + TestConstants.closedCallbackSettleDelay) {
            settle.fulfill()
        }
        wait(for: [settle], timeout: TestConstants.defaultTimeout)

        XCTAssertEqual(mockAdapter.openServiceTunnelCallCount, opensBeforeClosed)
    }

    // MARK: - Observer Disposal
}

extension PeerSharingServiceTests {

    /// Subscription is created asynchronously on the service queue while the
    /// teardown runs synchronously on the caller thread. Disposing before the
    /// async subscribe lands must still tear the inner subscription down so a
    /// later emission is never delivered.
    func testObservePeerServices_disposeBeforeEmit_noDelivery() {
        var received = 0
        let subscription = service.observePeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { _ in received += 1 })
        subscription.dispose()

        emitPeerServices(requestId: TestConstants.proactiveRequestId)

        let settle = XCTestExpectation(description: "post-dispose service emissions processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + TestConstants.settleDelay) {
            settle.fulfill()
        }
        wait(for: [settle], timeout: TestConstants.defaultTimeout)
        XCTAssertEqual(received, 0, "Disposed observer must not receive emissions")
    }

    func testObservePeerServices_disposeBeforeCachedReplay_noDelivery() {
        let cacheExpectation = XCTestExpectation(description: "Initial observer receives cached value")
        let cacheSubscription = service.observePeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { _ in cacheExpectation.fulfill() })

        emitPeerServices(requestId: TestConstants.proactiveRequestId)
        wait(for: [cacheExpectation], timeout: TestConstants.defaultTimeout)
        cacheSubscription.dispose()

        var received = 0
        let subscription = service.observePeerServices(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { _ in received += 1 })
        subscription.dispose()

        let settle = XCTestExpectation(description: "post-dispose cached replay skipped")
        DispatchQueue.main.asyncAfter(deadline: .now() + TestConstants.settleDelay) {
            settle.fulfill()
        }
        wait(for: [settle], timeout: TestConstants.defaultTimeout)
        XCTAssertEqual(received, 0, "Disposed observer must not receive cached relay replay")
    }

    func testObserveTunnelState_disposeBeforeEmit_noActiveTunnelDelivery() {
        // The initial empty PeerTunnelState may replay synchronously on subscribe;
        // assert only that no post-dispose state change (an active tunnel) arrives.
        var sawActiveTunnel = false
        let subscription = service.observeTunnelState(accountId: accountId1, peerId: jamiId1)
            .subscribe(onNext: { state in
                if !state.activeTunnels.isEmpty { sawActiveTunnel = true }
            })
        subscription.dispose()

        service.openTunnel(accountId: accountId1, peerId: jamiId1, service: testService)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    localPort: UInt16(TestConstants.defaultPort))

        let settle = XCTestExpectation(description: "post-dispose tunnel emissions processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + TestConstants.settleDelay) {
            settle.fulfill()
        }
        wait(for: [settle], timeout: TestConstants.defaultTimeout)
        XCTAssertFalse(sawActiveTunnel, "Disposed observer must not receive post-dispose state changes")
    }
}
