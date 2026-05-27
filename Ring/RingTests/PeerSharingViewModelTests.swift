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
@testable import Ring

class PeerSharingViewModelTests: XCTestCase {

    private enum TestConstants {
        static let serviceId = "test-service-id"
        static let otherServiceId = "other-test-service-id"
        static let tunnelId = "test-tunnel-id"
        static let otherTunnelId = "other-test-tunnel-id"
        static let serviceName = "Test Web Service"
        static let serviceDescription = "Test web service description"
        static let webScheme = "https"
        static let port = 8443
        static let otherPort = 9443
        static let queryRequestId: UInt32 = 1
        static let successStatus: Int32 = 0
        static let closeReason = "peer_disconnected"
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
    private var viewModel: PeerSharingViewModel!

    override func setUp() {
        super.setUp()
        mockAdapter = ObjCMockPeerServicesAdapter()
        mockAdapter.queryReturnValue = TestConstants.queryRequestId
        mockAdapter.openTunnelReturnValue = TestConstants.tunnelId
        service = PeerSharingService(withPeerServicesAdapter: mockAdapter)
        viewModel = PeerSharingViewModel(accountId: accountId1,
                                         peerId: jamiId1,
                                         peerSharingService: service)
    }

    override func tearDown() {
        viewModel = nil
        service = nil
        mockAdapter = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func webService(id: String = TestConstants.serviceId,
                            name: String = TestConstants.serviceName,
                            description: String = TestConstants.serviceDescription) -> PeerServiceInfo {
        PeerServiceInfo(id: id,
                        name: name,
                        description: description,
                        scheme: TestConstants.webScheme,
                        device: deviceId1)
    }

    private func servicesJson(_ services: [PeerServiceInfo]) -> String {
        let array = services.map { service -> [String: String] in
            [
                ServiceJsonKey.id: service.id,
                ServiceJsonKey.name: service.name,
                ServiceJsonKey.description: service.description,
                ServiceJsonKey.scheme: service.scheme,
                ServiceJsonKey.device: service.device
            ]
        }
        return jsonString(from: array)
    }

    private func jsonString(from object: Any) -> String {
        let data = try? JSONSerialization.data(withJSONObject: object)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    /// Delivers the query response so `viewModel.services` is populated.
    private func deliverServices(_ services: [PeerServiceInfo]) {
        service.peerServicesReceived(withRequestId: TestConstants.queryRequestId,
                                     accountId: accountId1,
                                     peerId: jamiId1,
                                     status: TestConstants.successStatus,
                                     servicesJson: servicesJson(services))
    }

    private func wait(until condition: @escaping () -> Bool,
                      timeout: TimeInterval = 2.0,
                      _ description: String) {
        let expectation = XCTestExpectation(description: description)
        func poll(_ attempts: Int) {
            if condition() { expectation.fulfill(); return }
            if attempts >= 60 { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { poll(attempts + 1) }
        }
        poll(0)
        wait(for: [expectation], timeout: timeout)
    }

    /// Drives a web service through query → open → TunnelOpened so it is active and presented.
    private func driveToPresented(serviceId: String = TestConstants.serviceId,
                                  tunnelId: String = TestConstants.tunnelId,
                                  port: Int = TestConstants.port) {
        let svc = webService(id: serviceId)
        deliverServices([svc])
        wait(until: { self.viewModel.services.contains { $0.id == serviceId } }, "services loaded")

        mockAdapter.openTunnelReturnValue = tunnelId
        viewModel.beginBrowsing(svc)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: tunnelId,
                                    localPort: UInt16(port))
        wait(until: { self.viewModel.presentedBrowseSession?.service.id == serviceId }, "session presented")
    }

    // MARK: - External tunnel death dismisses the browse session

    func testExternalTunnelClose_dismissesBrowseSession() {
        driveToPresented()

        service.serviceTunnelClosed(withAccountId: accountId1,
                                    tunnelId: TestConstants.tunnelId,
                                    reason: TestConstants.closeReason)

        wait(until: { self.viewModel.presentedBrowseSession == nil },
             "browse session dismissed when its tunnel closes externally")
    }

    func testCloseAllTunnels_dismissesBrowseSession() {
        driveToPresented()

        // The app-background path: closeAllTunnels bypasses the view model entirely.
        service.closeAllTunnels()

        wait(until: { self.viewModel.presentedBrowseSession == nil },
             "browse session dismissed when all tunnels close")
    }

    // MARK: - Reopen Prevention

    func testDismissedBrowseSession_doesNotReopenWhenUnrelatedTunnelStateChanges() {
        driveToPresented()

        // Simulate an external clear of the session while the original tunnel is still active.
        // A later, unrelated tunnel update must not reopen the dismissed browse session.
        viewModel.presentedBrowseSession = nil

        // Force a fresh state emission while the original tunnel is still active by opening a
        // second, unrelated service.
        let other = webService(id: TestConstants.otherServiceId)
        mockAdapter.openTunnelReturnValue = TestConstants.otherTunnelId
        viewModel.openTunnel(other)
        service.serviceTunnelOpened(withAccountId: accountId1,
                                    tunnelId: TestConstants.otherTunnelId,
                                    localPort: UInt16(TestConstants.otherPort))
        wait(until: { self.viewModel.activeTunnels[TestConstants.otherServiceId] != nil },
             "second tunnel active (forces a state emission)")

        XCTAssertNil(viewModel.presentedBrowseSession,
                     "Dismissed browse session must not reopen after unrelated tunnel changes")
    }
}
